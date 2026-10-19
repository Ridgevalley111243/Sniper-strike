// Procedural city-street battlefield: buildings, props, enemy cover points, spawns.
import * as THREE from 'three';
import { library, FACADE_TILE_W, FACADE_TILE_H } from './textures.js';
import * as P from './models.js';
import { rng, range, pick } from './util.js';

const { mesh, worldBox, geo } = P;
const CROSS_Z0 = -110, CROSS_Z1 = -128; // cross street gap

export class Level {
  constructor(game, mission) {
    this.game = game;
    this.mission = mission;
    this.group = new THREE.Group();
    this.colliders = [];
    this.coverPoints = [];
    this.barrels = [];
    this.spawns = [];
    this.lampPools = [];
    this.occupied = [];
    this.buildings = [];
    this.r = rng(mission.seed ?? mission.id * 7919 + 17);
    this.build();
  }

  add(obj, collide = true) {
    this.group.add(obj);
    if (collide) {
      obj.traverse((o) => { if (o.isMesh) this.colliders.push(o); });
    }
    return obj;
  }

  occupy(x, z, rad) { this.occupied.push([x, z, rad]); }
  free(x, z, rad) {
    for (const [ox, oz, orad] of this.occupied) if ((ox - x) ** 2 + (oz - z) ** 2 < (rad + orad) ** 2) return false;
    return true;
  }

  build() {
    const m = library().mat;
    const r = this.r;
    const roof = this.mission.vantage === 'roof';

    // ground + road markings
    const gg = new THREE.PlaneGeometry(1400, 1400);
    gg.rotateX(-Math.PI / 2);
    const uv = gg.attributes.uv;
    for (let i = 0; i < uv.count; i++) uv.setXY(i, uv.getX(i) * 175, uv.getY(i) * 175);
    this.add(mesh(gg, m.asphalt, false, true));

    const dash = new THREE.InstancedMesh(geo('dash', () => new THREE.PlaneGeometry(0.16, 3).rotateX(-Math.PI / 2)), m.lineYellow, 60);
    const mtx = new THREE.Matrix4();
    let n = 0;
    for (let z = 10; z > -270 && n < 60; z -= 8) {
      if (z < CROSS_Z0 + 2 && z > CROSS_Z1 - 2) continue;
      mtx.makeTranslation(0, 0.01, z); dash.setMatrixAt(n++, mtx);
    }
    dash.count = n; dash.receiveShadow = true;
    this.group.add(dash);
    for (const s of [-1, 1]) {
      for (const [z0, z1] of [[30, CROSS_Z0 - 1], [CROSS_Z1 + 1, -280]]) {
        const len = z0 - z1;
        const l = mesh(new THREE.PlaneGeometry(0.14, len).rotateX(-Math.PI / 2), m.lineWhite, false);
        l.position.set(s * 7.4, 0.01, (z0 + z1) / 2);
        this.group.add(l);
      }
    }
    // crosswalks at the cross street
    const cw = new THREE.InstancedMesh(geo('zebra', () => new THREE.PlaneGeometry(0.6, 3.2).rotateX(-Math.PI / 2)), m.lineWhite, 24);
    n = 0;
    for (const z of [CROSS_Z0 - 2.2, CROSS_Z1 + 2.2]) for (let x = -7; x <= 7; x += 1.3) {
      if (n >= 24) break;
      mtx.makeTranslation(x, 0.012, z); cw.setMatrixAt(n++, mtx);
    }
    cw.count = n; cw.receiveShadow = true;
    this.group.add(cw);

    // sidewalks + curbs
    for (const s of [-1, 1]) {
      for (const [z0, z1] of [[40, CROSS_Z0], [CROSS_Z1, -290]]) {
        const len = z0 - z1;
        const sw = mesh(worldBox(4, 0.16, len, 4), m.sidewalk, false, true);
        sw.position.set(s * 10, 0.08, (z0 + z1) / 2);
        this.add(sw);
        const curb = mesh(worldBox(0.25, 0.18, len, 4), m.curb, false, true);
        curb.position.set(s * 8.1, 0.09, (z0 + z1) / 2);
        this.add(curb);
      }
      // cross-street sidewalks
      for (const z of [CROSS_Z0 - 2, CROSS_Z1 + 2]) {
        const sw = mesh(worldBox(140, 0.16, 4, 4), m.sidewalk, false, true);
        sw.position.set(s * 82, 0.08, z);
        this.add(sw);
      }
    }

    this.buildPlayerSpot(roof);
    this.buildStreetBuildings();
    this.buildSkyline();
    this.buildProps();
    this.buildCover();
    this.buildSpawns();
    if (this.mission.type === 'assassinate') this.buildVipPath();
  }

