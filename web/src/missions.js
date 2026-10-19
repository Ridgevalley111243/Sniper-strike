// Campaign definitions, weapon stats, upgrades and persistent progress.

export const WEAPONS = {
  rifle: {
    key: 'rifle', name: 'AR-7 CARBINE', auto: true, dmg: 34, rate: 10, mag: 30, reload: 1.9,
    spread: 0.0035, recoil: 0.009, headMul: 2.6, limbMul: 0.7, adsFov: 52,
  },
  sniper: {
    key: 'sniper', name: 'HAWK .338', auto: false, dmg: 150, rate: 0.85, mag: 5, reload: 2.6,
    spread: 0, hipSpread: 0.05, recoil: 0.06, headMul: 3, limbMul: 0.75, zoomMin: 2, zoomMax: 6,
  },
};

export const MISSIONS = [
  {
    id: 1, name: 'Downtown Breach', time: 'day', vantage: 'street', type: 'waves',
    brief: 'Hostiles have seized Main Street. Hold the barricade and push back three assault waves.',
    range: [22, 62], loadout: 'rifle', reward: 300, barrels: 0.35,
    waves: [['rifle', 'rifle', 'rifle'], ['rifle', 'rifle', 'rifle', 'rifle'], ['rifle', 'heavy', 'rifle', 'rifle', 'rifle']],
    tutorial: true,
  },
  {
    id: 2, name: 'High Value', time: 'day', vantage: 'roof', type: 'assassinate',
    brief: 'A militia commander is walking to a meeting under guard. Take him out before he reaches the building. One shot alerts everyone.',
    range: [75, 140], loadout: 'sniper', reward: 450, vipSide: -1,
    guards: ['guard', 'guard'], sentries: ['rifle', 'rifle', 'rifle'],
    waves: [['rifle', 'rifle', 'sniper']],
  },
  {
    id: 3, name: 'Sunset Siege', time: 'sunset', vantage: 'street', type: 'waves',
    brief: 'The enemy is regrouping at dusk with heavy support and a marksman. Watch for red lasers - get into cover!',
    range: [24, 95], loadout: 'rifle', reward: 600, barrels: 0.35,
    waves: [['rifle', 'rifle', 'rifle', 'sniper'], ['rifle', 'heavy', 'rifle', 'rifle'], ['heavy', 'rifle', 'sniper', 'rifle', 'rifle']],
  },
  {
    id: 4, name: 'Rooftop Hunt', time: 'morning', vantage: 'roof', type: 'waves',
    brief: 'Enemy spotters control the rooftops at dawn. Clear every roof and street position from long range.',
    range: [60, 170], loadout: 'sniper', reward: 700, roofEnemies: true, barrels: 0.25,
    waves: [['rifle', 'sniper', 'rifle'], ['sniper', 'rifle', 'rifle', 'heavy'], ['sniper', 'sniper', 'rifle', 'heavy', 'rifle']],
  },
  {
    id: 5, name: 'Night Raid', time: 'night', vantage: 'street', type: 'waves',
    brief: 'They attack under cover of darkness. Muzzle flashes give them away. Survive four waves.',
    range: [20, 85], loadout: 'rifle', reward: 850, barrels: 0.4,
    waves: [['rifle', 'rifle', 'rifle', 'rifle'], ['rifle', 'heavy', 'rifle', 'sniper'], ['heavy', 'rifle', 'rifle', 'rifle', 'rifle'], ['heavy', 'heavy', 'sniper', 'rifle', 'rifle', 'rifle']],
  },
  {
    id: 6, name: 'Final Strike', time: 'sunset', vantage: 'roof', type: 'assassinate',
    brief: 'The warlord himself is on the move with his elite guard. Eliminate him, then wipe out his reinforcements.',
    range: [60, 165], loadout: 'sniper', reward: 1300, vipSide: 1, roofEnemies: true, hpMul: 1.15,
    guards: ['guard', 'guard', 'heavy'], sentries: ['rifle', 'sniper', 'rifle', 'rifle'],
    waves: [['rifle', 'heavy', 'rifle', 'sniper'], ['heavy', 'rifle', 'rifle', 'sniper', 'rifle']],
  },
];

export const UPGRADES = [
  { key: 'rifleDmg', name: 'Rifle Damage', desc: '+12% carbine damage', cost: [200, 400, 700, 1100, 1600] },
  { key: 'sniperDmg', name: 'Sniper Damage', desc: '+15% sniper damage', cost: [250, 500, 850, 1300, 1900] },
  { key: 'zoom', name: 'Scope Zoom', desc: '+1x max zoom', cost: [300, 600, 1000, 1500] },
  { key: 'stability', name: 'Stability', desc: '-15% scope sway', cost: [200, 450, 800, 1200] },
  { key: 'reload', name: 'Fast Hands', desc: '-10% reload time', cost: [250, 500, 900, 1400] },
  { key: 'armor', name: 'Body Armor', desc: '+20 max health', cost: [300, 600, 1000, 1500, 2100] },
];

const KEY = 'sniperstrike.save.v1';

function defaults() {
  return {
    coins: 0, unlocked: 1, stars: {}, best: {},
    upgrades: Object.fromEntries(UPGRADES.map((u) => [u.key, 0])),
    settings: { quality: 'auto', sens: 1, volume: 0.8, fps: false },
  };
}

export function loadSave() {
  const d = defaults();
  try {
    const raw = localStorage.getItem(KEY);
    if (raw) {
      const s = JSON.parse(raw);
      return { ...d, ...s, upgrades: { ...d.upgrades, ...s.upgrades }, settings: { ...d.settings, ...s.settings } };
    }
  } catch (e) { /* storage unavailable */ }
  return d;
}

export function writeSave(s) {
  try { localStorage.setItem(KEY, JSON.stringify(s)); } catch (e) { /* ignore */ }
}

export function resetSave() {
  try { localStorage.removeItem(KEY); } catch (e) { /* ignore */ }
  return defaults();
}
