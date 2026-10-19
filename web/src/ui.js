// HUD, menus and input (multi-touch, mouse with pointer lock, keyboard).
import * as THREE from 'three';
import { MISSIONS, UPGRADES, WEAPONS, writeSave, resetSave } from './missions.js';
import { TIMES } from './environment.js';

const $ = (s) => document.querySelector(s);
const $$ = (s) => document.querySelectorAll(s);
const _v = new THREE.Vector3(), _f = new THREE.Vector3();

export class UI {
  constructor(game) {
    this.game = game;
    this.el = {
      hud: $('#hud'), hpFill: $('#hpFill'), hpGhost: $('#hpGhost'), objective: $('#objective'),
      wave: $('#wave'), hostiles: $('#hostileCount'), banner: $('#banner'), bannerTitle: $('#bannerTitle'),
      bannerSub: $('#bannerSub'), hint: $('#hint'), killfeed: $('#killfeed'), crosshair: $('#crosshair'),
      hitmarker: $('#hitmarker'), scope: $('#scope'), zoomLabel: $('#zoomLabel'), rangeLabel: $('#rangeLabel'),
      steady: $('#steadyFill'), zoomWrap: $('#zoomWrap'), zoom: $('#zoom'), dmg: $('#dmg'), lowhp: $('#lowhp'),
      indicators: $('#indicators'), ammoCount: $('#ammoCount'), ammoMag: $('#ammoMag'), weaponName: $('#weaponName'),
      reloadBar: $('#reloadBar'), reloadFill: $('#reloadBar div'), fireBtn: $('#fireBtn'), fireLabel: $('#fireLabel'),
      peekBtn: $('#peekBtn'), reloadBtn: $('#reloadBtn'), swapBtn: $('#swapBtn'), swapName: $('#swapName'),
      letterbox: $('#letterbox'), kcText: $('#kcText'), fps: $('#fps'),
    };
    this.screen = null;
    this.bindMenus();
    this.bindInput();
    this.rangeT = 0;
  }

  // ---------------- screens ----------------
  show(name) {
    this.screen = name;
    for (const s of $$('.screen')) s.classList.toggle('show', s.id === 'scr-' + name);
    if (name === 'main' || name === 'campaign' || name === 'armory') this.refreshCoins();
    if (name === 'campaign') this.renderCampaign();
    if (name === 'armory') this.renderArmory();
    if (name === 'settings') this.renderSettings();
  }
  hideScreens() { this.screen = null; for (const s of $$('.screen')) s.classList.remove('show'); }

  refreshCoins() { for (const c of $$('.coinVal')) c.textContent = this.game.save.coins.toLocaleString(); }

  bindMenus() {
    const g = this.game;
    document.addEventListener('click', (e) => {
      const b = e.target.closest('[data-go]');
      if (b) { g.audio.init(); g.audio.ui(); this.show(b.dataset.go); }
    });
    $('#deployBtn').onclick = () => { g.audio.ui(); g.startMission(this.selected); };
    $('#pauseBtn').onclick = () => g.pause();
    $('#resumeBtn').onclick = () => g.resume();
    $('#restartBtn').onclick = () => g.startMission(g.mission.def);
    $('#quitBtn').onclick = () => g.toMenu();
    $('#resMenu').onclick = () => g.toMenu('campaign');
    $('#resRetry').onclick = () => g.startMission(g.mission.def);
    $('#resNext').onclick = () => {
      const next = MISSIONS.find((m) => m.id === g.mission.def.id + 1);
      if (next) { this.selected = next; this.renderBriefing(next); this.show('briefing'); }
      else g.toMenu('campaign');
    };
    for (const b of $$('#qualitySeg button')) {
      b.onclick = () => {
        g.save.settings.quality = b.dataset.q;
        writeSave(g.save);
        location.reload();
      };
    }
    $('#sensSlider').oninput = (e) => { g.save.settings.sens = +e.target.value; writeSave(g.save); };
    $('#volSlider').oninput = (e) => { g.save.settings.volume = +e.target.value; g.audio.setVolume(+e.target.value); writeSave(g.save); };
    $('#fpsToggle').onchange = (e) => { g.save.settings.fps = e.target.checked; writeSave(g.save); this.el.fps.textContent = ''; };
    $('#resetBtn').onclick = () => {
      if (!confirm('Reset all progress, coins and upgrades?')) return;
      const settings = g.save.settings;
      g.save = resetSave();
      g.save.settings = settings;
      writeSave(g.save);
      this.show('main');
    };
  }