  buildPlayerSpot(roof) {
    const m = library().mat;
    if (roof) {
      const h = 16;
      const b = mesh(worldBox(26, h, 24, FACADE_TILE_W, FACADE_TILE_H), [m.facades[1], m.facades[1], m.roof, m.roof, m.facades[1], m.facades[1]]);
      b.position.set(0, h / 2, 18);
      this.add(b);
      const par = mesh(worldBox(26, 1.15, 0.35, 2), m.concrete);
      par.position.set(0, h + 0.575, 6.2);
      this.add(par);
      for (const s of [-1, 1]) {
        const sp = mesh(worldBox(0.35, 1.15, 24, 2), m.concrete);
        sp.position.set(s * 12.8, h + 0.575, 18);
        this.add(sp);
      }
      const ac = P.acUnit(); ac.position.set(-4, h, 9.5); ac.rotation.y = 0.3; this.add(ac);
      const wt = P.waterTower(); wt.position.set(6, h, 16); this.add(wt);
      this.playerSpot = { pos: new THREE.Vector3(0, h, 7.4), coverTop: h + 1.15, cover: par };
      this.occupy(0, 15, 14);
    } else {
      const bar = P.barrier(); bar.position.set(0, 0, 2.9); this.add(bar);
      for (const s of [-1, 1]) {
        const sb = P.sandbags(); sb.position.set(s * 2.6, 0, 3.4); sb.rotation.y = -s * 0.5; this.add(sb);
      }
      const c1 = P.cone(); c1.position.set(-4.6, 0, 1.5); this.add(c1);
      const c2 = P.cone(); c2.position.set(4.3, 0, 2.2); this.add(c2);
      const car = P.car(3, true); car.position.set(5.8, 0, 7.5); car.rotation.y = 1.2; this.add(car);
      this.playerSpot = { pos: new THREE.Vector3(0, 0, 4.1), coverTop: 1.2, cover: bar };
      this.occupy(0, 4, 6);
    }
  }

