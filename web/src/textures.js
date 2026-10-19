// Procedural textures + shared material library. Everything is drawn on canvases at
// startup so the game ships without any image assets.
import * as THREE from 'three';
import { rng, range } from './util.js';

let aniso = 4;
export function setAnisotropy(a) { aniso = a; }

function makeCanvas(w, h) {
  const c = document.createElement('canvas');
  c.width = w; c.height = h;
  return [c, c.getContext('2d', { willReadFrequently: true })];
}

function toTex(c, srgb = true) {
  const t = new THREE.CanvasTexture(c);
  t.wrapS = t.wrapT = THREE.RepeatWrapping;
  t.anisotropy = aniso;
  if (srgb) t.colorSpace = THREE.SRGBColorSpace;
  return t;
}

function noise(ctx, w, h, amt, r) {
  const img = ctx.getImageData(0, 0, w, h);
  const d = img.data;
  for (let i = 0; i < d.length; i += 4) {
    const n = (r() - 0.5) * amt;
    d[i] += n; d[i + 1] += n; d[i + 2] += n;
  }
  ctx.putImageData(img, 0, 0);
}

// Soft radial blotches, drawn wrapped so the texture tiles seamlessly.
function blotches(ctx, w, h, n, rgb, aMax, r0, r1, r) {
  for (let i = 0; i < n; i++) {
    const x = r() * w, y = r() * h, rad = r0 + r() * (r1 - r0), a = aMax * r();
    for (const ox of [-w, 0, w]) for (const oy of [-h, 0, h]) {
      const X = x + ox, Y = y + oy;
      if (X + rad < 0 || X - rad > w || Y + rad < 0 || Y - rad > h) continue;
      const g = ctx.createRadialGradient(X, Y, 0, X, Y, rad);
      g.addColorStop(0, `rgba(${rgb},${a})`);
      g.addColorStop(1, `rgba(${rgb},0)`);
      ctx.fillStyle = g;
      ctx.fillRect(X - rad, Y - rad, rad * 2, rad * 2);
    }
  }
}

function specks(ctx, w, h, n, colors, r, size = 1.5) {
  for (let i = 0; i < n; i++) {
    ctx.fillStyle = colors[(r() * colors.length) | 0];
    ctx.fillRect(r() * w, r() * h, 1 + r() * size, 1 + r() * size);
  }
}

function asphalt() {
  const S = 512, [c, x] = makeCanvas(S, S), r = rng(11);
  x.fillStyle = '#47484b'; x.fillRect(0, 0, S, S);
  blotches(x, S, S, 70, '18,18,20', 0.35, 20, 100, r);
  blotches(x, S, S, 40, '130,126,118', 0.1, 10, 60, r);
  noise(x, S, S, 40, r);
  specks(x, S, S, 3000, ['rgba(170,166,158,0.45)', 'rgba(12,12,12,0.5)'], r);
  x.strokeStyle = 'rgba(14,14,14,0.55)';
  x.lineWidth = 1.3;
  for (let i = 0; i < 7; i++) {
    let px = 40 + r() * (S - 80), py = 40 + r() * (S - 80);
    x.beginPath(); x.moveTo(px, py);
    for (let k = 0; k < 10; k++) { px += (r() - 0.5) * 28; py += (r() - 0.5) * 28; x.lineTo(px, py); }
    x.stroke();
  }
  return toTex(c);
}

