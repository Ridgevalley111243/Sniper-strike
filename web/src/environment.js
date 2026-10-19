// Sky dome, sun/moon, fog and time-of-day presets.
import * as THREE from 'three';
import { setNightLevel } from './textures.js';

export const TIMES = {
  day: {
    label: 'Day', top: 0x2b68b3, horizon: 0xbcd2e6, bottom: 0x6e7880, sunElev: 52, sunAzim: 28,
    sunColor: 0xfff1da, sunInt: 3.4, sunSize: 0.0009, glow: 0.6,
    hemiSky: 0xbfd8ff, hemiGround: 0x5c564c, hemiInt: 0.85, env: 0.55,
    fog: 0xb4c6d6, fogNear: 90, fogFar: 620, exposure: 0.82, night: 0, stars: 0,
  },
  morning: {
    label: 'Dawn', top: 0x46709f, horizon: 0xf0c49c, bottom: 0x6c6560, sunElev: 13, sunAzim: -35,
    sunColor: 0xffcf9a, sunInt: 2.9, sunSize: 0.0012, glow: 1.0,
    hemiSky: 0xa9c0e0, hemiGround: 0x5a4c40, hemiInt: 0.7, env: 0.5,
    fog: 0xd4bea8, fogNear: 70, fogFar: 520, exposure: 0.85, night: 0.18, stars: 0,
  },
  sunset: {
    label: 'Sunset', top: 0x26386a, horizon: 0xff955a, bottom: 0x4a3a35, sunElev: 6, sunAzim: 18,
    sunColor: 0xff8848, sunInt: 2.6, sunSize: 0.0016, glow: 1.4,
    hemiSky: 0x7183b6, hemiGround: 0x4d3b32, hemiInt: 0.6, env: 0.45,
    fog: 0xc98b6b, fogNear: 60, fogFar: 460, exposure: 0.92, night: 0.65, stars: 0,
  },
  night: {
    label: 'Night', top: 0x02050c, horizon: 0x1c1d2b, bottom: 0x09090c, sunElev: 38, sunAzim: -40,
    sunColor: 0x9fb2ff, sunInt: 0.45, sunSize: 0.0006, glow: 0.25,
    hemiSky: 0x33405e, hemiGround: 0x16120f, hemiInt: 0.45, env: 0.3,
    fog: 0x11141d, fogNear: 30, fogFar: 330, exposure: 1.15, night: 1.6, stars: 1,
  },
};

const skyVert = /* glsl */ `
varying vec3 vDir;
void main() {
  vDir = normalize(position);
  gl_Position = projectionMatrix * modelViewMatrix * vec4(position, 1.0);
}`;

const skyFrag = /* glsl */ `
uniform vec3 top; uniform vec3 horizon; uniform vec3 bottom;
uniform vec3 sunDir; uniform vec3 sunColor;
uniform float sunSize; uniform float glow; uniform float stars;
varying vec3 vDir;
float hash(vec3 p) { p = fract(p * 0.3183099 + 0.1); p *= 17.0; return fract(p.x * p.y * p.z * (p.x + p.y + p.z)); }
void main() {
  vec3 d = normalize(vDir);
  float h = d.y;
  vec3 col = h > 0.0 ? mix(horizon, top, pow(clamp(h, 0.0, 1.0), 0.5)) : mix(horizon, bottom, clamp(-h * 5.0, 0.0, 1.0));
  float sd = max(dot(d, normalize(sunDir)), 0.0);
  col += sunColor * (pow(sd, 6.0) * 0.25 + pow(sd, 48.0) * 0.6) * glow;
  col += sunColor * smoothstep(1.0 - sunSize, 1.0 - sunSize * 0.5, sd) * 6.0;
  if (stars > 0.0 && h > 0.02) {
    vec3 sp = floor(d * 420.0);
    float s = hash(sp);
    col += vec3(smoothstep(0.9975, 1.0, s)) * stars * smoothstep(0.02, 0.3, h) * 1.5;
  }
  gl_FragColor = vec4(col, 1.0);
  #include <tonemapping_fragment>
  #include <colorspace_fragment>
}`;

