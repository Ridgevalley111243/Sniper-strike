// Sniper Strike - game controller: renderer, mission flow, combat resolution, kill cam.
import * as THREE from 'three';
import { EffectComposer } from 'three/addons/postprocessing/EffectComposer.js';
import { RenderPass } from 'three/addons/postprocessing/RenderPass.js';
import { UnrealBloomPass } from 'three/addons/postprocessing/UnrealBloomPass.js';
import { OutputPass } from 'three/addons/postprocessing/OutputPass.js';
import { Environment } from './environment.js';
import { library, setAnisotropy } from './textures.js';
import { Level } from './world.js';
import { Enemy } from './enemy.js';
import { Player } from './player.js';
import { Effects } from './effects.js';
import { GameAudio } from './audio.js';
import { UI } from './ui.js';
import { MISSIONS, loadSave, writeSave } from './missions.js';
import { clamp, rand } from './util.js';

const QUALITY = {
  low: { pixelRatio: 1, shadows: 0, bloom: false, aa: false, samples: 0 },
  medium: { pixelRatio: 1.5, shadows: 1024, bloom: true, aa: true, samples: 2 },
  high: { pixelRatio: 2, shadows: 2048, bloom: true, aa: true, samples: 4 },
};

function detectQuality() {
  const mobile = /Android|iPhone|iPad|Mobile/i.test(navigator.userAgent);
  const mem = navigator.deviceMemory || 4;
  if (!mobile) return 'high';
  return mem <= 3 ? 'low' : 'medium';
}

const _v = new THREE.Vector3(), _w = new THREE.Vector3();

class Game {
  constructor() {
    this.save = loadSave();
    const qKey = this.save.settings.quality === 'auto' ? detectQuality() : this.save.settings.quality;
    this.q = QUALITY[qKey] || QUALITY.medium;
    this.state = 'menu';
    this.timeScale = 1;
    this.difficulty = 1;
    this.enemies = [];
    this.stats = this.freshStats();

    const r = (this.renderer = new THREE.WebGLRenderer({ antialias: this.q.aa && !this.q.bloom, powerPreference: 'high-performance', stencil: false }));
    r.setPixelRatio(Math.min(window.devicePixelRatio || 1, this.q.pixelRatio));
    r.setSize(window.innerWidth, window.innerHeight);
    r.toneMapping = THREE.ACESFilmicToneMapping;
    r.outputColorSpace = THREE.SRGBColorSpace;
    r.shadowMap.enabled = this.q.shadows > 0;
    r.shadowMap.type = THREE.PCFSoftShadowMap;
    document.getElementById('app').prepend(r.domElement);
    setAnisotropy(Math.min(8, r.capabilities.getMaxAnisotropy()));
    library();

    this.scene = new THREE.Scene();
    this.camera = new THREE.PerspectiveCamera(70, window.innerWidth / window.innerHeight, 0.05, 1500);
    this.scene.add(this.camera);
    this.killCam = new THREE.PerspectiveCamera(42, window.innerWidth / window.innerHeight, 0.02, 1500);
    this.activeCam = this.camera;
    this.env = new Environment(r, this.scene);
    this.env.configureShadows(this.q);

    if (this.q.bloom) {
      const size = r.getDrawingBufferSize(new THREE.Vector2());
      const rt = new THREE.WebGLRenderTarget(size.x, size.y, { type: THREE.HalfFloatType, samples: this.q.samples });
      this.composer = new EffectComposer(r, rt);
      this.renderPass = new RenderPass(this.scene, this.camera);
      this.composer.addPass(this.renderPass);
      this.bloom = new UnrealBloomPass(new THREE.Vector2(size.x / 2, size.y / 2), 0.32, 0.5, 0.88);
      this.composer.addPass(this.bloom);
      this.composer.addPass(new OutputPass());
    }

    this.audio = new GameAudio();
    this.audio.setVolume(this.save.settings.volume);
    this.effects = new Effects(this);
    this.ui = new UI(this);
    this.player = new Player(this);
    this.raycaster = new THREE.Raycaster();
    this.raycaster.far = 700;

    this.clock = new THREE.Clock();
    window.addEventListener('resize', () => this.resize());
    document.addEventListener('visibilitychange', () => {
      if (document.hidden) { this.audio.suspend(); if (this.state === 'playing') this.pause(); }
      else this.audio.resume();
    });
    window.onAndroidBack = () => this.back();
    window.onAndroidPause = () => { this.audio.suspend(); if (this.state === 'playing') this.pause(); };
    window.onAndroidResume = () => this.audio.resume();

    this.loadMenuScene();
    this.ui.show('main');
    this.loop();
  }

