// First-person cover shooter player: peek/cover, weapons, scope, recoil, health.
import * as THREE from 'three';
import { rifleViewModel, sniperViewModel } from './models.js';
import { WEAPONS } from './missions.js';
import { clamp, damp, lerp, smooth, rand } from './util.js';
import { library } from './textures.js';

const _v = new THREE.Vector3(), _d = new THREE.Vector3(), _e = new THREE.Euler(0, 0, 0, 'YXZ');

const POSES = {
  rifle: { cover: [0.2, -0.33, -0.36, -0.55, 0.35, 0.35], hip: [0.17, -0.2, -0.42, 0, 0, 0], ads: [0, -0.098, -0.3, 0, 0, 0] },
  sniper: { cover: [0.2, -0.36, -0.42, -0.5, 0.4, 0.35], hip: [0.17, -0.2, -0.45, 0, 0, 0], ads: [0, -0.095, -0.2, 0, 0, 0] },
};

export class Player {
  constructor(game) {
    this.game = game;
    this.camera = game.camera;
    this.vmRoot = new THREE.Group();
    this.camera.add(this.vmRoot);
    this.vms = { rifle: rifleViewModel(), sniper: sniperViewModel() };
    const { tex } = library();
    for (const k in this.vms) {
      const vm = this.vms[k];
      vm.visible = false;
      this.vmRoot.add(vm);
      const fl = new THREE.Sprite(new THREE.SpriteMaterial({ map: tex.flash, blending: THREE.AdditiveBlending, depthWrite: false, color: new THREE.Color(3, 2.5, 1.8) }));
      fl.scale.setScalar(0.22);
      fl.visible = false;
      vm.userData.muzzle.add(fl);
      vm.userData.flash = fl;
    }
    this.headPos = new THREE.Vector3();
    this.coverPoint = new THREE.Vector3();
    this.fireHeld = false;
    this.active = false;
  }

  reset(level, mission, upgrades) {
    const spot = level.playerSpot;
    this.base = spot.pos.clone();
    this.coverTop = spot.coverTop;
    this.coverPoint.set(this.base.x, spot.coverTop - 0.04, this.base.z - 1.2);
    this.roof = mission.vantage === 'roof';
    this.up = upgrades;
    this.maxHp = 100 + 20 * (upgrades.armor || 0);
    this.hp = this.maxHp;
    this.yaw = 0; this.pitch = this.roof ? -0.12 : 0.02;
    this.recoilP = 0; this.recoilY = 0;
    this.peekT = 0; this.latched = false; this.fireHeld = false; this.holdAfterShot = 0;
    this.exposeTime = 0; this.lastHit = -10; this.time = 0;
    this.shake = 0;
    this.scopeT = 0; this.steady = 0; this.heat = 0;
    const zoomMax = WEAPONS.sniper.zoomMax + (upgrades.zoom || 0);
    this.zoomMax = zoomMax;
    this.zoom = Math.min(zoomMax, this.roof ? 4 : 3);
    this.weapons = {};
    for (const k of ['rifle', 'sniper']) {
      const def = WEAPONS[k];
      const dmgUp = k === 'rifle' ? 1 + 0.12 * (upgrades.rifleDmg || 0) : 1 + 0.15 * (upgrades.sniperDmg || 0);
      this.weapons[k] = { def, ammo: def.mag, cooldown: 0, dmg: def.dmg * dmgUp, reloadTime: def.reload * (1 - 0.1 * (upgrades.reload || 0)) };
    }
    this.reloading = 0; this.switching = 0; this.pendingSwitch = null;
    this.setWeapon(mission.loadout || 'rifle', true);
    this.kick = 0; this.boltT = 0;
    this.dead = false;
    this.active = true;
    this.lowHpBeat = 0;
    this.update(0);
  }

  get w() { return this.weapons[this.cur]; }

  setWeapon(k, instant = false) {
    if (instant) {
      this.cur = k;
      for (const key in this.vms) this.vms[key].visible = key === k;
      this.game.ui.weapon(this);
      return;
    }
    if (k === this.cur || this.switching > 0) return;
    this.pendingSwitch = k;
    this.switching = 0.55;
    this.reloading = 0;
  }

  switchWeapon() { this.setWeapon(this.cur === 'rifle' ? 'sniper' : 'rifle'); }

  isExposed() { return this.peekT > 0.45; }
  get scoped() { return this.cur === 'sniper' && this.scopeT > 0.5; }

  aim(dx, dy) {
    if (!this.active) return;
    const s = this.game.save.settings.sens * 0.0042 * (this.camera.fov / 70);
    this.yaw = clamp(this.yaw - dx * s, -1.15, 1.15);
    this.pitch = clamp(this.pitch - dy * s, this.roof ? -0.75 : -0.42, 0.4);
  }

  fireDown() {
    if (!this.active) return;
    this.fireHeld = true;
    if (this.cur === 'rifle' && this.w.ammo <= 0) this.reload();
  }