  buildStreetBuildings() {
    const m = library().mat;
    const r = this.r;
    for (const s of [-1, 1]) {
      let z = 34;
      while (z > -275) {
        if (z < CROSS_Z0 + 1 && z > CROSS_Z1 - 1) { z = CROSS_Z1 - 1; continue; }
        let len = range(r, 12, 26);
        if (z > CROSS_Z0 && z - len < CROSS_Z0) len = z - CROSS_Z0;
        if (len < 6) { z -= len; continue; }
        const z0 = z, z1 = z - len;
        const near = z > -20;
        const h = near ? range(r, 14, 24) : r() < 0.35 ? range(r, 10, 18) : range(r, 18, 52);
        const depth = range(r, 14, 22);
        const setback = r() < 0.25 ? range(r, 0.5, 2) : 0;
        const front = 12 + setback;
        const fi = Math.floor(r() * m.facades.length);
        const fm = m.facades[fi];
        const b = mesh(worldBox(depth, h, len - 0.2, FACADE_TILE_W, FACADE_TILE_H), [fm, fm, m.roof, m.roof, fm, fm]);
        b.position.set(s * (front + depth / 2), h / 2, (z0 + z1) / 2);
        this.add(b);
        const info = { side: s, z0, z1, h, front, zc: (z0 + z1) / 2, len };
        this.buildings.push(info);

        // roof trim / parapet along the street edge
        const trim = mesh(worldBox(0.5, 0.9, len - 0.2, 2), m.roofTrim);
        trim.position.set(s * (front + 0.25), h + 0.45, info.zc);
        this.add(trim);
        // cornice
        const cor = mesh(worldBox(0.6, 0.3, len - 0.2, 2), m.roofTrim, true, false);
        cor.position.set(s * (front - 0.1), h - 0.15, info.zc);
        this.add(cor, false);

        // storefront band + awning on lower buildings
        if (r() < 0.6 && len > 9) {
          const sf = mesh(new THREE.BoxGeometry(0.25, 3.2, len - 2), m.storefront, false, true);
          const uvs = sf.geometry.attributes.uv;
          for (let i = 0; i < uvs.count; i++) uvs.setX(i, uvs.getX(i) * (len - 2) / 16);
          sf.position.set(s * (front - 0.1), 1.75, info.zc);
          this.add(sf, false);
          if (r() < 0.6) {
            const aw = mesh(new THREE.PlaneGeometry(len - 3, 1.6), pick(r, m.awning), true, false);
            aw.position.set(s * (front - 0.75), 3.6, info.zc);
            aw.rotation.set(0, -s * Math.PI / 2, 0);
            aw.rotateX(-0.45);
            this.add(aw, false);
          }
        }
        // rooftop clutter
        if (r() < 0.55) {
          const ac = P.acUnit();
          ac.position.set(s * (front + range(r, 3, depth - 3)), h, info.zc + range(r, -len / 3, len / 3));
          this.add(ac);
        }
        if (h < 30 && r() < 0.25) {
          const wt = P.waterTower();
          wt.position.set(s * (front + depth * 0.6), h, info.zc);
          this.add(wt);
        }
        z = z1 - (r() < 0.25 ? range(r, 2.5, 5) : 0);
      }
    }
    // end-of-street landmark block
    const fm = m.facades[2];
    const end = mesh(worldBox(90, 60, 24, FACADE_TILE_W, FACADE_TILE_H), [fm, fm, m.roof, m.roof, fm, fm]);
    end.position.set(0, 30, -295);
    this.add(end);
    // buildings closing the cross street
    for (const s of [-1, 1]) {
      const f2 = m.facades[4];
      const cb = mesh(worldBox(24, 46, 40, FACADE_TILE_W, FACADE_TILE_H), [f2, f2, m.roof, m.roof, f2, f2]);
      cb.position.set(s * 120, 23, (CROSS_Z0 + CROSS_Z1) / 2);
      this.add(cb);
    }
  }

  buildSkyline() {
    const m = library().mat;
    const r = this.r;
    for (let i = 0; i < 48; i++) {
      const a = range(r, -Math.PI * 0.85, Math.PI * 0.85);
      const d = range(r, 330, 620);
      const x = Math.sin(a) * d, z = -Math.cos(a) * d - 60;
      const w = range(r, 25, 60), h = range(r, 40, 190);
      const mat = pick(r, m.skylines);
      const b = new THREE.Mesh(worldBox(w, h, w, FACADE_TILE_W, FACADE_TILE_H), mat);
      b.position.set(x, h / 2, z);
      b.rotation.y = r() * Math.PI;
      this.group.add(b);
    }
  }