  freshStats() { return { shots: 0, hits: 0, kills: 0, headshots: 0, damageTaken: 0 }; }

  resize() {
    const w = window.innerWidth, h = window.innerHeight;
    this.renderer.setSize(w, h);
    for (const c of [this.camera, this.killCam]) { c.aspect = w / h; c.updateProjectionMatrix(); }
    if (this.composer) {
      this.composer.setSize(w, h);
    }
  }

  // ---------------- scene management ----------------
  setLevel(mission) {
    if (this.level) this.level.dispose();
    for (const e of this.enemies) e.remove();
    this.enemies = [];
    this.effects.clear();
    const focus = mission.vantage === 'roof' ? -95 : -50;
    this.env.apply(mission.time, focus);
    this.level = new Level(this, mission);
    this.scene.add(this.level.group);
    this.targets = null;
  }

  loadMenuScene() {
    const m = MISSIONS[(this.save.unlocked - 1) % MISSIONS.length] || MISSIONS[0];
    this.setLevel({ ...m, vantage: 'street', type: 'waves', range: [25, 80], seed: 4242 });
    this.player.active = false;
    this.player.vmRoot.visible = false;
    this.menuT = 0;
    this.state = 'menu';
    this.ui.hud(false);
  }

  toMenu(screen = 'main') {
    this.ui.killcam(false);
    this.activeCam = this.camera;
    this.timeScale = 1;
    this.loadMenuScene();
    this.ui.show(screen);
    if (document.pointerLockElement) document.exitPointerLock();
  }

  startMission(def) {
    this.audio.init();
    this.ui.show('loading');
    this.ui.killcam(false);
    this.state = 'loading';
    setTimeout(() => {
      this.setLevel(def);
      this.stats = this.freshStats();
      this.mission = {
        def, waveIdx: -1, waveTimer: 2.5, spawnQueue: [], spawnTimer: 0, time: 0,
        alerted: def.type !== 'assassinate', vip: null, ended: false, killcamCooldown: 0,
      };
      this.difficulty = 0.85 + def.id * 0.06;
      this.player.reset(this.level, def, this.save.upgrades);
      this.player.vmRoot.visible = true;
      if (def.type === 'assassinate') this.spawnVipGroup(def);
      // warm up shaders so the first firefight does not hitch
      this.renderer.compile(this.scene, this.camera);
      this.activeCam = this.camera;
      if (this.renderPass) this.renderPass.camera = this.camera;
      this.timeScale = 1;
      this.state = 'playing';
      this.ui.hideScreens();
      this.ui.hud(true);
      this.ui.weapon(this.player);
      this.updateObjective();
      this.ui.banner(def.name.toUpperCase(), def.type === 'assassinate' ? 'ELIMINATE THE TARGET' : 'HOLD THE LINE');
      if (def.tutorial) {
        setTimeout(() => this.state === 'playing' && this.ui.hint('Drag to aim · HOLD FIRE to lean out and shoot · RELEASE to duck into cover', 6), 2500);
        setTimeout(() => this.state === 'playing' && this.ui.hint('Health regenerates while you are in cover', 4), 12000);
      } else if (def.loadout === 'sniper' && def.id === 2) {
        setTimeout(() => this.state === 'playing' && this.ui.hint('HOLD AIM to scope in · drag to steady · RELEASE to fire', 6), 2500);
      }
    }, 60);
  }

