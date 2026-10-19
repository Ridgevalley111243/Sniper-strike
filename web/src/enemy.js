// Articulated soldier models + cover-based combat AI.
import * as THREE from 'three';
import { library } from './textures.js';
import { geo, mesh, enemyRifle } from './models.js';
import { clamp, damp, rand } from './util.js';

export const ENEMY_TYPES = {
  rifle:  { hp: 100, acc: 0.34, dmg: 7, burst: [3, 5], rof: 0.12, speed: 4.6, peek: [1.4, 2.8], cover: [1.4, 3.2], scale: 1, reward: 10 },
  heavy:  { hp: 260, acc: 0.3, dmg: 10, burst: [5, 8], rof: 0.1, speed: 3.4, peek: [2.0, 3.4], cover: [1.6, 3.0], scale: 1.12, reward: 25, armor: 0.75 },
  sniper: { hp: 100, acc: 0.85, dmg: 34, burst: [1, 1], rof: 1, speed: 4.2, peek: [3.0, 3.0], cover: [2.5, 4.5], scale: 1, reward: 20, aimTime: 2.4 },
  guard:  { hp: 110, acc: 0.32, dmg: 7, burst: [3, 5], rof: 0.12, speed: 4.6, peek: [1.4, 2.8], cover: [1.4, 3.2], scale: 1, reward: 12 },
  vip:    { hp: 100, acc: 0, dmg: 0, burst: [0, 0], rof: 1, speed: 1.35, peek: [1, 1], cover: [1, 1], scale: 1, reward: 100, unarmed: true },
};

const _v = new THREE.Vector3(), _w = new THREE.Vector3(), _q = new THREE.Vector3();

function capsule(r, len, key) {
  return geo('cap' + key, () => new THREE.CapsuleGeometry(r, Math.max(0.01, len - r * 2), 4, 10));
}

