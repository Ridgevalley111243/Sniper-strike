// Particles, tracers, muzzle flashes, bullet-hole decals, dynamic flash lights.
import * as THREE from 'three';
import { library } from './textures.js';
import { rand } from './util.js';

const pVert = /* glsl */ `
attribute float psize; attribute float palpha; attribute vec3 pcolor;
varying vec3 vColor; varying float vAlpha;
uniform float scale;
void main() {
  vColor = pcolor; vAlpha = palpha;
  vec4 mv = modelViewMatrix * vec4(position, 1.0);
  gl_PointSize = psize * scale / max(0.05, -mv.z);
  gl_Position = projectionMatrix * mv;
}`;
const pFrag = /* glsl */ `
uniform sampler2D map;
varying vec3 vColor; varying float vAlpha;
void main() {
  vec4 t = texture2D(map, gl_PointCoord);
  gl_FragColor = vec4(vColor * t.rgb, t.a * vAlpha);
  #include <tonemapping_fragment>
  #include <colorspace_fragment>
}`;

class ParticleSystem {
  constructor(cap, tex, blending) {
    this.cap = cap; this.n = 0;
    this.pos = new Float32Array(cap * 3); this.vel = new Float32Array(cap * 3);
    this.col = new Float32Array(cap * 3); this.size = new Float32Array(cap);
    this.alpha = new Float32Array(cap);
    this.life = new Float32Array(cap); this.max = new Float32Array(cap);
    this.s0 = new Float32Array(cap); this.grow = new Float32Array(cap);
    this.a0 = new Float32Array(cap); this.grav = new Float32Array(cap); this.drag = new Float32Array(cap);
    const g = new THREE.BufferGeometry();
    this.aPos = new THREE.BufferAttribute(this.pos, 3).setUsage(THREE.DynamicDrawUsage);
    this.aCol = new THREE.BufferAttribute(this.col, 3).setUsage(THREE.DynamicDrawUsage);
    this.aSize = new THREE.BufferAttribute(this.size, 1).setUsage(THREE.DynamicDrawUsage);
    this.aAlpha = new THREE.BufferAttribute(this.alpha, 1).setUsage(THREE.DynamicDrawUsage);
    g.setAttribute('position', this.aPos); g.setAttribute('pcolor', this.aCol);
    g.setAttribute('psize', this.aSize); g.setAttribute('palpha', this.aAlpha);
    g.setDrawRange(0, 0);
    this.uniforms = { map: { value: tex }, scale: { value: 400 } };
    this.mat = new THREE.ShaderMaterial({
      uniforms: this.uniforms, vertexShader: pVert, fragmentShader: pFrag,
      transparent: true, depthWrite: false, blending,
    });
    this.points = new THREE.Points(g, this.mat);
    this.points.frustumCulled = false;
    this.points.renderOrder = 10;
    this.geo = g;
  }

  emit(p, v, color, size, life, o = {}) {
    if (this.n >= this.cap) return;
    const i = this.n++, i3 = i * 3;
    this.pos[i3] = p.x; this.pos[i3 + 1] = p.y; this.pos[i3 + 2] = p.z;
    this.vel[i3] = v.x; this.vel[i3 + 1] = v.y; this.vel[i3 + 2] = v.z;
    this.col[i3] = color.r; this.col[i3 + 1] = color.g; this.col[i3 + 2] = color.b;
    this.size[i] = this.s0[i] = size;
    this.life[i] = 0; this.max[i] = life;
    this.grow[i] = o.grow ?? 0; this.a0[i] = o.alpha ?? 1;
    this.grav[i] = o.gravity ?? 0; this.drag[i] = o.drag ?? 0;
    this.alpha[i] = this.a0[i];
  }