  spawnVipGroup(def) {
    const path = this.level.vipPath;
    const vip = new Enemy(this, 'vip', { pos: path[0].clone(), path, state: 'walk', alerted: false, hpMul: 1 });
    this.enemies.push(vip);
    this.mission.vip = vip;
    const offs = [new THREE.Vector3(-1.2, 0, -1.6), new THREE.Vector3(1.2, 0, -1.6), new THREE.Vector3(0, 0, -3)];
    def.guards.forEach((t, i) => {
      const off = offs[i % offs.length];
      const p = path[0].clone().add(off);
      const gEnemy = new Enemy(this, t, { pos: p, follow: vip, followOffset: off, state: 'walk', alerted: false, hpMul: def.hpMul });
      this.enemies.push(gEnemy);
    });
    for (const t of def.sentries) {
      const cp = this.level.pickCover(def.roofEnemies && Math.random() < 0.4);
      if (!cp) continue;
      const e = new Enemy(this, t, { pos: cp.pos.clone(), state: 'idle', alerted: false, hpMul: def.hpMul });
      e.assignCover(cp);
      e.root.rotation.y = cp.yaw;
      this.enemies.push(e);
    }
  }

  alertAll() {
    if (!this.mission || this.mission.alerted) return;
    this.mission.alerted = true;
    for (const e of this.enemies) e.alert();
    this.ui.banner('ALERT!', 'HOSTILES ARE ENGAGING', 1.6);
    if (this.mission.def.type === 'assassinate') this.mission.waveTimer = 3.5;
  }

  nextWave() {
    const m = this.mission;
    m.waveIdx++;
    const wave = m.def.waves[m.waveIdx];
    m.spawnQueue = [...wave];
    m.spawnTimer = 0;
    if (m.def.type === 'waves') this.ui.banner(`WAVE ${m.waveIdx + 1}`, `${wave.length} HOSTILES INBOUND`, 1.8);
    else this.ui.banner('REINFORCEMENTS', `${wave.length} HOSTILES INBOUND`, 1.8);
    this.updateObjective();
  }

  spawnEnemy(type) {
    const lvl = this.level;
    const wantRoof = lvl.mission.roofEnemies && (type === 'sniper' ? Math.random() < 0.8 : Math.random() < 0.35);
    const cp = lvl.pickCover(wantRoof);
    if (!cp) return false;
    let pos;
    if (cp.roof) {
      pos = cp.pos.clone();
    } else {
      const sp = lvl.nearestSpawn(cp.pos);
      pos = sp.pos.clone().add(new THREE.Vector3(rand(-0.8, 0.8), 0, rand(-0.8, 0.8)));
    }
    const e = new Enemy(this, type, { pos, cover: cp, state: cp.roof ? 'cover' : 'run', hpMul: this.mission.def.hpMul });
    e.timer = rand(0.8, 2);
    this.enemies.push(e);
    return true;
  }

  hostilesLeft() {
    const m = this.mission;
    if (!m) return 0;
    let n = this.enemies.filter((e) => e.alive).length + m.spawnQueue.length;
    if (m.def.type === 'waves' || m.alerted) {
      for (let i = m.waveIdx + 1; i < m.def.waves.length; i++) n += m.def.waves[i].length;
    }
    return n;
  }

  updateObjective() {
    const m = this.mission;
    if (!m) return;
    if (m.def.type === 'assassinate') {
      const vipDone = !m.vip.alive;
      this.ui.objective(vipDone ? '✔ Target eliminated<br><b>▸ Clear remaining hostiles</b>' : '<b>▸ Eliminate the marked target</b><br>Do not let him reach the building');
    } else {
      this.ui.objective(`<b>▸ Survive the assault</b><br>Wave ${Math.max(1, m.waveIdx + 1)} / ${m.def.waves.length}`);
    }
  }