  fireUp() {
    if (!this.active || !this.fireHeld) return;
    this.fireHeld = false;
    if (this.cur === 'sniper') {
      const w = this.w;
      if (this.peekT > 0.85 && w.cooldown <= 0 && this.reloading <= 0 && this.switching <= 0) {
        if (w.ammo > 0) { this.shoot(); this.holdAfterShot = this.latched ? 0 : 0.5; }
        else { this.game.audio.empty(); this.reload(); }
      }
    }
  }

  togglePeek() {
    if (!this.active) return;
    this.latched = !this.latched;
  }

  reload() {
    const w = this.w;
    if (this.reloading > 0 || this.switching > 0 || w.ammo >= w.def.mag) return;
    this.reloading = w.reloadTime;
    this.game.audio.reload(w.reloadTime);
  }

  setZoom(z) { this.zoom = clamp(z, WEAPONS.sniper.zoomMin, this.zoomMax); }

  get wantPeek() {
    return this.latched || this.fireHeld || this.holdAfterShot > 0;
  }

  shoot() {
    const g = this.game;
    const w = this.w;
    const def = w.def;
    w.ammo--;
    g.stats.shots++;
    this.camera.updateMatrixWorld();
    const origin = this.camera.getWorldPosition(new THREE.Vector3());
    const dir = new THREE.Vector3(0, 0, -1).applyQuaternion(this.camera.getWorldQuaternion(new THREE.Quaternion()));
    let spread = def.key === 'rifle' ? def.spread * (1 + this.heat * 3) : this.scoped ? 0 : def.hipSpread;
    if (spread > 0) {
      dir.x += rand(-spread, spread); dir.y += rand(-spread, spread); dir.z += rand(-spread, spread);
      dir.normalize();
    }
    const vm = this.vms[this.cur];
    const muzzle = vm.userData.muzzle.getWorldPosition(new THREE.Vector3());
    const hit = g.raycast(origin, dir);
    // visual muzzle flash + light
    const fl = vm.userData.flash;
    fl.visible = true; fl.material.rotation = Math.random() * 6; fl.scale.setScalar(def.key === 'sniper' ? 0.35 : 0.2 * rand(0.8, 1.3));
    this.flashT = 0.045;
    g.effects.light(muzzle, 0xffb060, def.key === 'sniper' ? 30 : 14, 0.07, 14);
    g.audio.playerShot(def.key);
    // recoil
    const rec = def.recoil * (this.scoped ? 1.4 : 1);
    this.recoilP += rec; this.pitch += rec * 0.35;
    this.recoilY += rand(-rec, rec) * 0.5;
    this.kick = 1;
    this.heat = Math.min(1, this.heat + 0.12);
    if (def.key === 'sniper') {
      w.cooldown = 1 / def.rate;
      this.boltT = 0.01;
      g.audio.bolt();
      this.shake = Math.max(this.shake, 0.35);
    } else {
      w.cooldown = 1 / def.rate;
      this.shake = Math.max(this.shake, 0.08);
    }
    const end = hit ? hit.point : _v.copy(origin).addScaledVector(dir, 600);
    const from = this.scoped ? _d.copy(origin).addScaledVector(dir, 2).add(new THREE.Vector3(0, -0.15, 0)) : muzzle;
    g.effects.tracer(from, end);
    g.onPlayerShot(hit, dir, w, origin);
    if (w.ammo <= 0) setTimeout(() => { if (this.active && this.cur === def.key) this.reload(); }, def.key === 'sniper' ? 900 : 150);
  }

  damage(amount, fromPos) {
    if (!this.active || this.dead || this.game.state !== 'playing') return;
    this.hp -= amount;
    this.lastHit = this.time;
    this.shake = Math.max(this.shake, 0.25);
    this.game.ui.damage(this, fromPos);
    this.game.stats.damageTaken += amount;
    if (this.hp <= 0) {
      this.hp = 0;
      this.dead = true;
      this.game.onPlayerDied();
    }
  }