  buildProps() {
    const r = this.r;
    const { tex } = library();
    const night = this.game.env.time.night > 0.3;
    const poolMat = new THREE.MeshBasicMaterial({ map: tex.pool, transparent: true, depthWrite: false, blending: THREE.AdditiveBlending, opacity: night ? 1 : 0 });
    const glowMat = new THREE.SpriteMaterial({ map: tex.glow, blending: THREE.AdditiveBlending, depthWrite: false, color: new THREE.Color(2, 1.7, 1.2), opacity: night ? 0.9 : 0 });
    this.poolMat = poolMat;
    // street lamps
    for (const s of [-1, 1]) {
      for (let z = 14 + (s > 0 ? 12 : 0); z > -260; z -= 24) {
        if (z < CROSS_Z0 + 2 && z > CROSS_Z1 - 2) continue;
        const lp = P.lampPost(-s);
        lp.position.set(s * 8.7, 0, z);
        this.add(lp);
        this.occupy(s * 8.7, z, 0.6);
        if (night) {
          const pool = new THREE.Mesh(geo('pool', () => new THREE.PlaneGeometry(11, 11).rotateX(-Math.PI / 2)), poolMat);
          pool.position.set(s * 7.0, 0.03, z);
          pool.renderOrder = 2;
          this.group.add(pool);
          const glow = new THREE.Sprite(glowMat);
          glow.position.set(s * 7.0, 6.9, z);
          glow.scale.setScalar(2.2);
          this.group.add(glow);
        }
      }
    }
    // trees
    for (const s of [-1, 1]) {
      for (let z = 2 - (s > 0 ? 9 : 0); z > -250; z -= range(r, 16, 30)) {
        if (z < CROSS_Z0 + 3 && z > CROSS_Z1 - 3) continue;
        if (!this.free(s * 10.6, z, 1.5)) continue;
        const t = P.tree(Math.floor(r() * 100));
        t.position.set(s * 10.6, 0.16, z);
        t.rotation.y = r() * 6;
        t.scale.setScalar(range(r, 0.85, 1.15));
        this.group.add(t);
        this.colliders.push(t.children[0]);
        this.occupy(s * 10.6, z, 1.2);
      }
    }
    // parked cars along the curbs
    for (const s of [-1, 1]) {
      for (let z = -8 - r() * 10; z > -250; z -= range(r, 9, 26)) {
        if (z < CROSS_Z0 + 4 && z > CROSS_Z1 - 4) continue;
        if (!this.free(s * 6.6, z, 2.4)) continue;
        const c = P.car(Math.floor(r() * 8), r() < 0.3);
        c.position.set(s * 6.6, 0, z);
        c.rotation.y = Math.PI / 2 + (s > 0 ? Math.PI : 0) + range(r, -0.05, 0.05);
        this.add(c);
        this.occupy(s * 6.6, z, 2.4);
      }
    }
    // traffic lights at the cross street
    for (const [x, z, ry] of [[-8.6, CROSS_Z0 - 0.5, 0], [8.6, CROSS_Z1 + 0.5, Math.PI]]) {
      const tl = P.trafficLight(); tl.position.set(x, 0.16, z); tl.rotation.y = ry; this.add(tl);
    }
    // a burnt-out car in the middle of the road for atmosphere
    const wreck = P.car(4, false);
    wreck.position.set(range(r, -3, 3), 0, range(r, -150, -180));
    wreck.rotation.y = range(r, -0.6, 0.6);
    if (this.free(wreck.position.x, wreck.position.z, 3)) {
      this.add(wreck);
      this.occupy(wreck.position.x, wreck.position.z, 2.6);
    }
  }

  // Enemy cover positions in a band of distances in front of the player.
  buildCover() {
    const r = this.r;
    const mis = this.mission;
    const [minR, maxR] = mis.range;
    const Pp = this.playerSpot.pos;
    const want = mis.coverCount ?? 16;
    let tries = 0;
    while (this.coverPoints.filter((c) => !c.roof).length < want && tries++ < 800) {
      const d = range(r, minR, maxR);
      const a = range(r, -0.4, 0.4);
      const x = Pp.x + Math.sin(a) * d, z = Pp.z - Math.cos(a) * d;
      if (Math.abs(x) > 11 || z > -10 || z < -265) continue;
      if (z < CROSS_Z0 + 2 && z > CROSS_Z1 - 2 && Math.abs(x) > 8) continue;
      if (!this.free(x, z, 2.2)) continue;
      const onRoad = Math.abs(x) < 7;
      const type = pick(r, onRoad ? ['barrier', 'sandbags', 'crates', 'car', 'barrier', 'sandbags', 'crates'] : ['crates', 'dumpster', 'sandbags', 'barrier']);
      this.addCover(type, x, 0, z);
    }
    if (mis.roofEnemies) {
      for (const b of this.buildings) {
        if (b.h > 32 || b.len < 10) continue;
        const dz = Pp.z - b.zc;
        if (dz < minR || dz > maxR + 20) continue;
        const k = r() < 0.5 ? 1 : 2;
        for (let i = 0; i < k; i++) {
          const z = b.zc + (k === 1 ? 0 : (i - 0.5) * b.len * 0.45);
          const x = b.side * (b.front + 1.6);
          this.addCover('acunit', x, b.h, z, true);
        }
      }
    }
  }