  // ---------------- combat ----------------
  raycast(origin, dir) {
    const targets = this.level.colliders.slice();
    for (const e of this.enemies) if (e.alive) for (const h of e.hitMeshes) targets.push(h);
    this.raycaster.set(origin, dir);
    const hits = this.raycaster.intersectObjects(targets, false);
    return hits[0] || null;
  }

  rangeToAim() {
    const cam = this.camera;
    const dir = _v.set(0, 0, -1).applyQuaternion(cam.quaternion);
    this.raycaster.set(cam.position, dir);
    const h = this.raycaster.intersectObjects(this.level.colliders, false)[0];
    return h ? h.distance : 0;
  }

  onPlayerShot(hit, dir, weapon, origin) {
    const def = weapon.def;
    if (!hit) { this.alertAll(); return; }
    const obj = hit.object;
    const enemy = obj.userData.enemy;
    if (enemy && enemy.alive) {
      const part = obj.userData.part || 'body';
      const dmg = weapon.dmg * (part === 'head' ? def.headMul : part === 'limb' ? def.limbMul : 1);
      const lethal = enemy.hp - dmg * (enemy.type.armor && part !== 'head' ? enemy.type.armor : 1) <= 0;
      if (def.key === 'sniper' && lethal && this.wantsKillcam(enemy, part)) {
        this.startKillcam(origin, hit.point.clone(), enemy, part, dmg, dir.clone());
        return;
      }
      this.applyEnemyHit(enemy, part, dmg, hit.point, dir);
    } else if (obj.userData.barrel) {
      const b = obj.userData.barrel;
      this.effects.impact(hit.point, worldNormal(hit), 'metal');
      this.audio.impact('metal');
      b.hp -= weapon.dmg;
      if (b.hp <= 0) this.explodeBarrel(b);
    } else {
      const n = worldNormal(hit);
      this.effects.impact(hit.point, n);
      this.effects.decal(hit.point, n);
      if (hit.distance < 60) this.audio.impact('world');
    }
    this.alertAll();
  }

  applyEnemyHit(enemy, part, dmg, point, dir, explosive = false) {
    const res = enemy.damage(dmg, part, dir, explosive);
    if (!explosive) {
      this.stats.hits++;
      this.effects.blood(point, dir, part === 'head');
      this.ui.hitmarker(part === 'head');
      this.audio.hitmarker(part === 'head' && res.killed);
      this.audio.flesh();
    }
    if (res.killed) {
      this.stats.kills++;
      if (part === 'head') this.stats.headshots++;
      const label = enemy.isVip ? 'TARGET ELIMINATED' : part === 'head' ? 'HEADSHOT' : explosive ? 'EXPLOSIVE KILL' : 'ENEMY DOWN';
      this.ui.killfeed(`${label}  +${enemy.type.reward}`, part === 'head' || enemy.isVip);
      this.mission.bonus = (this.mission.bonus || 0) + enemy.type.reward + (part === 'head' ? 15 : 0);
    }
    return res;
  }

  explodeBarrel(b) {
    if (!b.alive) return;
    b.alive = false;
    const p = b.pos.clone();
    b.obj.visible = false;
    this.level.colliders = this.level.colliders.filter((c) => c.userData.barrel !== b);
    this.effects.explosion(p);
    const dist = p.distanceTo(this.player.headPos);
    this.audio.explosion(dist);
    this.player.shake = Math.max(this.player.shake, clamp(1.2 - dist / 80, 0.2, 1));
    for (const e of this.enemies) {
      if (!e.alive) continue;
      const d = e.root.position.distanceTo(p);
      if (d < 7.5) {
        const dmg = 420 * (1 - d / 7.5) + 40;
        const dir = _w.subVectors(e.root.position, p).setY(0).normalize().clone();
        this.applyEnemyHit(e, 'body', dmg, e.root.position, dir, true);
      }
    }
    for (const o of this.level.barrels) {
      if (o.alive && o.pos.distanceTo(p) < 5) setTimeout(() => this.explodeBarrel(o), 180 + Math.random() * 200);
    }
    if (dist < 8) this.player.damage(60 * (1 - dist / 8), p);
  }