function concrete(base = '#8f8b84', seed = 21, seams = true) {
  const S = 512, [c, x] = makeCanvas(S, S), r = rng(seed);
  x.fillStyle = base; x.fillRect(0, 0, S, S);
  blotches(x, S, S, 50, '60,56,50', 0.22, 15, 90, r);
  blotches(x, S, S, 30, '200,196,188', 0.12, 15, 70, r);
  noise(x, S, S, 24, r);
  specks(x, S, S, 1200, ['rgba(60,58,54,0.4)', 'rgba(210,206,198,0.35)'], r, 1);
  if (seams) {
    x.fillStyle = 'rgba(30,28,25,0.35)';
    x.fillRect(0, 0, S, 2); x.fillRect(0, 0, 2, S);
    x.fillRect(0, S / 2, S, 1);
  }
  // rain streaks
  for (let i = 0; i < 40; i++) {
    x.fillStyle = `rgba(40,38,34,${0.05 + r() * 0.08})`;
    x.fillRect(r() * S, r() * S, 1 + r() * 2, 20 + r() * 80);
  }
  return toTex(c);
}

function sidewalk() {
  const S = 512, [c, x] = makeCanvas(S, S), r = rng(31);
  x.fillStyle = '#9b968d'; x.fillRect(0, 0, S, S);
  const T = 128;
  for (let i = 0; i < 4; i++) for (let j = 0; j < 4; j++) {
    const v = (r() - 0.5) * 18;
    x.fillStyle = `rgb(${155 + v},${150 + v},${141 + v})`;
    x.fillRect(i * T + 2, j * T + 2, T - 4, T - 4);
  }
  blotches(x, S, S, 50, '60,58,52', 0.25, 10, 60, r);
  noise(x, S, S, 22, r);
  x.fillStyle = 'rgba(40,38,34,0.6)';
  for (let i = 0; i <= 4; i++) { x.fillRect(i * T - 1, 0, 2, S); x.fillRect(0, i * T - 1, S, 2); }
  return toTex(c);
}

function roofGravel() {
  const S = 256, [c, x] = makeCanvas(S, S), r = rng(41);
  x.fillStyle = '#5d5b57'; x.fillRect(0, 0, S, S);
  noise(x, S, S, 50, r);
  specks(x, S, S, 2500, ['rgba(120,118,112,0.6)', 'rgba(30,30,30,0.6)'], r, 2);
  blotches(x, S, S, 20, '20,20,20', 0.3, 10, 50, r);
  return toTex(c);
}

export const FACADE_STYLES = [
  { name: 'brick', wall: '#7b4130', frame: '#d8d0c2', glassTop: '#8799ab', glassBot: '#1b232d', win: [30, 26, 68, 76], ledge: 'rgba(60,30,20,0.9)', brick: true },
  { name: 'stone', wall: '#b1a387', frame: '#4b4540', glassTop: '#7c8fa3', glassBot: '#182029', win: [22, 22, 84, 82], ledge: 'rgba(120,110,92,1)', panels: true },
  { name: 'glass', wall: '#2c3742', frame: '#8f9aa4', glassTop: '#9fb6cc', glassBot: '#22303e', win: [5, 5, 118, 118], rough: 0.28, metal: 0.45 },
  { name: 'stucco', wall: '#d6cab4', frame: '#5d5144', glassTop: '#7a8ba0', glassBot: '#1a2028', win: [36, 30, 56, 72], shutters: '#3f5a46' },
  { name: 'modern', wall: '#5e6366', frame: '#1d2023', glassTop: '#8aa0b5', glassBot: '#1c2631', win: [8, 40, 112, 58], panels: true, rough: 0.6, metal: 0.15 },
  { name: 'redbrick', wall: '#93533c', frame: '#2d2a28', glassTop: '#90a2b4', glassBot: '#1a1f27', win: [26, 24, 76, 80], brick: true, ledge: 'rgba(200,190,170,0.9)' },
];

// One facade tile = 4 window bays (16 m) x 4 floors (14 m).
export const FACADE_TILE_W = 16, FACADE_TILE_H = 14;

