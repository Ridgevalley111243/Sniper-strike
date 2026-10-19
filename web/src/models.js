// Procedural 3D models: street props, cover objects, vehicles and first-person weapons.
import * as THREE from 'three';
import { RoundedBoxGeometry } from 'three/addons/geometries/RoundedBoxGeometry.js';
import { mergeGeometries } from 'three/addons/utils/BufferGeometryUtils.js';
import { library } from './textures.js';

const G = {};
// Cached geometry shared between levels (flagged so level teardown never disposes it).
export function geo(key, fn) {
  if (!G[key]) { G[key] = fn(); G[key].userData.shared = true; }
  return G[key];
}

export function mesh(g, m, cast = true, recv = true) {
  const o = new THREE.Mesh(g, m);
  o.castShadow = cast; o.receiveShadow = recv;
  return o;
}

// Box whose UVs are scaled to world units so textures tile at a constant size.
export function worldBox(w, h, d, tileW = 4, tileH = tileW) {
  const g = new THREE.BoxGeometry(w, h, d);
  const uv = g.attributes.uv;
  const dims = [[d, h], [d, h], [w, d], [w, d], [w, h], [w, h]];
  for (let f = 0; f < 6; f++) {
    const [a, b] = dims[f];
    const tw = tileW, th = f === 2 || f === 3 ? tileW : tileH; // roof/floor tiles stay square
    for (let i = 0; i < 4; i++) {
      const k = f * 4 + i;
      uv.setXY(k, (uv.getX(k) * a) / tw, (uv.getY(k) * b) / th);
    }
  }
  return g;
}

const M = () => library().mat;

// ---------- cover objects (local +z faces the threat) ----------
export const COVER_HEIGHT = { barrier: 1.2, sandbags: 1.2, crates: 1.25, car: 1.5, dumpster: 1.35, acunit: 1.3 };

export function barrier() {
  const g = geo('barrier', () => {
    const s = new THREE.Shape();
    const pts = [[-0.32, 0], [0.32, 0], [0.32, 0.1], [0.13, 0.32], [0.1, 1.2], [-0.1, 1.2], [-0.13, 0.32], [-0.32, 0.1]];
    s.moveTo(pts[0][0], pts[0][1]);
    for (let i = 1; i < pts.length; i++) s.lineTo(pts[i][0], pts[i][1]);
    const e = new THREE.ExtrudeGeometry(s, { depth: 2.8, bevelEnabled: false });
    e.translate(0, 0, -1.4);
    e.rotateY(Math.PI / 2);
    return e;
  });
  const grp = new THREE.Group();
  grp.add(mesh(g, M().concreteLight));
  return grp;
}

export function sandbags() {
  const g = geo('sandbags', () => {
    const parts = [];
    for (let row = 0; row < 5; row++) {
      const n = row % 2 ? 5 : 6;
      for (let i = 0; i < n; i++) {
        const b = new THREE.SphereGeometry(0.5, 10, 6);
        b.scale(0.56, 0.26, 0.36);
        b.rotateY((Math.random() - 0.5) * 0.25);
        b.translate((i - (n - 1) / 2) * 0.5 + (Math.random() - 0.5) * 0.04, 0.13 + row * 0.215, (Math.random() - 0.5) * 0.06);
        parts.push(b);
      }
    }
    return mergeGeometries(parts);
  });
  const grp = new THREE.Group();
  grp.add(mesh(g, M().sandbag));
  return grp;
}

export function crates() {
  const grp = new THREE.Group();
  const g = geo('crate', () => new THREE.BoxGeometry(1.25, 1.25, 1.25));
  const a = mesh(g, M().crate); a.position.set(-0.66, 0.625, 0); a.rotation.y = 0.05;
  const b = mesh(g, M().crate); b.position.set(0.66, 0.625, 0.05); b.rotation.y = -0.08;
  const sg = geo('crateS', () => new THREE.BoxGeometry(0.8, 0.8, 0.8));
  const c = mesh(sg, M().crate); c.position.set(-0.6, 1.65, -0.1); c.rotation.y = 0.4;
  grp.add(a, b, c);
  return grp;
}