function build(type) {
  const m = library().mat;
  const uni = m.uniforms[type] || m.uniforms.rifle;
  const skin = m.skins[Math.floor(Math.random() * m.skins.length)];
  const vest = type === 'heavy' ? m.vestDark : type === 'vip' ? m.shirt : type === 'guard' ? m.vestDark : m.vest;
  const root = new THREE.Group();
  root.rotation.order = 'YXZ';
  const body = new THREE.Group(); // pivot used for falling
  root.add(body);
  const hips = new THREE.Group(); hips.position.y = 0.95; body.add(hips);
  const pelvis = mesh(geo('pelvis', () => new THREE.BoxGeometry(0.34, 0.18, 0.22)), uni);
  hips.add(pelvis);
  const torso = new THREE.Group(); torso.position.y = 0.08; hips.add(torso);
  const chest = mesh(capsule(0.17, 0.5, 'chest'), type === 'vip' ? uni : uni);
  chest.scale.set(1.2, 1, 0.75); chest.position.y = 0.27;
  torso.add(chest);
  const vestM = mesh(geo('vest' + type, () => type === 'vip'
    ? new THREE.BoxGeometry(0.16, 0.36, 0.05).translate(0, 0, 0.12)
    : new THREE.BoxGeometry(0.4, 0.38, 0.29)), vest);
  vestM.position.y = 0.3;
  torso.add(vestM);
  if (type === 'vip') {
    const tie = mesh(geo('tie', () => new THREE.BoxGeometry(0.04, 0.26, 0.02)), m.tie);
    tie.position.set(0, 0.32, 0.15); torso.add(tie);
  }
  const neck = mesh(geo('neck', () => new THREE.CylinderGeometry(0.05, 0.06, 0.1, 8)), skin);
  neck.position.y = 0.55; torso.add(neck);
  const head = new THREE.Group(); head.position.y = 0.58; torso.add(head);
  const skull = mesh(geo('head', () => new THREE.SphereGeometry(0.115, 14, 10).scale(0.92, 1.08, 1)), type === 'rifle' ? m.balaclava : skin);
  skull.position.y = 0.1; head.add(skull);
  const hitHead = [skull];
  if (type === 'rifle' || type === 'heavy' || type === 'guard') {
    const hm = type === 'rifle' ? m.helmet : m.helmetDark;
    const helmet = mesh(geo('helmet', () => new THREE.SphereGeometry(0.135, 14, 8, 0, Math.PI * 2, 0, Math.PI * 0.55)), hm);
    helmet.position.y = 0.13; head.add(helmet); hitHead.push(helmet);
    if (type === 'heavy') {
      const visor = mesh(geo('visor', () => new THREE.BoxGeometry(0.2, 0.07, 0.04)), m.visor);
      visor.position.set(0, 0.11, 0.11); head.add(visor);
    } else {
      const gog = mesh(geo('goggles', () => new THREE.BoxGeometry(0.18, 0.045, 0.03)), m.visor);
      gog.position.set(0, 0.12, 0.105); head.add(gog);
    }
  } else if (type === 'sniper') {
    const cap = mesh(geo('cap', () => new THREE.CylinderGeometry(0.12, 0.125, 0.07, 12)), uni);
    cap.position.y = 0.2; head.add(cap);
    const brim = mesh(geo('brim', () => new THREE.BoxGeometry(0.16, 0.015, 0.12)), uni);
    brim.position.set(0, 0.17, 0.12); head.add(brim);
    hitHead.push(cap);
  } else {
    const hair = mesh(geo('hair', () => new THREE.SphereGeometry(0.122, 12, 6, 0, Math.PI * 2, 0, Math.PI * 0.45)), m.hair);
    hair.position.y = 0.12; head.add(hair); hitHead.push(hair);
  }

  const limbs = [];
  const mkArm = (s) => {
    const a = new THREE.Group(); a.position.set(s * 0.24, 0.44, 0); torso.add(a);
    const up = mesh(capsule(0.055, 0.32, 'uarm'), uni); up.position.y = -0.15; a.add(up);
    const f = new THREE.Group(); f.position.y = -0.3; a.add(f);
    const lo = mesh(capsule(0.048, 0.28, 'farm'), uni); lo.position.y = -0.13; f.add(lo);
    const hand = mesh(geo('hand', () => new THREE.SphereGeometry(0.05, 8, 6)), type === 'vip' ? skin : m.glove);
    hand.position.y = -0.28; f.add(hand);
    limbs.push(up, lo, hand);
    return [a, f];
  };
  const [armL, foreL] = mkArm(-1);
  const [armR, foreR] = mkArm(1);
  const mkLeg = (s) => {
    const l = new THREE.Group(); l.position.set(s * 0.1, -0.05, 0); hips.add(l);
    const th = mesh(capsule(0.078, 0.46, 'thigh'), uni); th.position.y = -0.22; l.add(th);
    const sh = new THREE.Group(); sh.position.y = -0.45; l.add(sh);
    const shin = mesh(capsule(0.062, 0.42, 'shin'), uni); shin.position.y = -0.2; sh.add(shin);
    const boot = mesh(geo('boot', () => new THREE.BoxGeometry(0.11, 0.1, 0.26)), m.boot); boot.position.set(0, -0.43, 0.04); sh.add(boot);
    limbs.push(th, shin, boot);
    return [l, sh];
  };
  const [legL, shinL] = mkLeg(-1);
  const [legR, shinR] = mkLeg(1);

  let rifle = null;
  if (type !== 'vip') {
    rifle = enemyRifle(type === 'sniper');
    rifle.position.set(0.1, 0.36, 0.2);
    torso.add(rifle);
  }
  const parts = { root, body, hips, torso, head, armL, armR, foreL, foreR, legL, legR, shinL, shinR, rifle };
  const hit = [];
  for (const h of hitHead) { h.userData.part = 'head'; hit.push(h); }
  for (const b of [pelvis, chest, vestM, neck]) { b.userData.part = 'body'; hit.push(b); }
  for (const l of limbs) { l.userData.part = 'limb'; hit.push(l); }
  return { parts, hit };
}