  addCover(type, x, y, z, roof = false) {
    const r = this.r;
    const Pp = this.playerSpot.pos;
    const yaw = Math.atan2(Pp.x - x, Pp.z - z);
    const builders = { barrier: P.barrier, sandbags: P.sandbags, crates: P.crates, dumpster: P.dumpster, acunit: P.acUnit, car: () => P.car(Math.floor(r() * 8), r() < 0.3) };
    const obj = builders[type]();
    obj.position.set(x, y, z);
    obj.rotation.y = yaw + (type === 'car' ? range(r, -0.15, 0.15) : 0);
    this.add(obj);
    this.occupy(x, z, type === 'car' ? 2.4 : 1.6);
    const back = { car: 1.45, crates: 1.25, dumpster: 1.2, acunit: 1.1, barrier: 0.9, sandbags: 0.85 }[type];
    const pos = new THREE.Vector3(x - Math.sin(yaw) * back, y, z - Math.cos(yaw) * back);
    const cp = { pos, yaw, coverTop: y + P.COVER_HEIGHT[type], type, roof, taken: null, obj };
    this.coverPoints.push(cp);

    // explosive barrels next to some ground cover
    if (!roof && r() < (this.mission.barrels ?? 0.3)) {
      const side = r() < 0.5 ? -1 : 1;
      const bx = x + Math.cos(yaw) * side * range(r, 1.9, 2.6), bz = z - Math.sin(yaw) * side * range(r, 1.9, 2.6);
      if (Math.abs(bx) < 11.5 && this.free(bx, bz, 0.5)) {
        const b = P.barrel();
        b.position.set(bx, 0, bz);
        this.add(b);
        this.occupy(bx, bz, 0.5);
        const bb = { obj: b, hp: 40, alive: true, pos: new THREE.Vector3(bx, 0.5, bz) };
        b.traverse((o) => { if (o.isMesh) o.userData.barrel = bb; });
        this.barrels.push(bb);
      }
    }
    return cp;
  }

  buildSpawns() {
    const m = library().mat;
    const [minR, maxR] = this.mission.range;
    const Pz = this.playerSpot.pos.z;
    for (const b of this.buildings) {
      const dz = Pz - b.zc;
      if (dz < minR - 10 || dz > maxR + 30 || b.len < 8) continue;
      const door = mesh(geo('door', () => new THREE.BoxGeometry(0.3, 2.6, 1.8)), m.door, false, true);
      door.position.set(b.side * (b.front - 0.05), 1.3, b.zc + b.len * 0.3);
      this.add(door, false);
      this.spawns.push({ pos: new THREE.Vector3(b.side * (b.front - 0.8), 0, b.zc + b.len * 0.3), door: true });
    }
    for (let i = 0; i < 4; i++) {
      this.spawns.push({ pos: new THREE.Vector3(-6 + i * 4, 0, Math.max(-262, Pz - maxR - 35)) });
    }
    for (const s of [-1, 1]) this.spawns.push({ pos: new THREE.Vector3(s * 30, 0, (CROSS_Z0 + CROSS_Z1) / 2) });
  }

  buildVipPath() {
    const [minR, maxR] = this.mission.range;
    const s = this.mission.vipSide ?? -1;
    const Pz = this.playerSpot.pos.z;
    const zStart = Pz - maxR - 12, zEnd = Pz - minR - 6;
    this.vipPath = [
      new THREE.Vector3(s * 10.2, 0.16, zStart),
      new THREE.Vector3(s * 10.2, 0.16, zEnd),
      new THREE.Vector3(s * 13.5, 0.16, zEnd),
    ];
    const m = library().mat;
    const door = mesh(geo('door', () => new THREE.BoxGeometry(0.3, 2.6, 1.8)), m.door, false, true);
    door.position.set(s * 12.05, 1.3, zEnd);
    this.add(door, false);
  }

  pickCover(preferRoof = false, near = null) {
    const free = this.coverPoints.filter((c) => !c.taken && (preferRoof ? c.roof : !c.roof));
    const list = free.length ? free : this.coverPoints.filter((c) => !c.taken);
    if (!list.length) return null;
    if (near) {
      list.sort((a, b) => a.pos.distanceToSquared(near) - b.pos.distanceToSquared(near));
      return list[Math.floor(Math.random() * Math.min(3, list.length))];
    }
    return list[Math.floor(Math.random() * list.length)];
  }

  nearestSpawn(p) {
    let best = null, bd = Infinity;
    for (const s of this.spawns) {
      const d = s.pos.distanceToSquared(p) * (0.7 + Math.random() * 0.6);
      if (d < bd) { bd = d; best = s; }
    }
    return best;
  }

  dispose() {
    this.group.traverse((o) => {
      if (o.geometry && !o.geometry.userData.shared) o.geometry.dispose();
    });
    this.poolMat?.dispose();
    this.group.removeFromParent();
  }
}