export function dumpster() {
  const grp = new THREE.Group();
  const body = mesh(geo('dumpBody', () => new THREE.BoxGeometry(2.0, 1.25, 1.15)), M().dumpster);
  body.position.y = 0.72;
  const lid = mesh(geo('dumpLid', () => new THREE.BoxGeometry(2.05, 0.08, 1.2)), M().metalDark);
  lid.position.set(0, 1.38, 0.05); lid.rotation.x = -0.06;
  const wg = geo('dumpWheel', () => new THREE.CylinderGeometry(0.08, 0.08, 0.06, 8).rotateZ(Math.PI / 2));
  for (const x of [-0.85, 0.85]) for (const z of [-0.45, 0.45]) {
    const w = mesh(wg, M().tire); w.position.set(x, 0.08, z); grp.add(w);
  }
  grp.add(body, lid);
  return grp;
}

export function acUnit() {
  const grp = new THREE.Group();
  const b = mesh(geo('ac', () => new THREE.BoxGeometry(1.6, 1.3, 1.0)), M().acUnit);
  b.position.y = 0.65;
  const f = mesh(geo('acFan', () => new THREE.CylinderGeometry(0.35, 0.35, 0.04, 16)), M().metalDark);
  f.position.set(0.3, 1.31, 0);
  const grill = mesh(geo('acGrill', () => new THREE.BoxGeometry(0.9, 0.7, 0.02)), M().metalDark);
  grill.position.set(-0.2, 0.65, 0.51);
  grp.add(b, f, grill);
  return grp;
}

export function barrel() {
  const grp = new THREE.Group();
  const body = mesh(geo('barrel', () => new THREE.CylinderGeometry(0.3, 0.3, 0.9, 18)), M().barrel);
  body.position.y = 0.45;
  const rg = geo('barrelRing', () => new THREE.TorusGeometry(0.305, 0.018, 6, 18).rotateX(Math.PI / 2));
  for (const y of [0.15, 0.75]) { const r = mesh(rg, M().metalDark); r.position.y = y; grp.add(r); }
  const lid = mesh(geo('barrelLid', () => new THREE.CylinderGeometry(0.29, 0.29, 0.02, 18)), M().metalDark);
  lid.position.y = 0.905;
  grp.add(body, lid);
  return grp;
}

export function car(paintIdx, suv = false) {
  const m = M();
  const grp = new THREE.Group();
  const paint = m.carPaints[paintIdx % m.carPaints.length];
  const bh = suv ? 1.0 : 0.78;
  const body = mesh(geo('carBody' + suv, () => new RoundedBoxGeometry(4.4, bh, 1.86, 3, 0.16)), paint);
  body.position.y = 0.26 + bh / 2;
  const ch = suv ? 0.72 : 0.62;
  const cabin = mesh(geo('carCabin' + suv, () => new RoundedBoxGeometry(suv ? 3.0 : 2.35, ch, 1.66, 3, 0.18)), m.carGlass);
  cabin.position.set(suv ? -0.25 : -0.15, 0.26 + bh + ch / 2 - 0.04, 0);
  const roof = mesh(geo('carRoof' + suv, () => new RoundedBoxGeometry(suv ? 2.8 : 2.0, 0.09, 1.62, 2, 0.04)), paint);
  roof.position.set(cabin.position.x, cabin.position.y + ch / 2 - 0.02, 0);
  const pillar = geo('carPillar' + suv, () => new THREE.BoxGeometry(0.1, ch * 0.92, 1.64));
  for (const dx of suv ? [-1.4, 0.0, 1.1] : [-1.1, 0.95]) {
    const p = mesh(pillar, paint, false); p.position.set(cabin.position.x + dx * (suv ? 0.95 : 1), cabin.position.y, 0); grp.add(p);
  }
  const wg = geo('wheel', () => new THREE.CylinderGeometry(0.37, 0.37, 0.26, 18).rotateX(Math.PI / 2));
  const hg = geo('hub', () => new THREE.CylinderGeometry(0.22, 0.22, 0.27, 12).rotateX(Math.PI / 2));
  for (const x of [-1.4, 1.4]) for (const z of [-0.84, 0.84]) {
    const w = mesh(wg, m.tire); w.position.set(x, 0.37, z);
    const h = mesh(hg, m.rim, false); h.position.set(x, 0.37, z);
    grp.add(w, h);
  }
  const bg = geo('bumper', () => new THREE.BoxGeometry(0.16, 0.22, 1.82));
  const fb = mesh(bg, m.bumper); fb.position.set(2.2, 0.42, 0);
  const rb = mesh(bg, m.bumper); rb.position.set(-2.2, 0.42, 0);
  const lg = geo('carLight', () => new THREE.BoxGeometry(0.06, 0.12, 0.36));
  for (const z of [-0.62, 0.62]) {
    const hl = mesh(lg, m.headlight, false); hl.position.set(2.21, 0.72 + (suv ? 0.12 : 0), z);
    const tl = mesh(lg, m.taillight, false); tl.position.set(-2.21, 0.72 + (suv ? 0.12 : 0), z);
    grp.add(hl, tl);
  }
  grp.add(body, cabin, roof, fb, rb);
  return grp;
}