  renderCampaign() {
    const s = this.game.save;
    const list = $('#missionList');
    list.innerHTML = '';
    for (const m of MISSIONS) {
      const locked = m.id > s.unlocked;
      const stars = s.stars[m.id] || 0;
      const c = document.createElement('button');
      c.className = 'card' + (locked ? ' locked' : '');
      c.innerHTML = `<div class="num">0${m.id}</div>
        <div class="chips"><span class="chip t-${m.time}">${TIMES[m.time].label.toUpperCase()}</span>
        <span class="chip">${m.type === 'assassinate' ? 'ASSASSINATION' : 'DEFENSE'}</span>
        <span class="chip">${m.vantage === 'roof' ? 'ROOFTOP' : 'STREET'}</span></div>
        <h3>${m.name.toUpperCase()}</h3>
        <div class="stars">${starStr(stars)}</div>
        <div class="reward"><span class="coin"></span>${m.reward}</div>`;
      if (!locked) c.onclick = () => { this.game.audio.init(); this.game.audio.ui(); this.selected = m; this.renderBriefing(m); this.show('briefing'); };
      list.appendChild(c);
    }
  }

  renderBriefing(m) {
    $('#briefTitle').textContent = `0${m.id} · ${m.name.toUpperCase()}`;
    $('#briefMeta').innerHTML = `<span class="chip t-${m.time}">${TIMES[m.time].label.toUpperCase()}</span>
      <span class="chip">${m.vantage === 'roof' ? 'ROOFTOP OVERWATCH' : 'STREET BARRICADE'}</span>
      <span class="chip">LOADOUT: ${WEAPONS[m.loadout].name}</span>
      <span class="chip">RANGE ${m.range[0]}–${m.range[1]} M</span>`;
    $('#briefText').textContent = m.brief;
    const obj = m.type === 'assassinate'
      ? ['Eliminate the marked target before he escapes', 'Neutralize all remaining hostiles']
      : [`Survive ${m.waves.length} waves of hostiles`, 'Eliminate every enemy combatant'];
    $('#briefObj').innerHTML = obj.map((o) => `<li>${o}</li>`).join('') + '<li style="color:var(--muted)">★ Complete · ★ Accuracy ≥ 55% · ★ Health ≥ 60% at the end</li>';
  }

  renderArmory() {
    const g = this.game, s = g.save;
    const list = $('#upgradeList');
    list.innerHTML = '';
    for (const u of UPGRADES) {
      const lvl = s.upgrades[u.key] || 0;
      const max = u.cost.length;
      const cost = u.cost[lvl];
      const d = document.createElement('div');
      d.className = 'upg';
      d.innerHTML = `<h4>${u.name.toUpperCase()}</h4><p>${u.desc}</p>
        <div class="pips">${Array.from({ length: max }, (_, i) => `<i class="${i < lvl ? 'on' : ''}"></i>`).join('')}</div>`;
      const b = document.createElement('button');
      b.className = 'btn' + (lvl < max && s.coins >= cost ? ' primary' : '');
      if (lvl >= max) { b.textContent = 'MAXED'; b.disabled = true; }
      else {
        b.innerHTML = `UPGRADE <span class="coin"></span>${cost}`;
        b.disabled = s.coins < cost;
        b.onclick = () => {
          if (s.coins < cost) return;
          s.coins -= cost;
          s.upgrades[u.key] = lvl + 1;
          writeSave(s);
          g.audio.ui();
          this.refreshCoins();
          this.renderArmory();
        };
      }
      d.appendChild(b);
      list.appendChild(d);
    }
  }