// joint targets per pose (radians)
function poseTargets(e, out) {
  const t = e.animT;
  const s = e.state;
  const P = out;
  P.hipsY = 0.95; P.torsoX = 0; P.torsoY = 0; P.headX = 0;
  P.legL = 0; P.legR = 0; P.shinL = 0; P.shinR = 0;
  // arms: aim pose by default (holding rifle forward)
  P.armLX = -1.25; P.armLZ = 0.55; P.foreLX = -0.5;
  P.armRX = -1.05; P.armRZ = -0.25; P.foreRX = -0.9;
  if (e.type.unarmed) { P.armLX = 0.05; P.armLZ = 0.08; P.foreLX = -0.15; P.armRX = 0.05; P.armRZ = -0.08; P.foreRX = -0.15; }

  if (s === 'run' || s === 'walk' || s === 'flee') {
    const ph = e.runPhase;
    const amp = s === 'walk' ? 0.45 : 0.85;
    P.legL = Math.sin(ph) * amp; P.legR = -Math.sin(ph) * amp;
    P.shinL = 0.15 + Math.max(0, Math.sin(ph + 1.6)) * amp * 1.3;
    P.shinR = 0.15 + Math.max(0, -Math.sin(ph + 1.6)) * amp * 1.3;
    P.hipsY = 0.95 + Math.abs(Math.cos(ph)) * (s === 'walk' ? 0.02 : 0.06) - (s === 'walk' ? 0 : 0.04);
    P.torsoX = s === 'walk' ? 0.03 : 0.25;
    if (e.type.unarmed) {
      P.armLX = -Math.sin(ph) * amp * 0.8; P.armRX = Math.sin(ph) * amp * 0.8;
      P.foreLX = P.foreRX = s === 'walk' ? -0.2 : -1.2;
    } else {
      P.armLX = -0.9; P.armRX = -0.7; P.foreRX = -1.1;
    }
  } else if (s === 'cover' || (s === 'hit' && e.prevState === 'cover')) {
    P.hipsY = 0.42; P.torsoX = 0.75; P.headX = -0.35;
    P.legL = -1.25; P.legR = -0.6; P.shinL = 2.1; P.shinR = 1.9;
    P.armLX = -1.0; P.armRX = -0.7;
  } else if (s === 'idle') {
    P.torsoY = Math.sin(t * 0.4) * 0.25;
    P.headX = Math.sin(t * 0.7) * 0.08;
    if (!e.type.unarmed) { P.armLX = -0.7; P.armLZ = 0.5; P.armRX = -0.4; P.foreRX = -1.2; }
  }
  if (s === 'peek' || s === 'snipe') {
    P.torsoX = clamp(e.aimPitch, -0.4, 0.5);
    P.legL = -0.15; P.legR = 0.15; P.shinR = 0.1; P.shinL = 0.2;
    if (s === 'peek') P.torsoX += e.recoil * 0.4;
  }
  if (s === 'hit') {
    P.torsoX -= 0.35; P.headX = -0.3;
  }
  return P;
}

const POSE = {};

export class Enemy {
  constructor(game, typeKey, opts = {}) {
    this.game = game;
    this.typeKey = typeKey;
    this.type = ENEMY_TYPES[typeKey];
    const { parts, hit } = build(typeKey);
    this.p = parts;
    this.root = parts.root;
    this.hitMeshes = hit;
    for (const h of hit) h.userData.enemy = this;
    this.root.scale.setScalar(this.type.scale);
    this.hp = this.type.hp * (opts.hpMul ?? 1);
    this.alive = true;
    this.state = opts.state || 'run';
    this.prevState = null;
    this.timer = 0;
    this.animT = Math.random() * 10;
    this.runPhase = Math.random() * 6;
    this.recoil = 0;
    this.aimPitch = 0;
    this.burstLeft = 0;
    this.shotTimer = 0;
    this.deadT = 0;
    this.fall = 0;
    this.fallDir = 1;
    this.flingVel = null;
    this.cover = null;
    this.path = opts.path || null;
    this.pathIdx = 1;
    this.follow = opts.follow || null;
    this.followOffset = opts.followOffset || new THREE.Vector3();
    this.isVip = typeKey === 'vip';
    this.alerted = opts.alerted ?? true;
    this.peekCount = 0;
    this.root.position.copy(opts.pos || new THREE.Vector3());
    if (this.isVip) this.addMarker();
    if (typeKey === 'sniper') this.laser = game.effects.makeLaser();
    game.scene.add(this.root);
    for (const k in this.p) if (this.p[k] && this.p[k].isGroup) this.p[k].userData.rx = 0;
    if (opts.cover) this.assignCover(opts.cover);
  }