export function lampPost(armDir = 1) {
  const m = M();
  const grp = new THREE.Group();
  const pole = mesh(geo('pole', () => new THREE.CylinderGeometry(0.07, 0.12, 7.2, 10)), m.pole);
  pole.position.y = 3.6;
  const base = mesh(geo('poleBase', () => new THREE.CylinderGeometry(0.2, 0.24, 0.5, 10)), m.pole);
  base.position.y = 0.25;
  const arm = mesh(geo('poleArm', () => new THREE.BoxGeometry(1.8, 0.08, 0.08)), m.pole);
  arm.position.set(0.85 * armDir, 7.1, 0);
  const head = mesh(geo('lampHead', () => new THREE.BoxGeometry(0.7, 0.14, 0.32)), m.pole);
  head.position.set(1.7 * armDir, 7.05, 0);
  const glass = mesh(geo('lampGlass', () => new THREE.BoxGeometry(0.6, 0.04, 0.26)), m.lampGlass, false, false);
  glass.position.set(1.7 * armDir, 6.97, 0);
  grp.add(pole, base, arm, head, glass);
  grp.userData.lampPos = new THREE.Vector3(1.7 * armDir, 6.9, 0);
  return grp;
}

export function tree(seed) {
  const m = M();
  const grp = new THREE.Group();
  const trunk = mesh(geo('trunk', () => new THREE.CylinderGeometry(0.11, 0.17, 3.0, 8)), m.bark);
  trunk.position.y = 1.5;
  grp.add(trunk);
  const v = seed % 3;
  const cg = geo('canopy' + v, () => {
    const g = new THREE.IcosahedronGeometry(1.5, 1);
    const p = g.attributes.position;
    for (let i = 0; i < p.count; i++) {
      const s = 0.82 + Math.abs(Math.sin(i * 12.9898 + v * 78.233)) * 0.35;
      p.setXYZ(i, p.getX(i) * s, p.getY(i) * s * 0.9, p.getZ(i) * s);
    }
    g.computeVertexNormals();
    return g;
  });
  const c1 = mesh(cg, m.foliage); c1.position.set(0, 3.7, 0);
  const c2 = mesh(cg, m.foliage2); c2.position.set(0.6, 4.4, 0.3); c2.scale.setScalar(0.7);
  const c3 = mesh(cg, m.foliage); c3.position.set(-0.5, 4.2, -0.4); c3.scale.setScalar(0.65);
  grp.add(c1, c2, c3);
  return grp;
}

export function cone() {
  const grp = new THREE.Group();
  const c = mesh(geo('cone', () => new THREE.ConeGeometry(0.17, 0.62, 12)), M().cone);
  c.position.y = 0.33;
  const b = mesh(geo('coneBase', () => new THREE.BoxGeometry(0.4, 0.04, 0.4)), M().cone);
  b.position.y = 0.02;
  grp.add(c, b);
  return grp;
}