  renderSettings() {
    const st = this.game.save.settings;
    for (const b of $$('#qualitySeg button')) b.classList.toggle('on', b.dataset.q === st.quality);
    $('#sensSlider').value = st.sens;
    $('#volSlider').value = st.volume;
    $('#fpsToggle').checked = st.fps;
  }

  renderResult(r) {
    const t = $('#resTitle');
    t.textContent = r.win ? 'MISSION COMPLETE' : r.reason || 'MISSION FAILED';
    t.className = r.win ? 'win' : 'lose';
    $('#resStars').innerHTML = r.win ? starStr(r.stars) : '';
    const acc = r.shots ? Math.round((r.hits / r.shots) * 100) : 0;
    const mins = Math.floor(r.time / 60), secs = Math.floor(r.time % 60);
    $('#resStats').innerHTML = [
      ['KILLS', r.kills], ['HEADSHOTS', r.headshots], ['ACCURACY', acc + '%'], ['TIME', `${mins}:${String(secs).padStart(2, '0')}`],
    ].map(([k, v]) => `<div><b>${v}</b><span>${k}</span></div>`).join('');
    $('#resCoins').innerHTML = `+<span class="coin"></span>${r.coins}`;
    $('#resNext').classList.toggle('hidden', !r.win || !MISSIONS.find((m) => m.id === r.id + 1));
    this.show('result');
  }

  // ---------------- HUD ----------------
  hud(on) {
    this.el.hud.classList.toggle('hidden', !on);
    if (on) { this.el.killfeed.innerHTML = ''; this.el.indicators.innerHTML = ''; this.el.dmg.style.opacity = 0; }
  }

  banner(title, sub = '', dur = 2.2) {
    const e = this.el;
    e.bannerTitle.textContent = title;
    e.bannerSub.textContent = sub;
    e.banner.classList.add('show');
    clearTimeout(this.bannerTO);
    this.bannerTO = setTimeout(() => e.banner.classList.remove('show'), dur * 1000);
  }

  hint(text, dur = 4) {
    const e = this.el;
    e.hint.textContent = text;
    e.hint.classList.add('show');
    clearTimeout(this.hintTO);
    this.hintTO = setTimeout(() => e.hint.classList.remove('show'), dur * 1000);
  }

  objective(html) { this.el.objective.innerHTML = html; }

  hitmarker(head) {
    const h = this.el.hitmarker;
    h.classList.remove('show');
    void h.offsetWidth;
    h.classList.toggle('head', head);
    h.classList.add('show');
  }

  killfeed(text, head) {
    const d = document.createElement('div');
    d.textContent = text;
    if (head) d.className = 'head';
    this.el.killfeed.prepend(d);
    setTimeout(() => d.remove(), 3000);
    while (this.el.killfeed.children.length > 4) this.el.killfeed.lastChild.remove();
  }

  damage(player, fromPos) {
    const e = this.el;
    e.dmg.style.transition = 'none';
    e.dmg.style.opacity = 1;
    requestAnimationFrame(() => { e.dmg.style.transition = 'opacity .6s'; e.dmg.style.opacity = 0; });
    if (!fromPos) return;
    const cam = this.game.camera;
    _f.set(0, 0, -1).applyQuaternion(cam.quaternion); _f.y = 0; _f.normalize();
    _v.subVectors(fromPos, cam.position); _v.y = 0; _v.normalize();
    const ang = Math.atan2(_f.x * _v.z - _f.z * _v.x, _f.dot(_v));
    const d = document.createElement('div');
    d.style.transform = `rotate(${ang}rad)`;
    e.indicators.appendChild(d);
    setTimeout(() => d.remove(), 1600);
  }

  weapon(p) {
    const e = this.el;
    const other = p.cur === 'rifle' ? 'sniper' : 'rifle';
    e.weaponName.textContent = WEAPONS[p.cur].name;
    e.swapName.textContent = WEAPONS[other].name;
    e.fireLabel.textContent = p.cur === 'sniper' ? 'AIM' : 'FIRE';
    e.zoom.max = p.zoomMax;
  }