export class Environment {
  constructor(renderer, scene) {
    this.renderer = renderer;
    this.scene = scene;
    this.uniforms = {
      top: { value: new THREE.Color() }, horizon: { value: new THREE.Color() }, bottom: { value: new THREE.Color() },
      sunDir: { value: new THREE.Vector3(0, 1, 0) }, sunColor: { value: new THREE.Color() },
      sunSize: { value: 0.001 }, glow: { value: 1 }, stars: { value: 0 },
    };
    const mat = new THREE.ShaderMaterial({
      uniforms: this.uniforms, vertexShader: skyVert, fragmentShader: skyFrag,
      side: THREE.BackSide, depthWrite: false, depthTest: false, fog: false,
    });
    this.dome = new THREE.Mesh(new THREE.SphereGeometry(900, 32, 16), mat);
    this.dome.renderOrder = -1000;
    this.dome.frustumCulled = false;
    scene.add(this.dome);

    this.envScene = new THREE.Scene();
    this.envScene.add(new THREE.Mesh(this.dome.geometry, mat));
    this.pmrem = new THREE.PMREMGenerator(renderer);
    this.envRT = null;

    this.sun = new THREE.DirectionalLight(0xffffff, 3);
    this.sun.target.position.set(0, 0, -60);
    scene.add(this.sun, this.sun.target);
    this.hemi = new THREE.HemisphereLight(0xffffff, 0x444444, 1);
    scene.add(this.hemi);
    scene.fog = new THREE.Fog(0xffffff, 80, 600);
    this.sunDir = new THREE.Vector3();
  }

  configureShadows(q) {
    const s = this.sun;
    s.castShadow = q.shadows > 0;
    if (!s.castShadow) return;
    s.shadow.mapSize.set(q.shadows, q.shadows);
    const c = s.shadow.camera;
    c.left = -95; c.right = 95; c.top = 95; c.bottom = -95; c.near = 1; c.far = 600;
    c.updateProjectionMatrix();
    s.shadow.bias = -0.0004;
    s.shadow.normalBias = 0.04;
    if (s.shadow.map) { s.shadow.map.dispose(); s.shadow.map = null; }
  }

  apply(timeKey, focusZ = -60) {
    const t = TIMES[timeKey] || TIMES.day;
    this.time = t;
    const u = this.uniforms;
    u.top.value.set(t.top); u.horizon.value.set(t.horizon); u.bottom.value.set(t.bottom);
    const el = THREE.MathUtils.degToRad(t.sunElev), az = THREE.MathUtils.degToRad(t.sunAzim);
    // azimuth 0 = straight down the street (towards -z)
    this.sunDir.set(Math.sin(az) * Math.cos(el), Math.sin(el), -Math.cos(az) * Math.cos(el)).normalize();
    u.sunDir.value.copy(this.sunDir);
    u.sunColor.value.set(t.sunColor);
    u.sunSize.value = t.sunSize; u.glow.value = t.glow; u.stars.value = t.stars;

    this.sun.color.set(t.sunColor);
    this.sun.intensity = t.sunInt;
    this.sun.target.position.set(0, 0, focusZ);
    this.sun.position.copy(this.sun.target.position).addScaledVector(this.sunDir, 300);
    this.hemi.color.set(t.hemiSky); this.hemi.groundColor.set(t.hemiGround); this.hemi.intensity = t.hemiInt;
    this.scene.fog.color.set(t.fog); this.scene.fog.near = t.fogNear; this.scene.fog.far = t.fogFar;
    this.renderer.toneMappingExposure = t.exposure;
    setNightLevel(t.night);

    if (this.envRT) this.envRT.dispose();
    this.envRT = this.pmrem.fromScene(this.envScene, 0, 0.1, 1000);
    this.scene.environment = this.envRT.texture;
    this.scene.environmentIntensity = t.env;
  }
}