  update(dt) {
    let i = 0;
    while (i < this.n) {
      this.life[i] += dt;
      if (this.life[i] >= this.max[i]) { this._kill(i); continue; }
      const i3 = i * 3, k = 1 - Math.min(1, this.drag[i] * dt);
      this.vel[i3] *= k; this.vel[i3 + 1] = this.vel[i3 + 1] * k - this.grav[i] * dt; this.vel[i3 + 2] *= k;
      this.pos[i3] += this.vel[i3] * dt; this.pos[i3 + 1] += this.vel[i3 + 1] * dt; this.pos[i3 + 2] += this.vel[i3 + 2] * dt;
      const u = this.life[i] / this.max[i];
      this.size[i] = this.s0[i] * (1 + this.grow[i] * u);
      this.alpha[i] = this.a0[i] * (1 - u) * Math.min(1, u * 12 + 0.3);
      i++;
    }
    this.geo.setDrawRange(0, this.n);
    for (const a of [this.aPos, this.aCol, this.aSize, this.aAlpha]) a.needsUpdate = true;
  }

  _kill(i) {
    const j = --this.n;
    if (i === j) return;
    const i3 = i * 3, j3 = j * 3;
    for (let k = 0; k < 3; k++) {
      this.pos[i3 + k] = this.pos[j3 + k]; this.vel[i3 + k] = this.vel[j3 + k]; this.col[i3 + k] = this.col[j3 + k];
    }
    for (const arr of [this.size, this.life, this.max, this.s0, this.grow, this.a0, this.grav, this.drag, this.alpha]) arr[i] = arr[j];
  }

  clear() { this.n = 0; this.geo.setDrawRange(0, 0); }
}

const _v = new THREE.Vector3(), _c = new THREE.Color(), _d = new THREE.Vector3();

export class Effects {
  constructor(game) {
    this.game = game;
    const { tex } = library();
    const scene = game.scene;
    this.add = new ParticleSystem(1500, tex.soft, THREE.AdditiveBlending);
    this.norm = new ParticleSystem(1500, tex.smoke, THREE.NormalBlending);
    scene.add(this.add.points, this.norm.points);

    // tracers
    const tg = new THREE.BoxGeometry(1, 1, 1); tg.translate(0, 0, 0.5);
    this.tracerMatP = new THREE.MeshBasicMaterial({ color: new THREE.Color(6, 4.5, 2), blending: THREE.AdditiveBlending, transparent: true, depthWrite: false });
    this.tracerMatE = new THREE.MeshBasicMaterial({ color: new THREE.Color(7, 2.2, 0.8), blending: THREE.AdditiveBlending, transparent: true, depthWrite: false });
    this.tracers = [];
    for (let i = 0; i < 40; i++) {
      const m = new THREE.Mesh(tg, this.tracerMatP);
      m.visible = false; m.frustumCulled = false;
      scene.add(m);
      this.tracers.push({ mesh: m, active: false, start: new THREE.Vector3(), dir: new THREE.Vector3(), len: 0, t: 0, speed: 0, seg: 0 });
    }

    // world-space muzzle flash sprites
    this.flashMat = new THREE.SpriteMaterial({ map: tex.flash, blending: THREE.AdditiveBlending, depthWrite: false, transparent: true, color: new THREE.Color(3, 2.6, 2) });
    this.flashes = [];
    for (let i = 0; i < 12; i++) {
      const s = new THREE.Sprite(this.flashMat.clone());
      s.visible = false; scene.add(s);
      this.flashes.push({ s, t: 0 });
    }

    // bullet hole decals
    const dg = new THREE.PlaneGeometry(0.14, 0.14);
    this.decalMat = new THREE.MeshBasicMaterial({ map: tex.decal, transparent: true, depthWrite: false, polygonOffset: true, polygonOffsetFactor: -4 });
    this.decals = [];
    this.decalIdx = 0;
    for (let i = 0; i < 80; i++) {
      const m = new THREE.Mesh(dg, this.decalMat);
      m.visible = false; m.matrixAutoUpdate = false; scene.add(m);
      this.decals.push(m);
    }

    // pooled flash lights (fixed count so shaders never recompile)
    this.lights = [];
    for (let i = 0; i < 3; i++) {
      const l = new THREE.PointLight(0xffaa55, 0, 18, 2);
      scene.add(l);
      this.lights.push({ l, t: 0, dur: 1, peak: 0 });
    }
    this.lightIdx = 0;

    // laser lines for enemy snipers
    const lg = new THREE.CylinderGeometry(0.012, 0.012, 1, 6, 1, true);
    lg.rotateX(Math.PI / 2); lg.translate(0, 0, 0.5);
    this.laserGeo = lg;
  }