  addMarker() {
    const { tex } = library();
    const s = new THREE.Sprite(new THREE.SpriteMaterial({ map: tex.marker, depthTest: false, depthWrite: false, sizeAttenuation: false, color: new THREE.Color(2, 2, 2) }));
    s.scale.setScalar(0.035);
    s.position.y = 2.35;
    s.renderOrder = 999;
    this.root.add(s);
    this.marker = s;
  }

  assignCover(cp) {
    if (this.cover) this.cover.taken = null;
    this.cover = cp;
    if (cp) cp.taken = this;
  }

  get headPos() {
    return this.p.head.getWorldPosition(_q).setY(_q.y + 0.1);
  }

  alert() {
    if (this.alerted || !this.alive) return;
    this.alerted = true;
    if (this.isVip) {
      this.state = 'flee';
      if (this.marker) this.marker.material.color.setRGB(3, 0.6, 0.4);
      return;
    }
    if (this.cover) { this.state = 'cover'; this.timer = rand(0.3, 1.2); return; }
    const cp = this.game.level.pickCover(false, this.root.position);
    if (cp) { this.assignCover(cp); this.state = 'run'; }
    else { this.state = 'peek'; this.timer = 2; }
  }

  moveTowards(target, speed, dt) {
    _v.subVectors(target, this.root.position); _v.y = 0;
    const d = _v.length();
    if (d < 0.05) return true;
    const step = Math.min(d, speed * dt);
    _v.multiplyScalar(step / d);
    this.root.position.add(_v);
    const yaw = Math.atan2(_v.x, _v.z);
    this.root.rotation.y = damp(this.root.rotation.y, this.root.rotation.y + angleDiff(this.root.rotation.y, yaw), 10, dt);
    if (target.y !== undefined) this.root.position.y = damp(this.root.position.y, target.y, 12, dt);
    return d - step < 0.05;
  }

  facePlayer(dt, rate = 8) {
    const pp = this.game.player.headPos;
    const yaw = Math.atan2(pp.x - this.root.position.x, pp.z - this.root.position.z);
    this.root.rotation.y += angleDiff(this.root.rotation.y, yaw) * Math.min(1, rate * dt);
    const dist = Math.hypot(pp.x - this.root.position.x, pp.z - this.root.position.z);
    this.aimPitch = -Math.atan2(pp.y - (this.root.position.y + 1.45), dist);
  }