export function waterTower() {
  const m = M();
  const grp = new THREE.Group();
  const tank = mesh(geo('wtTank', () => new THREE.CylinderGeometry(1.6, 1.6, 2.6, 16)), m.crate);
  tank.position.y = 3.3;
  const roof = mesh(geo('wtRoof', () => new THREE.ConeGeometry(1.75, 1.0, 16)), m.metalDark);
  roof.position.y = 5.1;
  const lg = geo('wtLeg', () => new THREE.CylinderGeometry(0.07, 0.07, 2.0, 6));
  for (const [x, z] of [[1.1, 1.1], [-1.1, 1.1], [1.1, -1.1], [-1.1, -1.1]]) {
    const l = mesh(lg, m.metalDark); l.position.set(x, 1.0, z); grp.add(l);
  }
  grp.add(tank, roof);
  return grp;
}

export function trafficLight() {
  const m = M();
  const grp = new THREE.Group();
  const pole = mesh(geo('tlPole', () => new THREE.CylinderGeometry(0.08, 0.1, 4.2, 8)), m.pole);
  pole.position.y = 2.1;
  const box = mesh(geo('tlBox', () => new THREE.BoxGeometry(0.34, 0.95, 0.3)), m.trafficLight);
  box.position.set(0, 4.5, 0);
  const lg = geo('tlLamp', () => new THREE.CircleGeometry(0.09, 12));
  const red = mesh(lg, m.tlRed, false, false); red.position.set(0, 4.78, 0.16);
  const off = mesh(lg, m.metalDark, false, false); off.position.set(0, 4.5, 0.16);
  const green = mesh(lg, m.metalDark, false, false); green.position.set(0, 4.22, 0.16);
  grp.add(pole, box, red, off, green);
  return grp;
}

// ---------- weapons ----------
function part(g, m, x, y, z, rx = 0) {
  const o = mesh(g, m, false, false);
  o.position.set(x, y, z);
  o.rotation.x = rx;
  return o;
}
const cyl = (r1, r2, h, s = 12) => new THREE.CylinderGeometry(r1, r2, h, s).rotateX(Math.PI / 2);
const box = (w, h, d) => new THREE.BoxGeometry(w, h, d);

function arms(grp, gripZ, foreZ, foreY) {
  const m = M();
  const handR = part(box(0.05, 0.075, 0.09), m.glove, 0.012, -0.065, gripZ);
  const handL = part(box(0.06, 0.05, 0.11), m.glove, -0.01, foreY - 0.035, foreZ);
  const armR = part(box(0.075, 0.08, 0.42), m.sleeve, 0.06, -0.14, gripZ + 0.22, 0.35);
  armR.rotation.y = -0.25;
  const armL = part(box(0.075, 0.08, 0.5), m.sleeve, -0.1, foreY - 0.12, foreZ + 0.24, 0.32);
  armL.rotation.y = 0.35;
  grp.add(handR, handL, armR, armL);
}

export function rifleViewModel() {
  const m = M();
  const g = new THREE.Group();
  g.add(
    part(box(0.058, 0.075, 0.3), m.gunMetal, 0, 0, 0),
    part(box(0.04, 0.016, 0.34), m.polymer, 0, 0.046, -0.02),
    part(box(0.062, 0.066, 0.24), m.polymer, 0, -0.002, -0.27),
    part(cyl(0.011, 0.011, 0.2), m.gunMetal, 0, 0.005, -0.48),
    part(cyl(0.017, 0.017, 0.06), m.gunMetal, 0, 0.005, -0.6),
    part(box(0.034, 0.15, 0.07), m.polymer, 0, -0.1, -0.03, 0.22),
    part(box(0.034, 0.09, 0.045), m.polymer, 0, -0.075, 0.1, -0.35),
    part(box(0.046, 0.072, 0.21), m.polymer, 0, -0.012, 0.25),
    part(box(0.05, 0.1, 0.03), m.polymer, 0, -0.02, 0.36),
    part(box(0.036, 0.044, 0.07), m.gunMetal, 0, 0.074, -0.03),
    part(cyl(0.014, 0.014, 0.012), m.lens, 0, 0.078, -0.064),
  );
  const dot = part(new THREE.SphereGeometry(0.0022, 6, 4), m.redDot, 0, 0.078, -0.03);
  g.add(dot);
  arms(g, 0.1, -0.27, -0.002);
  const muzzle = new THREE.Object3D(); muzzle.position.set(0, 0.005, -0.64);
  g.add(muzzle);
  g.userData.muzzle = muzzle;
  return g;
}