  wantsKillcam(enemy, part) {
    const m = this.mission;
    if (enemy.isVip) return true;
    const alive = this.enemies.filter((e) => e.alive).length;
    const last = alive === 1 && m.spawnQueue.length === 0 && m.waveIdx >= m.def.waves.length - 1 && (!m.vip || !m.vip.alive);
    if (last) return true;
    return part === 'head' && m.killcamCooldown <= 0 && Math.random() < 0.3;
  }

  startKillcam(from, to, enemy, part, dmg, dir) {
    this.state = 'killcam';
    this.mission.killcamCooldown = 25;
    const start = from.clone().addScaledVector(dir, 1.2);
    const dist = start.distanceTo(to);
    this.kc = { from: start, to, enemy, part, dmg, dir, t: 0, dur: clamp(dist / 45, 1.3, 2.8), phase: 'flight', orbit: Math.random() < 0.5 ? 1 : -1 };
    if (!this.bulletMesh) {
      const g = new THREE.Group();
      const m = new THREE.MeshStandardMaterial({ color: 0xc9a14a, metalness: 1, roughness: 0.25 });
      const body = new THREE.Mesh(new THREE.CylinderGeometry(0.0043, 0.0043, 0.03, 12).rotateX(Math.PI / 2), m);
      const tip = new THREE.Mesh(new THREE.ConeGeometry(0.0043, 0.022, 12).rotateX(-Math.PI / 2), m);
      tip.position.z = -0.026;
      g.add(body, tip);
      this.bulletMesh = g;
      this.scene.add(g);
    }
    this.bulletMesh.visible = true;
    this.activeCam = this.killCam;
    if (this.renderPass) this.renderPass.camera = this.killCam;
    this.ui.killcam(true);
    this.ui.hud(false);
    this.audio.bulletTime();
    this.timeScale = 0;
  }

  updateKillcam(dt) {
    const kc = this.kc;
    kc.t += dt;
    const cam = this.killCam;
    if (kc.phase === 'flight') {
      const u = Math.min(1, kc.t / kc.dur);
      const s = 1 - Math.pow(1 - u, 1.6);
      const bp = _v.lerpVectors(kc.from, kc.to, s);
      this.bulletMesh.position.copy(bp);
      this.bulletMesh.lookAt(_w.copy(bp).add(kc.dir));
      this.bulletMesh.rotateZ(kc.t * 20);
      // chase camera spiralling around the bullet
      const side = new THREE.Vector3().crossVectors(kc.dir, THREE.Object3D.DEFAULT_UP).normalize();
      const up = new THREE.Vector3().crossVectors(side, kc.dir).normalize();
      const a = u * 1.4 * kc.orbit;
      const back = 0.22 + u * 0.15;
      cam.position.copy(bp).addScaledVector(kc.dir, -back)
        .addScaledVector(side, Math.cos(a) * 0.07).addScaledVector(up, Math.sin(a) * 0.07 + 0.02);
      cam.lookAt(_w.copy(bp).addScaledVector(kc.dir, 1.5));
      cam.fov = 42; cam.updateProjectionMatrix();
      if (Math.random() < 0.7) this.effects.bulletTrail(_w.copy(bp).addScaledVector(kc.dir, -0.08));
      this.effects.update(dt * 0.4);
      if (u >= 1) {
        kc.phase = 'impact'; kc.t = 0;
        this.bulletMesh.visible = false;
        const res = this.applyEnemyHit(kc.enemy, kc.part, kc.dmg, kc.to, kc.dir);
        this.alertAll();
        this.timeScale = 0.18;
        const vip = kc.enemy.isVip;
        this.ui.killcam(true, vip ? 'TARGET ELIMINATED' : kc.part === 'head' ? 'HEADSHOT' : 'CONFIRMED KILL',
          `${Math.round(kc.from.distanceTo(kc.to))} M`);
        kc.center = kc.enemy.root.position.clone().setY(kc.enemy.root.position.y + 1);
        kc.res = res;
      }
    } else {
      const u = kc.t / 2.2;
      const side = new THREE.Vector3().crossVectors(kc.dir, THREE.Object3D.DEFAULT_UP).normalize();
      const a = (0.6 + u * 0.8) * kc.orbit;
      cam.position.copy(kc.center).addScaledVector(side, Math.cos(a) * 3.2).addScaledVector(kc.dir, -Math.sin(a) * 3.2).add(_w.set(0, 0.4, 0));
      cam.lookAt(kc.center);
      if (kc.t > 2.2) this.endKillcam();
    }
  }