  update(dt) {
    this.animT += dt;
    if (!this.alive) { this.updateDeath(dt); return; }
    const T = this.type;
    this.timer -= dt;
    this.recoil = damp(this.recoil, 0, 12, dt);
    switch (this.state) {
      case 'run': {
        if (!this.cover) { this.state = 'peek'; this.timer = rand(...T.peek); break; }
        this.runPhase += dt * T.speed * 2.4;
        if (this.moveTowards(this.cover.pos, T.speed, dt)) {
          this.state = 'cover'; this.timer = rand(0.6, 1.4);
        }
        break;
      }
      case 'walk': {
        this.runPhase += dt * 4;
        if (this.follow) {
          if (!this.follow.alive || this.follow.alerted) { this.alert(); break; }
          _w.copy(this.followOffset).applyAxisAngle(THREE.Object3D.DEFAULT_UP, this.follow.root.rotation.y).add(this.follow.root.position);
          const d = _w.distanceTo(this.root.position);
          this.moveTowards(_w, d > 1.5 ? 1.8 : this.follow.type.speed, dt);
        } else if (this.path) {
          const tgt = this.path[this.pathIdx];
          if (this.moveTowards(tgt, T.speed, dt)) {
            this.pathIdx++;
            if (this.pathIdx >= this.path.length) { this.escaped(); return; }
          }
        }
        break;
      }
      case 'flee': {
        this.runPhase += dt * 9;
        const tgt = this.path[this.pathIdx];
        if (this.moveTowards(tgt, 3.9, dt)) {
          this.pathIdx++;
          if (this.pathIdx >= this.path.length) { this.escaped(); return; }
        }
        break;
      }
      case 'idle': {
        break;
      }
      case 'cover': {
        this.facePlayer(dt, 4);
        if (this.timer <= 0) {
          this.peekCount++;
          // occasionally relocate to keep the fight dynamic
          if (this.peekCount > 2 && Math.random() < 0.22 && !this.cover?.roof) {
            const cp = this.game.level.pickCover(false, this.root.position);
            if (cp && cp !== this.cover) { this.assignCover(cp); this.state = 'run'; this.peekCount = 0; break; }
          }
          if (this.typeKey === 'sniper') {
            this.state = 'snipe'; this.timer = T.aimTime; this.beepT = 0;
          } else {
            this.state = 'peek'; this.timer = rand(...T.peek);
            this.burstLeft = 0; this.shotTimer = rand(0.35, 0.6);
          }
        }
        break;
      }
      case 'peek': {
        this.facePlayer(dt, 10);
        this.shotTimer -= dt;
        if (this.shotTimer <= 0) {
          if (this.burstLeft <= 0) {
            this.burstLeft = Math.round(rand(...T.burst));
          }
          this.fire();
          this.burstLeft--;
          this.shotTimer = this.burstLeft > 0 ? T.rof * rand(0.85, 1.2) : rand(0.5, 0.9);
        }
        if (this.timer <= 0) { this.state = this.cover ? 'cover' : 'peek'; this.timer = rand(...T.cover); }
        break;
      }
      case 'snipe': {
        this.facePlayer(dt, 10);
        this.updateLaser(1 - this.timer / T.aimTime);
        this.beepT -= dt;
        if (this.beepT <= 0) {
          this.beepT = 0.12 + (this.timer / T.aimTime) * 0.5;
          if (this.distToPlayer() < 200) this.game.audio.beep();
        }
        if (this.timer <= 0) {
          this.fire();
          this.laser.visible = false;
          this.state = 'cover'; this.timer = rand(...T.cover);
        }
        break;
      }
      case 'hit': {
        if (this.timer <= 0) {
          const back = this.prevState === 'peek' && Math.random() < 0.5 && this.cover ? 'cover' : this.prevState;
          this.state = back || 'cover';
          this.timer = back === 'cover' ? rand(...T.cover) : rand(0.6, 1.5);
        }
        break;
      }
    }
    if (this.laser && this.state !== 'snipe') this.laser.visible = false;
    this.animate(dt);
  }

  updateLaser(k) {
    const l = this.laser;
    const muzzle = this.p.rifle.userData.muzzle.getWorldPosition(_v);
    const target = this.game.player.headPos;
    _w.subVectors(target, muzzle);
    const len = _w.length();
    l.position.copy(muzzle);
    l.lookAt(target);
    l.scale.set(1 + k * 1.5, 1 + k * 1.5, len);
    l.material.opacity = 0.15 + k * 0.55 + Math.sin(this.animT * 40) * 0.05;
    l.visible = true;
  }

  distToPlayer() { return this.root.position.distanceTo(this.game.player.headPos); }