export function sniperViewModel() {
  const m = M();
  const g = new THREE.Group();
  g.add(
    part(box(0.056, 0.07, 0.38), m.gunMetal, 0, 0, 0),
    part(box(0.064, 0.07, 0.42), m.tan, 0, -0.012, -0.28),
    part(cyl(0.012, 0.014, 0.6), m.gunMetal, 0, 0.008, -0.72),
    part(cyl(0.02, 0.02, 0.07), m.gunMetal, 0, 0.008, -1.04),
    part(cyl(0.022, 0.022, 0.32), m.gunMetal, 0, 0.082, -0.06),
    part(cyl(0.034, 0.024, 0.09), m.gunMetal, 0, 0.082, -0.26),
    part(cyl(0.029, 0.022, 0.06), m.gunMetal, 0, 0.082, 0.12),
    part(cyl(0.015, 0.015, 0.04).rotateX(Math.PI / 2), m.gunMetal, 0, 0.115, -0.07),
    part(box(0.03, 0.04, 0.02), m.gunMetal, 0, 0.05, -0.16),
    part(box(0.03, 0.04, 0.02), m.gunMetal, 0, 0.05, 0.03),
    part(box(0.03, 0.08, 0.06), m.polymer, 0, -0.07, -0.03),
    part(box(0.034, 0.09, 0.045), m.tan, 0, -0.075, 0.12, -0.35),
    part(box(0.05, 0.11, 0.3), m.tan, 0, -0.035, 0.33),
    part(box(0.04, 0.04, 0.16), m.tan, 0, 0.035, 0.32),
    part(cyl(0.031, 0.031, 0.004), m.lens, 0, 0.082, -0.306),
  );
  const bolt = new THREE.Group();
  bolt.add(part(new THREE.CylinderGeometry(0.007, 0.007, 0.07, 6).rotateZ(Math.PI / 2), m.gunMetal, 0.05, 0.02, 0.08));
  bolt.add(part(new THREE.SphereGeometry(0.014, 8, 6), m.gunMetal, 0.085, 0.02, 0.08));
  g.add(bolt);
  g.userData.bolt = bolt;
  arms(g, 0.12, -0.3, -0.012);
  const muzzle = new THREE.Object3D(); muzzle.position.set(0, 0.008, -1.08);
  g.add(muzzle);
  g.userData.muzzle = muzzle;
  return g;
}

export function enemyRifle(long = false) {
  const m = M();
  const g = new THREE.Group();
  const geom = geo('enemyRifle' + long, () => mergeGeometries([
    new THREE.BoxGeometry(0.06, 0.09, 0.42).translate(0, 0, 0.05),
    new THREE.BoxGeometry(0.04, 0.14, 0.06).translate(0, -0.1, 0.12),
    new THREE.BoxGeometry(0.045, 0.08, 0.22).translate(0, -0.02, -0.25),
    new THREE.CylinderGeometry(0.012, 0.012, long ? 0.6 : 0.3, 8).rotateX(Math.PI / 2).translate(0, 0.01, long ? 0.55 : 0.4),
    ...(long ? [new THREE.CylinderGeometry(0.025, 0.025, 0.28, 8).rotateX(Math.PI / 2).translate(0, 0.08, 0.1)] : []),
  ]));
  g.add(mesh(geom, m.gunMetal));
  const muzzle = new THREE.Object3D();
  muzzle.position.set(0, 0.01, long ? 0.86 : 0.56);
  g.add(muzzle);
  g.userData.muzzle = muzzle;
  return g;
}