  skipKillcam() {
    if (this.state !== 'killcam') return;
    const kc = this.kc;
    if (kc.phase === 'flight') {
      this.bulletMesh.visible = false;
      this.applyEnemyHit(kc.enemy, kc.part, kc.dmg, kc.to, kc.dir);
      this.alertAll();
    }
    this.endKillcam();
  }

  endKillcam() {
    this.state = 'playing';
    this.timeScale = 1;
    this.activeCam = this.camera;
    if (this.renderPass) this.renderPass.camera = this.camera;
    this.ui.killcam(false);
    this.ui.hud(true);
    this.ui.weapon(this.player);
    this.player.fireHeld = false;
  }

  onEnemyRemoved(e) {
    if (e.isVip) {
      this.updateObjective();
      if (this.state === 'playing') this.ui.banner('TARGET DOWN', 'CLEAR THE AREA', 2);
    }
  }

  onVipEscaped() {
    if (this.mission && !this.mission.ended) this.endMission(false, 'TARGET ESCAPED');
  }

  onPlayerDied() {
    if (this.mission && !this.mission.ended) this.endMission(false, 'KILLED IN ACTION');
  }

  endMission(win, reason) {
    const m = this.mission;
    m.ended = true;
    this.player.active = false;
    this.player.fireHeld = false;
    if (document.pointerLockElement) document.exitPointerLock();
    const s = this.stats;
    const acc = s.shots ? s.hits / s.shots : 0;
    let stars = 0, coins = 0;
    if (win) {
      stars = 1 + (acc >= 0.55 ? 1 : 0) + (this.player.hp / this.player.maxHp >= 0.6 ? 1 : 0);
      coins = m.def.reward + (m.bonus || 0);
      const sv = this.save;
      sv.stars[m.def.id] = Math.max(sv.stars[m.def.id] || 0, stars);
      sv.unlocked = Math.max(sv.unlocked, Math.min(MISSIONS.length, m.def.id + 1));
    } else {
      coins = Math.floor((m.bonus || 0) * 0.5);
    }
    this.save.coins += coins;
    writeSave(this.save);
    setTimeout(() => {
      this.state = 'result';
      this.ui.hud(false);
      this.ui.renderResult({ win, reason, stars, coins, id: m.def.id, time: m.time, ...s });
    }, win ? 1600 : 1200);
    if (!win) this.ui.banner(reason, '', 1.2);
    else this.ui.banner('MISSION COMPLETE', '', 1.5);
  }

  pause() {
    if (this.state !== 'playing') return;
    this.state = 'paused';
    this.player.fireHeld = false;
    this.ui.show('pause');
    if (document.pointerLockElement) document.exitPointerLock();
  }