function facade(style, seed) {
  const S = 512, [c, x] = makeCanvas(S, S), [ce, xe] = makeCanvas(S, S), r = rng(seed);
  x.fillStyle = style.wall; x.fillRect(0, 0, S, S);
  blotches(x, S, S, 30, '0,0,0', 0.15, 20, 80, r);
  if (style.brick) {
    x.fillStyle = 'rgba(0,0,0,0.16)';
    for (let y = 0; y < S; y += 4) {
      x.fillRect(0, y, S, 1);
      const off = (y / 4) % 2 ? 0 : 5;
      for (let xx = off; xx < S; xx += 10) x.fillRect(xx, y, 1, 4);
    }
    blotches(x, S, S, 40, '150,90,70', 0.15, 4, 18, r);
  }
  if (style.panels) {
    x.fillStyle = 'rgba(0,0,0,0.2)';
    for (let i = 0; i < S; i += 64) { x.fillRect(i, 0, 1, S); x.fillRect(0, i, S, 1); }
  }
  noise(x, S, S, 22, r);
  xe.fillStyle = '#000'; xe.fillRect(0, 0, S, S);

  const [wx, wy, ww, wh] = style.win;
  for (let f = 0; f < 4; f++) for (let b = 0; b < 4; b++) {
    const X = b * 128 + wx, Y = f * 128 + wy;
    x.fillStyle = style.frame; x.fillRect(X - 4, Y - 4, ww + 8, wh + 8);
    const lit = r() < 0.33;
    if (lit) {
      const warm = r() < 0.72;
      const col = warm ? [255, (185 + r() * 50) | 0, (100 + r() * 60) | 0] : [175, 210, 255];
      const k = 0.55 + r() * 0.45;
      for (const ctx of [x, xe]) {
        const g = ctx.createLinearGradient(X, Y, X, Y + wh);
        g.addColorStop(0, `rgb(${col.map((v) => (v * k) | 0)})`);
        g.addColorStop(1, `rgb(${col.map((v) => (v * k * 0.55) | 0)})`);
        ctx.fillStyle = g; ctx.fillRect(X, Y, ww, wh);
      }
    } else {
      const g = x.createLinearGradient(X, Y, X + ww * 0.3, Y + wh);
      g.addColorStop(0, style.glassTop); g.addColorStop(1, style.glassBot);
      x.fillStyle = g; x.fillRect(X, Y, ww, wh);
      x.fillStyle = 'rgba(255,255,255,0.09)';
      x.beginPath();
      x.moveTo(X + ww * 0.25, Y); x.lineTo(X + ww * 0.5, Y);
      x.lineTo(X + ww * 0.15, Y + wh); x.lineTo(X, Y + wh); x.lineTo(X, Y + wh * 0.75);
      x.closePath(); x.fill();
      if (r() < 0.3) { x.fillStyle = 'rgba(205,195,175,0.55)'; x.fillRect(X, Y, ww, wh * range(r, 0.15, 0.6)); }
    }
    x.fillStyle = style.frame; xe.fillStyle = '#000';
    x.fillRect(X + ww / 2 - 1.5, Y, 3, wh); xe.fillRect(X + ww / 2 - 1.5, Y, 3, wh);
    if (wh > 60) { x.fillRect(X, Y + wh * 0.32, ww, 3); xe.fillRect(X, Y + wh * 0.32, ww, 3); }
    x.fillStyle = 'rgba(0,0,0,0.35)'; x.fillRect(X - 6, Y + wh + 4, ww + 12, 5);
    if (style.shutters) {
      x.fillStyle = style.shutters;
      x.fillRect(X - 18, Y - 2, 12, wh + 4); x.fillRect(X + ww + 6, Y - 2, 12, wh + 4);
    }
  }
  if (style.ledge) {
    x.fillStyle = style.ledge;
    for (let f = 0; f < 4; f++) x.fillRect(0, f * 128 + 122, S, 6);
  }
  return { map: toTex(c), emissive: toTex(ce) };
}