  update(dt) {
    const g = this.game, p = g.player, e = this.el;
    if (g.save.settings.fps) {
      this.fpsAcc = (this.fpsAcc || 0) + dt; this.fpsN = (this.fpsN || 0) + 1;
      if (this.fpsAcc > 0.5) { e.fps.textContent = Math.round(this.fpsN / this.fpsAcc) + ' FPS'; this.fpsAcc = 0; this.fpsN = 0; }
    }
    if (g.state !== 'playing' || !p.active) return;
    const hpK = p.hp / p.maxHp;
    e.hpFill.style.transform = `scaleX(${hpK})`;
    e.hpGhost.style.transform = `scaleX(${hpK})`;
    e.hpFill.classList.toggle('low', hpK < 0.3);
    e.lowhp.style.opacity = hpK < 0.3 ? (0.3 - hpK) * 3 : 0;
    const w = p.w;
    e.ammoCount.textContent = w.ammo;
    e.ammoCount.classList.toggle('low', w.ammo <= Math.ceil(w.def.mag * 0.2));
    e.ammoMag.textContent = '/' + w.def.mag;
    if (p.reloading > 0) {
      e.reloadBar.style.opacity = 1;
      e.reloadFill.style.transform = `scaleX(${1 - p.reloading / w.reloadTime})`;
    } else e.reloadBar.style.opacity = 0;
    e.hostiles.textContent = g.hostilesLeft();
    // crosshair + scope
    const sc = p.scopeT;
    e.scope.style.opacity = sc > 0.5 ? 1 : 0;
    e.zoomWrap.classList.toggle('show', p.cur === 'sniper' && sc > 0.5);
    if (sc > 0.5) {
      e.zoomLabel.textContent = p.zoom.toFixed(1) + 'x';
      this.rangeT -= dt;
      if (this.rangeT <= 0) {
        this.rangeT = 0.15;
        const d = g.rangeToAim();
        e.rangeLabel.textContent = d ? Math.round(d) + ' m' : '--- m';
      }
      const steadyK = p.steady < 4 ? 1 - p.steady / 4 : 0;
      e.steady.style.transform = `scaleX(${steadyK})`;
      if (+e.zoom.value !== p.zoom) e.zoom.value = p.zoom;
    }
    const exposed = p.peekT > 0.5;
    const spread = p.cur === 'rifle' ? 6 + p.heat * 14 + (exposed ? 0 : 6) : 4;
    const ch = e.crosshair.children;
    ch[0].style.top = -(spread + 9) + 'px'; ch[1].style.top = spread + 'px';
    ch[2].style.left = -(spread + 9) + 'px'; ch[3].style.left = spread + 'px';
    e.crosshair.style.opacity = sc > 0.5 ? 0 : exposed ? 0.95 : 0.35;
    e.peekBtn.classList.toggle('on', p.latched);
    e.fireBtn.classList.toggle('active', p.fireHeld);
  }

  killcam(on, text = '', sub = '') {
    const e = this.el;
    e.letterbox.classList.toggle('show', on);
    e.kcText.classList.remove('show');
    if (text) {
      e.kcText.innerHTML = `${text}<small>${sub}</small>`;
      e.kcText.classList.add('show');
    }
  }