  resume() {
    if (this.state !== 'paused') return;
    this.ui.hideScreens();
    this.state = 'playing';
    this.clock.getDelta();
  }

  // Android hardware back button. Returns true when handled.
  back() {
    if (this.state === 'playing' || this.state === 'killcam') { this.skipKillcam(); this.pause(); return true; }
    if (this.state === 'paused') { this.resume(); return true; }
    const s = this.ui.screen;
    if (s === 'briefing') { this.ui.show('campaign'); return true; }
    if (s && s !== 'main') { this.state === 'result' ? this.toMenu('campaign') : this.ui.show('main'); return true; }
    return false;
  }

  // Fixed-step simulation without rendering (used by automated tests).
  simulate(seconds, step = 1 / 30) {
    for (let t = 0; t < seconds; t += step) this.tick(step);
  }

  // ---------------- main loop ----------------
  updateMission(dt) {
    const m = this.mission;
    if (!m || m.ended) return;
    m.time += dt;
    m.killcamCooldown -= dt;
    const waves = m.def.waves;
    const canWave = m.def.type === 'waves' || m.alerted;
    if (m.spawnQueue.length) {
      m.spawnTimer -= dt;
      if (m.spawnTimer <= 0) {
        if (this.spawnEnemy(m.spawnQueue[0])) m.spawnQueue.shift();
        m.spawnTimer = rand(0.5, 1.1);
      }
    }
    const alive = this.enemies.filter((e) => e.alive).length;
    if (canWave && !m.spawnQueue.length && m.waveIdx < waves.length - 1) {
      const threshold = m.def.type === 'waves' && m.waveIdx >= 0 ? 1 : 0;
      if (alive <= threshold || m.waveIdx < 0) {
        m.waveTimer -= dt;
        if (m.waveTimer <= 0) { this.nextWave(); m.waveTimer = 3; }
      }
    }
    const allSpawned = m.waveIdx >= waves.length - 1 && !m.spawnQueue.length;
    const vipDone = !m.vip || !m.vip.alive;
    if (allSpawned && alive === 0 && vipDone && this.state === 'playing') this.endMission(true);
    // drop finished corpses from the list
    if (this.enemies.length > 24) this.enemies = this.enemies.filter((e) => !e.removed);
  }

  loop() {
    requestAnimationFrame(() => this.loop());
    const raw = Math.min(0.05, this.clock.getDelta());
    this.tick(raw);
    const cam = this.activeCam;
    this.effects.setScale(cam, this.renderer.domElement.height);
    if (this.composer) this.composer.render();
    else this.renderer.render(this.scene, cam);
  }

  tick(raw) {
    if (this.state === 'menu' || this.state === 'result' || this.state === 'loading') {
      this.menuT = (this.menuT || 0) + raw;
      const t = this.menuT;
      this.camera.position.set(Math.sin(t * 0.06) * 5, 5.5 + Math.sin(t * 0.11) * 1.5, 6);
      this.camera.fov = 60; this.camera.updateProjectionMatrix();
      this.camera.lookAt(Math.sin(t * 0.05) * 6, 6, -90);
      this.effects.update(raw);
    } else if (this.state === 'playing') {
      const dt = raw * this.timeScale;
      this.player.update(raw);
      for (const e of this.enemies) if (!e.removed) e.update(dt);
      this.updateMission(dt);
      this.effects.update(dt);
    } else if (this.state === 'killcam') {
      this.updateKillcam(raw);
      if (this.timeScale > 0) {
        const dt = raw * this.timeScale;
        for (const e of this.enemies) if (!e.removed) e.update(dt);
        this.effects.update(dt);
      }
    }
    this.ui.update(raw);
  }
}

function worldNormal(hit) {
  if (!hit.face) return new THREE.Vector3(0, 1, 0);
  return hit.face.normal.clone().transformDirection(hit.object.matrixWorld);
}

window.__game = new Game();