  update(dt) {
    if (!this.base) return;
    this.time += dt;
    const w = this.w;
    const T = dt;
    if (this.holdAfterShot > 0) this.holdAfterShot -= T;
    w.cooldown -= T;
    this.heat = Math.max(0, this.heat - T * 1.6);

    // weapon switching / reloading timers
    if (this.switching > 0) {
      const before = this.switching;
      this.switching -= T;
      if (before > 0.275 && this.switching <= 0.275 && this.pendingSwitch) {
        this.setWeapon(this.pendingSwitch, true);
        this.pendingSwitch = null;
      }
    }
    if (this.reloading > 0) {
      this.reloading -= T;
      if (this.reloading <= 0) { w.ammo = w.def.mag; this.reloading = 0; this.game.ui.weapon(this); }
    }

    // peek in/out of cover
    const target = this.active && this.wantPeek && this.switching <= 0 ? 1 : 0;
    const speed = 1 / 0.2;
    this.peekT = target > this.peekT ? Math.min(1, this.peekT + T * speed) : Math.max(0, this.peekT - T * speed);
    this.exposeTime = this.isExposed() ? this.exposeTime + T : 0;

    // scope
    const scopeTarget = this.cur === 'sniper' && this.peekT > 0.7 && this.wantPeek && this.switching <= 0 && this.reloading <= 0 ? 1 : 0;
    this.scopeT = damp(this.scopeT, scopeTarget, 22, T);
    if (scopeTarget) this.steady += T; else this.steady = 0;

    // auto fire
    if (this.active && this.cur === 'rifle' && this.fireHeld && this.peekT > 0.8 && this.reloading <= 0 && this.switching <= 0 && w.cooldown <= 0) {
      if (w.ammo > 0) this.shoot();
      else this.reload();
    }

    // health regen while in cover
    if (this.active && !this.dead && !this.isExposed() && this.time - this.lastHit > 2.5 && this.hp < this.maxHp) {
      this.hp = Math.min(this.maxHp, this.hp + 22 * T);
    }
    if (this.hp < this.maxHp * 0.3 && !this.dead) {
      this.lowHpBeat -= T;
      if (this.lowHpBeat <= 0) { this.game.audio.heartbeat(); this.lowHpBeat = 0.9; }
    }

    // camera placement
    const e = smooth(this.peekT);
    const camY = this.base.y + lerp(0.92, 1.62, e);
    const camZ = this.base.z + lerp(0.1, -0.22, e);
    this.shake = Math.max(0, this.shake - T * 1.8);
    const sh = this.shake * this.shake * 0.05;
    this.camera.position.set(this.base.x + rand(-sh, sh), camY + rand(-sh, sh), camZ);

    // sway when scoped (breathing + fatigue)
    let swayX = 0, swayY = 0;
    if (this.scopeT > 0.01) {
      const stab = 1 - 0.15 * (this.up.stability || 0);
      const fatigue = this.steady < 1.2 ? 1.2 - this.steady * 0.5 : 0.6 + Math.max(0, this.steady - 4) * 0.25;
      const amp = 0.0022 * stab * Math.min(1.8, fatigue) * this.scopeT;
      const t = this.time;
      swayX = (Math.sin(t * 0.83) * 0.7 + Math.sin(t * 1.91) * 0.3) * amp;
      swayY = (Math.sin(t * 1.17 + 1) * 0.6 + Math.sin(t * 2.3) * 0.25) * amp;
    }
    this.recoilP = damp(this.recoilP, 0, 9, T);
    this.recoilY = damp(this.recoilY, 0, 9, T);
    const roll = Math.sin(this.peekT * Math.PI) * 0.025;
    _e.set(this.pitch + this.recoilP + swayY, this.yaw + this.recoilY + swayX, roll, 'YXZ');
    this.camera.quaternion.setFromEuler(_e);

    // field of view
    let fov = 70;
    if (this.cur === 'sniper') fov = lerp(70, 70 / this.zoom, this.scopeT);
    else fov = lerp(70, w.def.adsFov, e);
    this.camera.fov = damp(this.camera.fov, fov, 20, T);
    this.camera.updateProjectionMatrix();
    this.camera.updateMatrixWorld();
    this.camera.getWorldPosition(this.headPos);

    this.updateViewModel(T, e);
  }

  updateViewModel(dt, e) {
    const vm = this.vms[this.cur];
    const P = POSES[this.cur];
    this.kick = damp(this.kick, 0, 14, dt);
    if (this.flashT > 0) { this.flashT -= dt; if (this.flashT <= 0) vm.userData.flash.visible = false; }
    const peekPose = this.cur === 'rifle' ? P.ads : P.hip;
    const t = this.time;
    const pose = [];
    for (let i = 0; i < 6; i++) pose[i] = lerp(P.cover[i], peekPose[i], e);
    // idle breathing
    pose[1] += Math.sin(t * 1.6) * 0.004 * (1 - e * 0.7);
    pose[0] += Math.sin(t * 0.8) * 0.002;
    // reload dip
    if (this.reloading > 0) {
      const u = 1 - this.reloading / this.w.reloadTime;
      const k = Math.sin(u * Math.PI);
      pose[1] -= 0.08 * k; pose[3] -= 0.4 * k; pose[5] += 0.7 * k;
    }
    // switching
    if (this.switching > 0) {
      const k = Math.sin((1 - this.switching / 0.55) * Math.PI);
      pose[1] -= 0.35 * k; pose[3] -= 0.6 * k;
    }
    // recoil kick
    pose[2] += this.kick * (this.cur === 'sniper' ? 0.09 : 0.035);
    pose[3] += this.kick * (this.cur === 'sniper' ? 0.12 : 0.04);
    vm.position.set(pose[0], pose[1], pose[2]);
    vm.rotation.set(pose[3], pose[4], pose[5]);
    // bolt animation
    if (this.cur === 'sniper' && this.boltT > 0) {
      this.boltT += dt;
      const b = vm.userData.bolt;
      const u = this.boltT / 0.9;
      b.position.z = u > 0.3 && u < 0.8 ? 0.06 * Math.sin(((u - 0.3) / 0.5) * Math.PI) : 0;
      b.rotation.z = u > 0.2 && u < 0.9 ? -0.9 * Math.sin(((u - 0.2) / 0.7) * Math.PI) : 0;
      if (u >= 1) this.boltT = 0;
    }
    this.vmRoot.visible = this.scopeT < 0.5 && this.game.state !== 'killcam';
  }
}