  makeLaser() {
    const m = new THREE.Mesh(this.laserGeo, new THREE.MeshBasicMaterial({
      color: new THREE.Color(8, 0.2, 0.1), transparent: true, opacity: 0.4, blending: THREE.AdditiveBlending, depthWrite: false,
    }));
    m.visible = false; m.frustumCulled = false;
    this.game.scene.add(m);
    return m;
  }

  setScale(camera, height) {
    const s = height / (2 * Math.tan(THREE.MathUtils.degToRad(camera.fov) / 2));
    this.add.uniforms.scale.value = s;
    this.norm.uniforms.scale.value = s;
  }

  tracer(from, to, enemy = false) {
    const t = this.tracers.find((x) => !x.active);
    if (!t) return;
    t.active = true;
    t.start.copy(from);
    t.dir.subVectors(to, from);
    t.len = t.dir.length();
    t.dir.normalize();
    t.t = 0; t.speed = enemy ? 260 : 420; t.seg = enemy ? 3.5 : 5;
    t.mesh.material = enemy ? this.tracerMatE : this.tracerMatP;
    t.mesh.visible = true;
    t.thick = enemy ? 0.035 : 0.022;
  }

  muzzle(pos, scale = 0.6) {
    const f = this.flashes.find((x) => x.t <= 0) || this.flashes[0];
    f.s.position.copy(pos);
    f.s.scale.setScalar(scale * rand(0.8, 1.2));
    f.s.material.rotation = Math.random() * Math.PI;
    f.s.visible = true;
    f.t = 0.05;
  }

  light(pos, color, intensity, dur, distance = 18) {
    const L = this.lights[this.lightIdx++ % this.lights.length];
    L.l.position.copy(pos);
    L.l.color.set(color);
    L.l.distance = distance;
    L.peak = intensity; L.t = dur; L.dur = dur;
    L.l.intensity = intensity;
  }

  decal(point, normal) {
    const m = this.decals[this.decalIdx++ % this.decals.length];
    _v.copy(point).addScaledVector(normal, 0.01);
    m.position.copy(_v);
    m.lookAt(_d.copy(_v).add(normal));
    m.rotateZ(Math.random() * Math.PI * 2);
    m.scale.setScalar(rand(0.7, 1.3));
    m.updateMatrix();
    m.visible = true;
  }

  impact(point, normal, kind = 'world') {
    const n = normal || _d.set(0, 1, 0);
    for (let i = 0; i < 10; i++) {
      _v.set(n.x + rand(-0.7, 0.7), n.y + rand(-0.3, 0.9), n.z + rand(-0.7, 0.7)).multiplyScalar(rand(3, 9));
      this.add.emit(point, _v, _c.setRGB(3, 1.8, 0.6), rand(0.03, 0.06), rand(0.15, 0.4), { gravity: 9.8, drag: 1 });
    }
    if (kind !== 'metal') {
      for (let i = 0; i < 6; i++) {
        _v.set(n.x * rand(0.5, 2) + rand(-0.4, 0.4), n.y * rand(0.5, 2) + rand(0, 0.6), n.z * rand(0.5, 2) + rand(-0.4, 0.4));
        this.norm.emit(point, _v, _c.setRGB(0.55, 0.52, 0.48), rand(0.25, 0.5), rand(0.8, 1.6), { grow: 2.5, alpha: 0.55, drag: 2, gravity: -0.2 });
      }
    }
  }