function storefront() {
  const W = 512, H = 128, [c, x] = makeCanvas(W, H), [ce, xe] = makeCanvas(W, H), r = rng(77);
  x.fillStyle = '#1d1f22'; x.fillRect(0, 0, W, H);
  xe.fillStyle = '#000'; xe.fillRect(0, 0, W, H);
  const signs = ['#c0392b', '#2471a3', '#1e8449', '#b9770e', '#7d3c98'];
  for (let i = 0; i < 4; i++) {
    const X = i * 128;
    x.fillStyle = signs[(r() * signs.length) | 0]; x.fillRect(X + 4, 4, 120, 22);
    xe.fillStyle = x.fillStyle; xe.globalAlpha = 0.6; xe.fillRect(X + 4, 4, 120, 22); xe.globalAlpha = 1;
    x.fillStyle = 'rgba(255,255,255,0.85)';
    for (let k = 0; k < 6; k++) x.fillRect(X + 14 + k * 17, 10, 11, 10);
    const g = x.createLinearGradient(X, 30, X, H);
    g.addColorStop(0, '#5d6d7e'); g.addColorStop(1, '#17202a');
    x.fillStyle = g; x.fillRect(X + 8, 32, 112, H - 36);
    const ge = xe.createLinearGradient(X, 30, X, H);
    ge.addColorStop(0, 'rgb(255,214,150)'); ge.addColorStop(1, 'rgb(120,80,40)');
    xe.fillStyle = ge; xe.fillRect(X + 8, 32, 112, H - 36);
    x.fillStyle = '#111'; x.fillRect(X + 62, 32, 3, H - 36); xe.fillStyle = '#000'; xe.fillRect(X + 62, 32, 3, H - 36);
  }
  noise(x, W, H, 14, r);
  const t = { map: toTex(c), emissive: toTex(ce) };
  return t;
}

function wood() {
  const S = 256, [c, x] = makeCanvas(S, S), r = rng(51);
  x.fillStyle = '#8a6a43'; x.fillRect(0, 0, S, S);
  for (let i = 0; i < 6; i++) {
    const y = i * (S / 6), v = (r() - 0.5) * 30;
    x.fillStyle = `rgb(${138 + v},${104 + v},${66 + v})`; x.fillRect(0, y + 2, S, S / 6 - 4);
    x.fillStyle = 'rgba(40,25,10,0.7)'; x.fillRect(0, y, S, 2);
    for (let k = 0; k < 30; k++) {
      x.fillStyle = `rgba(70,45,20,${0.1 + r() * 0.2})`;
      x.fillRect(r() * S, y + 3 + r() * (S / 6 - 6), 20 + r() * 80, 1);
    }
  }
  x.strokeStyle = 'rgba(50,32,14,0.9)'; x.lineWidth = 10;
  x.strokeRect(5, 5, S - 10, S - 10);
  x.beginPath(); x.moveTo(10, 10); x.lineTo(S - 10, S - 10); x.stroke();
  noise(x, S, S, 18, r);
  return toTex(c);
}

function fabric() {
  const S = 128, [c, x] = makeCanvas(S, S), r = rng(61);
  x.fillStyle = '#a89a76'; x.fillRect(0, 0, S, S);
  x.fillStyle = 'rgba(0,0,0,0.08)';
  for (let i = 0; i < S; i += 2) { x.fillRect(i, 0, 1, S); x.fillRect(0, i, S, 1); }
  blotches(x, S, S, 20, '70,60,40', 0.3, 5, 30, r);
  noise(x, S, S, 30, r);
  return toTex(c);
}

function barrelTex() {
  const W = 256, H = 128, [c, x] = makeCanvas(W, H), r = rng(71);
  x.fillStyle = '#9e1b16'; x.fillRect(0, 0, W, H);
  x.fillStyle = '#e8b923'; x.fillRect(0, 48, W, 32);
  x.fillStyle = '#111';
  for (let i = 0; i < W; i += 64) {
    x.beginPath(); x.moveTo(i + 32, 52); x.lineTo(i + 44, 76); x.lineTo(i + 20, 76); x.closePath(); x.fill();
  }
  x.fillStyle = 'rgba(0,0,0,0.35)'; x.fillRect(0, 18, W, 4); x.fillRect(0, 106, W, 4);
  blotches(x, W, H, 30, '40,20,10', 0.4, 4, 20, r);
  specks(x, W, H, 400, ['rgba(180,180,180,0.5)'], r, 2);
  noise(x, W, H, 20, r);
  return toTex(c);
}

