// Fully synthesized sound effects (WebAudio) - no audio files needed.
export class GameAudio {
  constructor() {
    this.ctx = null;
    this.volume = 0.8;
  }

  init() {
    if (this.ctx) {
      if (this.ctx.state === 'suspended') this.ctx.resume();
      return;
    }
    const AC = window.AudioContext || window.webkitAudioContext;
    if (!AC) return;
    const ctx = (this.ctx = new AC());
    this.master = ctx.createGain();
    this.master.gain.value = this.volume;
    const comp = ctx.createDynamicsCompressor();
    comp.threshold.value = -14; comp.ratio.value = 6;
    this.master.connect(comp).connect(ctx.destination);

    const len = ctx.sampleRate * 2;
    this.noiseBuf = ctx.createBuffer(1, len, ctx.sampleRate);
    const d = this.noiseBuf.getChannelData(0);
    for (let i = 0; i < len; i++) d[i] = Math.random() * 2 - 1;

    // Generated impulse response for a city-street reverb tail.
    const ir = ctx.createBuffer(2, ctx.sampleRate * 2.6, ctx.sampleRate);
    for (let c = 0; c < 2; c++) {
      const ch = ir.getChannelData(c);
      for (let i = 0; i < ch.length; i++) {
        const t = i / ch.length;
        ch[i] = (Math.random() * 2 - 1) * Math.pow(1 - t, 3.2) * (i % 2400 < 40 ? 2 : 1);
      }
    }
    this.reverb = ctx.createConvolver();
    this.reverb.buffer = ir;
    this.reverbIn = ctx.createGain();
    this.reverbIn.gain.value = 0.55;
    this.reverbIn.connect(this.reverb).connect(this.master);
    this.startAmbient();
  }

  setVolume(v) {
    this.volume = v;
    if (this.master) this.master.gain.value = v;
  }

  suspend() { if (this.ctx && this.ctx.state === 'running') this.ctx.suspend(); }
  resume() { if (this.ctx && this.ctx.state === 'suspended') this.ctx.resume(); }

  _out(pan = 0, reverb = 0) {
    const ctx = this.ctx;
    const g = ctx.createGain();
    let node = g;
    if (pan && ctx.createStereoPanner) {
      const p = ctx.createStereoPanner();
      p.pan.value = Math.max(-1, Math.min(1, pan));
      g.connect(p); node = p;
    }
    node.connect(this.master);
    if (reverb > 0) {
      const s = ctx.createGain(); s.gain.value = reverb;
      node.connect(s).connect(this.reverbIn);
    }
    return g;
  }

  _noise(t0, dur, type, f0, f1, q, gain, attack, out) {
    const ctx = this.ctx;
    const src = ctx.createBufferSource();
    src.buffer = this.noiseBuf;
    src.playbackRate.value = 0.8 + Math.random() * 0.4;
    const f = ctx.createBiquadFilter();
    f.type = type; f.Q.value = q;
    f.frequency.setValueAtTime(f0, t0);
    f.frequency.exponentialRampToValueAtTime(Math.max(20, f1), t0 + dur);
    const g = ctx.createGain();
    g.gain.setValueAtTime(0.0001, t0);
    g.gain.exponentialRampToValueAtTime(gain, t0 + attack);
    g.gain.exponentialRampToValueAtTime(0.0001, t0 + dur);
    src.connect(f).connect(g).connect(out);
    src.start(t0, Math.random() * 1.5, dur + 0.05);
  }

  _tone(t0, dur, type, f0, f1, gain, out, attack = 0.002) {
    const ctx = this.ctx;
    const o = ctx.createOscillator();
    o.type = type;
    o.frequency.setValueAtTime(f0, t0);
    o.frequency.exponentialRampToValueAtTime(Math.max(10, f1), t0 + dur);
    const g = ctx.createGain();
    g.gain.setValueAtTime(0.0001, t0);
    g.gain.exponentialRampToValueAtTime(gain, t0 + attack);
    g.gain.exponentialRampToValueAtTime(0.0001, t0 + dur);
    o.connect(g).connect(out);
    o.start(t0); o.stop(t0 + dur + 0.05);
  }

  get ok() { return this.ctx && this.ctx.state === 'running'; }

  playerShot(kind) {
    if (!this.ok) return;
    const t = this.ctx.currentTime;
    if (kind === 'sniper') {
      const out = this._out(0, 0.9);
      this._noise(t, 0.06, 'highpass', 3000, 2000, 0.7, 1.2, 0.001, out);
      this._noise(t, 0.6, 'lowpass', 3200, 140, 0.8, 1.4, 0.003, out);
      this._tone(t, 0.35, 'sine', 110, 32, 1.2, out);
    } else {
      const out = this._out(0, 0.35);
      this._noise(t, 0.035, 'highpass', 2500, 1800, 0.7, 0.7, 0.001, out);
      this._noise(t, 0.2, 'lowpass', 2200, 260, 0.9, 0.9, 0.002, out);
      this._tone(t, 0.12, 'sine', 150, 48, 0.7, out);
    }
  }