  blood(point, dir, head = false) {
    const n = head ? 30 : 14;
    for (let i = 0; i < n; i++) {
      _v.copy(dir).multiplyScalar(rand(1, 5)).add(_d.set(rand(-1.5, 1.5), rand(-0.5, 2), rand(-1.5, 1.5)));
      this.norm.emit(point, _v, _c.setRGB(0.35, 0.02, 0.02), rand(0.05, 0.12), rand(0.4, 0.9), { gravity: 9.8, drag: 0.5 });
    }
    for (let i = 0; i < (head ? 6 : 3); i++) {
      _v.copy(dir).multiplyScalar(rand(0.5, 1.5)).add(_d.set(rand(-0.3, 0.3), rand(0, 0.4), rand(-0.3, 0.3)));
      this.norm.emit(point, _v, _c.setRGB(0.45, 0.04, 0.03), rand(0.25, 0.5), rand(0.3, 0.6), { grow: 3, alpha: 0.65, drag: 3 });
    }
  }

  explosion(p) {
    for (let i = 0; i < 45; i++) {
      _v.set(rand(-1, 1), rand(0.2, 1.4), rand(-1, 1)).normalize().multiplyScalar(rand(2, 9));
      this.add.emit(p, _v, _c.setRGB(4, rand(1.4, 2.2), 0.4), rand(0.8, 2.2), rand(0.35, 0.8), { grow: 1.6, drag: 3, gravity: -2 });
    }
    for (let i = 0; i < 60; i++) {
      _v.set(rand(-1, 1), rand(0.2, 1.5), rand(-1, 1)).normalize().multiplyScalar(rand(8, 22));
      this.add.emit(p, _v, _c.setRGB(4, 2.4, 0.8), rand(0.05, 0.1), rand(0.4, 1.2), { gravity: 9.8, drag: 0.6 });
    }
    for (let i = 0; i < 30; i++) {
      _v.set(rand(-1, 1), rand(0.4, 1.4), rand(-1, 1)).normalize().multiplyScalar(rand(1, 4));
      const g = rand(0.08, 0.16);
      this.norm.emit(_d.copy(p).add(_v.clone().multiplyScalar(0.3)), _v, _c.setRGB(g, g, g), rand(1.2, 2.5), rand(2.5, 4.5), { grow: 2.5, alpha: 0.75, drag: 1.2, gravity: -1.2 });
    }
    this.light(p, 0xff8a3a, 120, 0.6, 30);
  }

  bulletTrail(p) {
    _v.set(rand(-0.1, 0.1), rand(-0.1, 0.1), rand(-0.1, 0.1));
    this.norm.emit(p, _v, _c.setRGB(0.8, 0.8, 0.85), rand(0.04, 0.08), rand(0.5, 0.9), { grow: 4, alpha: 0.35, drag: 2 });
  }

  update(dt) {
    this.add.update(dt);
    this.norm.update(dt);
    for (const t of this.tracers) {
      if (!t.active) continue;
      t.t += dt * t.speed;
      const head = Math.min(t.t, t.len), tail = Math.max(0, t.t - t.seg);
      if (tail >= t.len) { t.active = false; t.mesh.visible = false; continue; }
      const m = t.mesh;
      m.position.copy(t.start).addScaledVector(t.dir, tail);
      m.lookAt(_v.copy(m.position).add(t.dir));
      m.scale.set(t.thick, t.thick, Math.max(0.01, head - tail));
    }
    for (const f of this.flashes) {
      if (f.t > 0) { f.t -= dt; if (f.t <= 0) f.s.visible = false; }
    }
    for (const L of this.lights) {
      if (L.t > 0) {
        L.t -= dt;
        L.l.intensity = Math.max(0, L.peak * (L.t / L.dur));
      } else L.l.intensity = 0;
    }
  }

  clear() {
    this.add.clear(); this.norm.clear();
    for (const t of this.tracers) { t.active = false; t.mesh.visible = false; }
    for (const d of this.decals) d.visible = false;
    for (const f of this.flashes) { f.t = 0; f.s.visible = false; }
  }
}