function radial(size, stops) {
  const [c, x] = makeCanvas(size, size);
  const g = x.createRadialGradient(size / 2, size / 2, 0, size / 2, size / 2, size / 2);
  for (const [o, col] of stops) g.addColorStop(o, col);
  x.fillStyle = g; x.fillRect(0, 0, size, size);
  const t = new THREE.CanvasTexture(c);
  t.colorSpace = THREE.SRGBColorSpace;
  return t;
}

function flashTex() {
  const S = 128, [c, x] = makeCanvas(S, S);
  x.translate(S / 2, S / 2);
  const g = x.createRadialGradient(0, 0, 0, 0, 0, S / 2);
  g.addColorStop(0, 'rgba(255,255,240,1)'); g.addColorStop(0.2, 'rgba(255,220,140,0.9)');
  g.addColorStop(0.5, 'rgba(255,140,40,0.35)'); g.addColorStop(1, 'rgba(255,90,0,0)');
  x.fillStyle = g;
  for (let i = 0; i < 6; i++) {
    x.rotate(Math.PI / 3);
    x.beginPath(); x.moveTo(0, -5); x.lineTo(S / 2, 0); x.lineTo(0, 5); x.closePath(); x.fill();
  }
  x.beginPath(); x.arc(0, 0, S / 5, 0, Math.PI * 2); x.fill();
  const t = new THREE.CanvasTexture(c); t.colorSpace = THREE.SRGBColorSpace; return t;
}

function decalTex() {
  const S = 64, [c, x] = makeCanvas(S, S);
  const g = x.createRadialGradient(32, 32, 0, 32, 32, 32);
  g.addColorStop(0, 'rgba(5,5,5,1)'); g.addColorStop(0.18, 'rgba(15,12,10,1)');
  g.addColorStop(0.3, 'rgba(40,36,30,0.8)'); g.addColorStop(0.6, 'rgba(60,55,48,0.25)'); g.addColorStop(1, 'rgba(0,0,0,0)');
  x.fillStyle = g; x.fillRect(0, 0, S, S);
  x.strokeStyle = 'rgba(20,18,15,0.7)'; x.lineWidth = 1;
  for (let i = 0; i < 7; i++) {
    const a = (i / 7) * Math.PI * 2 + Math.random();
    x.beginPath(); x.moveTo(32, 32); x.lineTo(32 + Math.cos(a) * (12 + Math.random() * 14), 32 + Math.sin(a) * (12 + Math.random() * 14)); x.stroke();
  }
  const t = new THREE.CanvasTexture(c); t.colorSpace = THREE.SRGBColorSpace; return t;
}

function markerTex() {
  const S = 128, [c, x] = makeCanvas(S, S);
  x.fillStyle = '#ff3b30'; x.strokeStyle = '#fff'; x.lineWidth = 6;
  x.beginPath(); x.moveTo(24, 30); x.lineTo(104, 30); x.lineTo(64, 100); x.closePath();
  x.stroke(); x.fill();
  const t = new THREE.CanvasTexture(c); t.colorSpace = THREE.SRGBColorSpace; return t;
}