  fire() {
    const g = this.game;
    const T = this.type;
    if (T.unarmed) return;
    const muzzle = this.p.rifle.userData.muzzle.getWorldPosition(new THREE.Vector3());
    const player = g.player;
    const target = player.headPos.clone();
    const dist = muzzle.distanceTo(target);
    const exposed = player.isExposed();
    const settle = clamp(player.exposeTime / 0.8, 0.25, 1);
    const distK = this.typeKey === 'sniper' ? 1 : clamp(1.15 - dist / 140, 0.3, 1);
    const chance = exposed ? T.acc * distK * settle * g.difficulty : 0;
    const hit = Math.random() < chance;
    this.recoil = 1;
    g.effects.muzzle(muzzle, this.typeKey === 'sniper' ? 0.9 : 0.6);
    g.effects.light(muzzle, 0xffa050, 8, 0.06, 10);
    const pan = this.panFromPlayer();
    g.audio.enemyShot(dist, pan, this.typeKey === 'sniper');
    if (hit) {
      player.damage(T.dmg, this.root.position);
      g.effects.tracer(muzzle, target.add(_v.set(rand(-0.3, 0.3), -0.25, rand(-0.3, 0.3))), true);
    } else if (!exposed && player.coverPoint) {
      // round smacks into the player's cover
      const cp = player.coverPoint;
      const hitP = new THREE.Vector3(cp.x + rand(-1, 1), cp.y + rand(-0.25, 0.02), cp.z);
      g.effects.tracer(muzzle, hitP, true);
      setTimeout(() => {
        g.effects.impact(hitP, _w.set(0, 0.5, 1).normalize());
        if (Math.random() < 0.35) g.audio.impact('ricochet', rand(-0.5, 0.5));
        else g.audio.impact('world', rand(-0.3, 0.3));
      }, Math.min(400, dist * 4));
    } else {
      const miss = target.clone().add(_v.set(rand(-1.4, 1.4), rand(-0.6, 1.2), rand(-1.4, 1.4)));
      _w.subVectors(miss, muzzle).multiplyScalar(1.6).add(muzzle);
      g.effects.tracer(muzzle, _w, true);
      if (Math.random() < 0.5) setTimeout(() => g.audio.whiz(pan), Math.min(400, dist * 3));
    }
  }

  panFromPlayer() {
    const cam = this.game.camera;
    _v.subVectors(this.root.position, cam.position).normalize();
    _w.set(1, 0, 0).applyQuaternion(cam.quaternion);
    return _v.dot(_w);
  }

  // returns { killed }
  damage(amount, part, dir, explosive = false) {
    if (!this.alive) return { killed: false };
    let a = amount;
    if (this.type.armor && part !== 'head' && !explosive) a *= this.type.armor;
    this.hp -= a;
    this.alert();
    if (this.hp <= 0) {
      this.die(dir, explosive, part === 'head');
      return { killed: true };
    }
    if (this.state !== 'hit' && this.state !== 'run' && this.state !== 'flee' && this.state !== 'walk') {
      this.prevState = this.state;
      this.state = 'hit';
      this.timer = 0.3;
    }
    return { killed: false };
  }

  die(dir, explosive, head) {
    this.alive = false;
    this.state = 'dead';
    this.baseY = this.root.position.y;
    this.assignCover(null);
    if (this.laser) this.laser.visible = false;
    if (this.marker) this.marker.visible = false;
    // fall away from the shot
    const local = _v.copy(dir || _w.set(0, 0, -1)).applyAxisAngle(THREE.Object3D.DEFAULT_UP, -this.root.rotation.y);
    this.fallDir = local.z > 0 ? -1 : 1; // topple along the bullet's path
    this.fallSide = clamp(local.x, -1, 1) * 0.4;
    this.fallSpeed = head ? 4.2 : 2.6;
    if (explosive) {
      this.flingVel = new THREE.Vector3(dir.x * 7, 6 + Math.random() * 3, dir.z * 7);
      this.fallSpeed = 7;
    }
    for (const h of this.hitMeshes) h.userData.part = null;
    this.game.onEnemyRemoved(this);
  }