  enemyShot(dist, pan, sniper = false) {
    if (!this.ok) return;
    const delay = Math.min(dist / 343, 0.45);
    const t = this.ctx.currentTime + delay;
    const g = Math.min(0.9, 9 / (6 + dist)) * (sniper ? 1.6 : 1);
    const out = this._out(pan, 0.7);
    this._noise(t, sniper ? 0.5 : 0.22, 'lowpass', sniper ? 1800 : 1300, 180, 0.8, g, 0.003, out);
    this._tone(t, 0.12, 'sine', 120, 45, g * 0.6, out);
  }

  whiz(pan) {
    if (!this.ok) return;
    const t = this.ctx.currentTime;
    this._noise(t, 0.18, 'bandpass', 3500, 900, 6, 0.5, 0.02, this._out(pan));
  }

  impact(kind = 'world', pan = 0) {
    if (!this.ok) return;
    const t = this.ctx.currentTime, out = this._out(pan);
    if (kind === 'metal') {
      this._tone(t, 0.25, 'triangle', 2400 + Math.random() * 800, 1500, 0.15, out);
      this._noise(t, 0.05, 'highpass', 4000, 3000, 1, 0.3, 0.001, out);
    } else if (kind === 'ricochet') {
      this._tone(t, 0.3, 'sine', 2600 + Math.random() * 900, 650, 0.12, out, 0.01);
    } else {
      this._noise(t, 0.06, 'bandpass', 1800, 600, 1.5, 0.35, 0.001, out);
    }
  }

  hitmarker(head) {
    if (!this.ok) return;
    const t = this.ctx.currentTime, out = this._out(0);
    if (head) {
      this._tone(t, 0.4, 'sine', 1320, 1300, 0.35, out);
      this._tone(t, 0.3, 'sine', 2640, 2600, 0.15, out);
    } else {
      this._tone(t, 0.05, 'square', 1700, 1600, 0.08, out);
    }
  }

  flesh() {
    if (!this.ok) return;
    const t = this.ctx.currentTime;
    this._noise(t, 0.12, 'lowpass', 900, 200, 1, 0.5, 0.002, this._out(0));
  }

  explosion(dist = 20) {
    if (!this.ok) return;
    const t = this.ctx.currentTime + Math.min(dist / 343, 0.3);
    const g = Math.min(1.6, 40 / (10 + dist));
    const out = this._out(0, 1.0);
    this._noise(t, 1.8, 'lowpass', 1400, 50, 0.7, g, 0.005, out);
    this._noise(t, 0.3, 'highpass', 1500, 800, 0.7, g * 0.5, 0.002, out);
    this._tone(t, 1.0, 'sine', 70, 22, g, out);
  }

  click(t0 = 0, f = 2500, g = 0.25) {
    if (!this.ok) return;
    const t = this.ctx.currentTime + t0;
    this._noise(t, 0.045, 'bandpass', f, f * 0.7, 3, g, 0.001, this._out(0.2));
  }

  reload(dur) {
    this.click(dur * 0.12, 1800, 0.25);
    this.click(dur * 0.55, 2200, 0.35);
    this.click(dur * 0.85, 3000, 0.3);
    this.click(dur * 0.9, 1500, 0.3);
  }

  bolt() {
    this.click(0.28, 2600, 0.3);
    this.click(0.45, 1900, 0.3);
    this.click(0.62, 2800, 0.25);
  }

  empty() { this.click(0, 3500, 0.2); }

  beep() {
    if (!this.ok) return;
    const t = this.ctx.currentTime;
    this._tone(t, 0.09, 'sine', 1500, 1500, 0.12, this._out(0));
  }

  ui() {
    if (!this.ok) return;
    const t = this.ctx.currentTime;
    this._tone(t, 0.05, 'sine', 900, 600, 0.12, this._out(0));
  }

  heartbeat() {
    if (!this.ok) return;
    const t = this.ctx.currentTime, out = this._out(0);
    this._tone(t, 0.12, 'sine', 70, 40, 0.5, out, 0.01);
    this._tone(t + 0.18, 0.12, 'sine', 60, 35, 0.35, out, 0.01);
  }

  bulletTime() {
    if (!this.ok) return;
    const t = this.ctx.currentTime, out = this._out(0, 0.8);
    this._noise(t, 1.6, 'bandpass', 600, 180, 2, 0.6, 0.2, out);
    this._tone(t, 1.6, 'sawtooth', 90, 40, 0.08, out, 0.2);
  }

  startAmbient() {
    const ctx = this.ctx;
    const src = ctx.createBufferSource();
    src.buffer = this.noiseBuf; src.loop = true;
    const f = ctx.createBiquadFilter(); f.type = 'lowpass'; f.frequency.value = 380;
    const g = ctx.createGain(); g.gain.value = 0.07;
    const lfo = ctx.createOscillator(); lfo.frequency.value = 0.07;
    const lg = ctx.createGain(); lg.gain.value = 0.04;
    lfo.connect(lg).connect(g.gain);
    src.connect(f).connect(g).connect(this.master);
    src.start(); lfo.start();
  }
}