  // ---------------- input ----------------
  bindInput() {
    const g = this.game;
    const touch = $('#touch');
    let aimId = null, lx = 0, ly = 0;
    const playing = () => g.state === 'playing';

    touch.addEventListener('pointerdown', (e) => {
      g.audio.init();
      if (!playing()) return;
      if (e.pointerType === 'mouse') {
        if (!document.pointerLockElement && touch.requestPointerLock) {
          try { const r = touch.requestPointerLock(); if (r && r.catch) r.catch(() => {}); } catch (err) { /* unsupported */ }
        }
        if (document.pointerLockElement) {
          if (e.button === 0) g.player.fireDown();
          if (e.button === 2) g.player.togglePeek();
          return;
        }
      }
      if (aimId === null) {
        aimId = e.pointerId; lx = e.clientX; ly = e.clientY;
        touch.setPointerCapture(e.pointerId);
      }
    });
    touch.addEventListener('pointermove', (e) => {
      if (e.pointerId !== aimId || !playing()) return;
      g.player.aim(e.clientX - lx, e.clientY - ly);
      lx = e.clientX; ly = e.clientY;
    });
    const endAim = (e) => { if (e.pointerId === aimId) aimId = null; };
    touch.addEventListener('pointerup', (e) => {
      if (e.pointerType === 'mouse' && document.pointerLockElement && e.button === 0) g.player.fireUp();
      endAim(e);
    });
    touch.addEventListener('pointercancel', endAim);
    touch.addEventListener('contextmenu', (e) => e.preventDefault());
    document.addEventListener('mousemove', (e) => {
      if (document.pointerLockElement && playing()) g.player.aim(e.movementX, e.movementY);
    });
    document.addEventListener('pointerlockchange', () => {
      if (!document.pointerLockElement && playing()) g.player.fireUp();
    });
    touch.addEventListener('wheel', (e) => {
      if (playing() && g.player.cur === 'sniper') g.player.setZoom(g.player.zoom - Math.sign(e.deltaY) * 0.5);
    }, { passive: true });

    // FIRE button doubles as an aim pad while held (drag to adjust aim, Cover Fire style)
    const fire = this.el.fireBtn;
    let fireId = null, fx = 0, fy = 0;
    fire.addEventListener('pointerdown', (e) => {
      g.audio.init();
      e.preventDefault();
      if (!playing() || fireId !== null) return;
      fireId = e.pointerId; fx = e.clientX; fy = e.clientY;
      fire.setPointerCapture(e.pointerId);
      g.player.fireDown();
    });
    fire.addEventListener('pointermove', (e) => {
      if (e.pointerId !== fireId || !playing()) return;
      g.player.aim(e.clientX - fx, e.clientY - fy);
      fx = e.clientX; fy = e.clientY;
    });
    const fireEnd = (e) => {
      if (e.pointerId !== fireId) return;
      fireId = null;
      g.player.fireUp();
    };
    fire.addEventListener('pointerup', fireEnd);
    fire.addEventListener('pointercancel', fireEnd);

    const tap = (el, fn) => el.addEventListener('pointerdown', (e) => { e.preventDefault(); e.stopPropagation(); g.audio.init(); if (playing()) fn(); });
    tap(this.el.peekBtn, () => g.player.togglePeek());
    tap(this.el.reloadBtn, () => g.player.reload());
    tap(this.el.swapBtn, () => g.player.switchWeapon());
    this.el.zoom.addEventListener('input', (e) => g.player.setZoom(+e.target.value));
    this.el.zoom.addEventListener('pointerdown', (e) => e.stopPropagation());
    this.el.letterbox.addEventListener('pointerdown', () => g.skipKillcam());

    window.addEventListener('keydown', (e) => {
      if (e.repeat) return;
      if (e.code === 'Escape' || e.code === 'KeyP') {
        if (playing()) g.pause(); else if (g.state === 'paused') g.resume();
        return;
      }
      if (!playing()) return;
      const p = g.player;
      if (e.code === 'Space') { e.preventDefault(); p.togglePeek(); }
      else if (e.code === 'KeyR') p.reload();
      else if (e.code === 'KeyQ' || e.code === 'Digit1' || e.code === 'Digit2') p.switchWeapon();
      else if (e.code === 'KeyF' || e.code === 'Enter') p.fireDown();
      else if (e.code === 'Equal') p.setZoom(p.zoom + 0.5);
      else if (e.code === 'Minus') p.setZoom(p.zoom - 0.5);
    });
    window.addEventListener('keyup', (e) => {
      if ((e.code === 'KeyF' || e.code === 'Enter') && playing()) g.player.fireUp();
    });
  }
}

function starStr(n) {
  return [0, 1, 2].map((i) => (i < n ? '★' : '<span class="off">★</span>')).join('');
}