  updateDeath(dt) {
    this.deadT += dt;
    const p = this.p;
    if (this.flingVel) {
      this.flingVel.y -= 18 * dt;
      this.root.position.addScaledVector(this.flingVel, dt);
      if (this.root.position.y < this.groundY()) {
        this.root.position.y = this.groundY();
        this.flingVel.multiplyScalar(0.3);
        if (Math.abs(this.flingVel.y) < 1) this.flingVel = null;
        else this.flingVel.y = Math.abs(this.flingVel.y);
      }
    }
    // accelerate fall like a toppling body
    this.fallV = (this.fallV || 0) + this.fallSpeed * dt;
    this.fall = Math.min(Math.PI / 2 - 0.08, this.fall + this.fallV * dt);
    this.root.rotation.x = -this.fall * this.fallDir;
    this.root.rotation.z = this.fall * this.fallSide;
    const k = Math.min(1, this.deadT * 4);
    p.legL.rotation.x = damp(p.legL.rotation.x, -0.4 * this.fallDir, 6, dt);
    p.legR.rotation.x = damp(p.legR.rotation.x, -0.1 * this.fallDir, 6, dt);
    p.shinL.rotation.x = damp(p.shinL.rotation.x, 0.6 * k, 6, dt);
    p.shinR.rotation.x = damp(p.shinR.rotation.x, 0.3 * k, 6, dt);
    p.armL.rotation.x = damp(p.armL.rotation.x, -2.6 * this.fallDir, 4, dt);
    p.armR.rotation.x = damp(p.armR.rotation.x, -2.2 * this.fallDir, 4, dt);
    p.hips.position.y = damp(p.hips.position.y, 0.75, 5, dt);
    p.torso.rotation.x = damp(p.torso.rotation.x, 0.2 * this.fallDir, 5, dt);
    p.head.rotation.x = damp(p.head.rotation.x, -0.6 * this.fallDir, 5, dt);
    if (this.p.rifle && this.deadT > 0.25 && this.p.rifle.parent === p.torso) {
      // drop the weapon
      this.p.rifle.getWorldPosition(_v);
      this.game.scene.attach(this.p.rifle);
      this.droppedV = new THREE.Vector3(rand(-1, 1), 1, rand(-1, 1));
    }
    if (this.droppedV) {
      const r = this.p.rifle;
      this.droppedV.y -= 9.8 * dt;
      r.position.addScaledVector(this.droppedV, dt);
      r.rotation.x += dt * 3;
      if (r.position.y < this.groundY() + 0.05) { r.position.y = this.groundY() + 0.05; this.droppedV = null; }
    }
    if (this.deadT > 7) {
      this.root.position.y -= dt * 0.4;
      if (this.deadT > 9) this.remove();
    }
  }

  groundY() { return this.baseY ?? 0; }

  animate(dt) {
    const P = poseTargets(this, POSE);
    const p = this.p, r = 14;
    p.hips.position.y = damp(p.hips.position.y, P.hipsY, r, dt);
    p.torso.rotation.x = damp(p.torso.rotation.x, P.torsoX, r, dt);
    p.torso.rotation.y = damp(p.torso.rotation.y, P.torsoY, r, dt);
    p.head.rotation.x = damp(p.head.rotation.x, P.headX, r, dt);
    p.legL.rotation.x = damp(p.legL.rotation.x, P.legL, r, dt);
    p.legR.rotation.x = damp(p.legR.rotation.x, P.legR, r, dt);
    p.shinL.rotation.x = damp(p.shinL.rotation.x, P.shinL, r, dt);
    p.shinR.rotation.x = damp(p.shinR.rotation.x, P.shinR, r, dt);
    p.armL.rotation.x = damp(p.armL.rotation.x, P.armLX, r, dt);
    p.armL.rotation.z = damp(p.armL.rotation.z, P.armLZ, r, dt);
    p.armR.rotation.x = damp(p.armR.rotation.x, P.armRX, r, dt);
    p.armR.rotation.z = damp(p.armR.rotation.z, P.armRZ, r, dt);
    p.foreL.rotation.x = damp(p.foreL.rotation.x, P.foreLX, r, dt);
    p.foreR.rotation.x = damp(p.foreR.rotation.x, P.foreRX, r, dt);
    if (p.rifle) {
      const running = this.state === 'run';
      p.rifle.rotation.x = damp(p.rifle.rotation.x, running ? 0.5 : this.state === 'cover' ? -0.6 : -this.recoil * 0.15, r, dt);
      p.rifle.position.z = damp(p.rifle.position.z, 0.2 - this.recoil * 0.05, r, dt);
    }
  }

  escaped() {
    this.alive = false;
    this.state = 'gone';
    this.game.onVipEscaped(this);
    this.remove();
  }

  remove() {
    if (this.removed) return;
    this.removed = true;
    this.assignCover(null);
    this.root.removeFromParent();
    if (this.p.rifle) this.p.rifle.removeFromParent();
    if (this.laser) { this.laser.removeFromParent(); this.laser.material.dispose(); }
    if (this.marker) this.marker.material.dispose();
  }
}

function angleDiff(a, b) {
  let d = b - a;
  while (d > Math.PI) d -= Math.PI * 2;
  while (d < -Math.PI) d += Math.PI * 2;
  return d;
}