let LIB = null;
export function library() {
  if (LIB) return LIB;
  const std = (o) => new THREE.MeshStandardMaterial(o);
  const asphaltTex = asphalt();
  const concreteTex = concrete();
  const conc2 = concrete('#a39d92', 22);
  const t = {
    asphalt: asphaltTex, concrete: concreteTex, sidewalk: sidewalk(), gravel: roofGravel(),
    wood: wood(), fabric: fabric(), barrel: barrelTex(),
    soft: radial(64, [[0, 'rgba(255,255,255,1)'], [0.4, 'rgba(255,255,255,0.5)'], [1, 'rgba(255,255,255,0)']]),
    smoke: radial(64, [[0, 'rgba(255,255,255,0.7)'], [0.5, 'rgba(255,255,255,0.3)'], [1, 'rgba(255,255,255,0)']]),
    pool: radial(128, [[0, 'rgba(255,200,130,0.55)'], [0.5, 'rgba(255,170,90,0.18)'], [1, 'rgba(255,150,60,0)']]),
    glow: radial(64, [[0, 'rgba(255,240,210,1)'], [0.25, 'rgba(255,200,130,0.6)'], [1, 'rgba(255,160,60,0)']]),
    flash: flashTex(), decal: decalTex(), marker: markerTex(),
  };
  const m = {
    asphalt: std({ map: t.asphalt, roughness: 0.93, color: 0xffffff }),
    concrete: std({ map: t.concrete, roughness: 0.9 }),
    concreteLight: std({ map: conc2, roughness: 0.88 }),
    sidewalk: std({ map: t.sidewalk, roughness: 0.9 }),
    curb: std({ map: conc2, roughness: 0.85, color: 0xd8d4cc }),
    roof: std({ map: t.gravel, roughness: 0.97 }),
    roofTrim: std({ color: 0x6d6a65, roughness: 0.8 }),
    lineWhite: std({ color: 0xe8e6df, roughness: 0.7 }),
    lineYellow: std({ color: 0xe0b52a, roughness: 0.7 }),
    crate: std({ map: t.wood, roughness: 0.85 }),
    sandbag: std({ map: t.fabric, roughness: 1 }),
    barrel: std({ map: t.barrel, roughness: 0.55, metalness: 0.4 }),
    metal: std({ color: 0x8c9196, roughness: 0.45, metalness: 0.8 }),
    metalDark: std({ color: 0x2f3236, roughness: 0.5, metalness: 0.7 }),
    dumpster: std({ color: 0x2e5b3a, roughness: 0.6, metalness: 0.5 }),
    acUnit: std({ color: 0xb9bcbf, roughness: 0.55, metalness: 0.6 }),
    pole: std({ color: 0x3a3d40, roughness: 0.5, metalness: 0.8 }),
    lampGlass: std({ color: 0xfff1d6, emissive: 0xffd9a0, emissiveIntensity: 0, roughness: 0.3 }),
    bark: std({ color: 0x4a3626, roughness: 1 }),
    foliage: std({ color: 0x3f6b2a, roughness: 0.9, flatShading: true }),
    foliage2: std({ color: 0x55803a, roughness: 0.9, flatShading: true }),
    door: std({ color: 0x2a2420, roughness: 0.7 }),
    awning: [0x7b1e1e, 0x1e3f7b, 0x2d5a2d, 0x6b5a1e].map((c) => std({ color: c, roughness: 0.9, side: THREE.DoubleSide })),
    tire: std({ color: 0x151515, roughness: 0.95 }),
    rim: std({ color: 0xa9adb1, roughness: 0.3, metalness: 0.9 }),
    carGlass: std({ color: 0x0b1118, roughness: 0.08, metalness: 0.9 }),
    headlight: std({ color: 0xffffff, emissive: 0xfff2d0, emissiveIntensity: 0.5 }),
    taillight: std({ color: 0x550000, emissive: 0xff1a00, emissiveIntensity: 0.4 }),
    bumper: std({ color: 0x1f2124, roughness: 0.6 }),
    carPaints: [0xb3202a, 0x1f4e8c, 0xd9d9d6, 0x111316, 0x6f7377, 0xc9a227, 0x2d5e3e, 0x7a1f4f].map(
      (c) => std({ color: c, roughness: 0.28, metalness: 0.6 })),
    cone: std({ color: 0xff5a1f, roughness: 0.6 }),
    skyline: std({ color: 0x55606b, roughness: 0.9 }),
    trafficLight: std({ color: 0x1b1d1f, roughness: 0.6 }),
    tlRed: std({ color: 0x330000, emissive: 0xff2200, emissiveIntensity: 1.5 }),
    tlGreen: std({ color: 0x003300, emissive: 0x22ff66, emissiveIntensity: 1.2 }),
    // weapons + characters
    gunMetal: std({ color: 0x26282b, roughness: 0.42, metalness: 0.75 }),
    polymer: std({ color: 0x1a1b1c, roughness: 0.75 }),
    tan: std({ color: 0x6d5c41, roughness: 0.8 }),
    glove: std({ color: 0x232323, roughness: 0.9 }),
    sleeve: std({ color: 0x4b5139, roughness: 0.95 }),
    lens: std({ color: 0x0a1a2a, roughness: 0.05, metalness: 1, emissive: 0x102040, emissiveIntensity: 0.3 }),
    redDot: new THREE.MeshBasicMaterial({ color: new THREE.Color(4, 0.2, 0.1) }),
    skins: [0xc68863, 0x8d5524, 0xe0ac69, 0x5c3a21, 0xf1c27d].map((c) => std({ color: c, roughness: 0.75 })),
    uniforms: {
      rifle: std({ color: 0x4d5531, roughness: 0.95 }),
      heavy: std({ color: 0x1d1f22, roughness: 0.9 }),
      sniper: std({ color: 0x3e3a2a, roughness: 1 }),
      guard: std({ color: 0x1c2333, roughness: 0.85 }),
      vip: std({ color: 0x15171c, roughness: 0.6 }),
    },
    vest: std({ color: 0x8a7a55, roughness: 0.9 }),
    vestDark: std({ color: 0x3b3e42, roughness: 0.8 }),
    shirt: std({ color: 0xe8e8e8, roughness: 0.8 }),
    helmet: std({ color: 0x4a4f36, roughness: 0.7 }),
    helmetDark: std({ color: 0x202224, roughness: 0.5, metalness: 0.3 }),
    visor: std({ color: 0x080808, roughness: 0.1, metalness: 0.9 }),
    boot: std({ color: 0x1a1612, roughness: 0.9 }),
    balaclava: std({ color: 0x151515, roughness: 1 }),
    hair: std({ color: 0x1b140f, roughness: 0.9 }),
    tie: std({ color: 0x8c1c1c, roughness: 0.6 }),
  };
  m.facades = FACADE_STYLES.map((s, i) => {
    const f = facade(s, 100 + i * 7);
    return std({
      map: f.map, emissiveMap: f.emissive, emissive: 0xffffff, emissiveIntensity: 0,
      roughness: s.rough ?? 0.88, metalness: s.metal ?? 0,
    });
  });
  const sf = storefront();
  m.storefront = std({ map: sf.map, emissiveMap: sf.emissive, emissive: 0xffffff, emissiveIntensity: 0.2, roughness: 0.25, metalness: 0.5 });
  m.skylines = m.facades.map((f) => new THREE.MeshLambertMaterial({ map: f.map, emissiveMap: f.emissiveMap, emissive: 0xffffff, emissiveIntensity: 0 }));
  LIB = { tex: t, mat: m };
  return LIB;
}

// Called when the time of day changes: window lights, lamps, headlights.
export function setNightLevel(v) {
  const { mat } = library();
  for (const f of mat.facades) f.emissiveIntensity = v;
  for (const f of mat.skylines) f.emissiveIntensity = v * 0.9;
  mat.storefront.emissiveIntensity = 0.15 + v * 0.9;
  mat.lampGlass.emissiveIntensity = v > 0.3 ? 6 : 0;
  mat.headlight.emissiveIntensity = 0.3 + v;
  mat.taillight.emissiveIntensity = 0.4 + v;
}
