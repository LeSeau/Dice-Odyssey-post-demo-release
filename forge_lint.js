// Encounter Forge linter — rebuilt 2026-09-06 (the 09-01 original died with its
// session scratchpad). Guards the failure mode that blanked this page once: the
// render path does unguarded table lookups like RAMPTYPES[d.ramp.type].c, so ONE
// invented enum string throws while drawing and the whole document goes white.
// node --check cannot see it, and neither can running ai().
//
// The roster is built across SEVERAL script blocks (base ENEMIES, then the bench,
// act-2 natives and idea-dump bodies each ENEMIES.push into it), so this runs every
// block in order inside one stubbed VM context and reads the finished globals —
// slicing a single block gives a partial roster and floods you with false negatives.
//
//   usage: node lint_forge.js forge_new.html
const fs = require('fs');
const vm = require('vm');
const file = process.argv[2] || 'forge_new.html';
const html = fs.readFileSync(file, 'utf8');

let fail = 0, pass = 0;
const bad = (m) => { console.log('  FAIL ' + m); fail++; };
const ok = () => pass++;

const scripts = [...html.matchAll(/<script>([\s\S]*?)<\/script>/g)].map(m => m[1]);
if (!scripts.length) { console.log('FATAL: no <script> blocks'); process.exit(1); }

// --- 1. syntax of every script block
scripts.forEach((s, i) => {
  try { new vm.Script(s); ok(); }
  catch (e) { bad('script block ' + i + ' does not parse: ' + e.message); }
});

// --- 2. execute every block in one context, with a permissive DOM stub.
// Render/init code will throw on the stub; that is expected and only reported.
function stub(name) {
  const f = function () { return stub(name + '()'); };
  return new Proxy(f, {
    get(t, p) {
      if (p === Symbol.toPrimitive) return () => 0;
      if (p === Symbol.iterator) return function* () {};
      if (p === 'toString') return () => name;
      if (p === 'length') return 0;
      if (p === 'style' || p === 'dataset' || p === 'classList') return stub(name + '.' + String(p));
      return stub(name + '.' + String(p));
    },
    set() { return true; },
    has() { return true; },
    apply() { return stub(name + '()'); },
    construct() { return stub('new ' + name); }
  });
}
const ctx = vm.createContext({
  console: { log() {}, warn() {}, error() {} },
  document: stub('document'), window: stub('window'),
  localStorage: { getItem: () => null, setItem() {}, removeItem() {} },
  requestAnimationFrame: () => 0, matchMedia: () => ({ matches: false, addEventListener() {} }),
  setTimeout: () => 0, clearTimeout: () => {}, setInterval: () => 0,
  navigator: stub('navigator'), location: stub('location'),
  Math, JSON, Object, Array, String, Number, Boolean, Set, Map, RegExp, Date, isNaN, parseFloat, parseInt, Symbol, Error
});
const threw = [];
scripts.forEach((s, i) => {
  try { vm.runInContext(s, ctx, { timeout: 20000 }); }
  catch (e) { threw.push(i + ': ' + e.message.split('\n')[0]); }
});

function grab(expr) { try { return vm.runInContext(expr, ctx); } catch (e) { return undefined; } }
const D = {
  BEATS: grab('BEATS'), RAMPTYPES: grab('RAMPTYPES'), ENEMIES: grab('ENEMIES'),
  ENCOUNTERS: grab('ENCOUNTERS'), STATUSES: grab('STATUSES'), VERDICTS: grab('VERDICTS'),
  GAPS: grab('GAPS'), GROUPS: grab('GROUPS')
};
for (const k of ['BEATS', 'RAMPTYPES', 'ENEMIES', 'ENCOUNTERS', 'VERDICTS', 'GROUPS']) {
  if (!D[k]) bad('global ' + k + ' did not survive execution — blocks that threw: ' + threw.join(' | ')); else ok();
}
if (!D.ENEMIES || !D.ENCOUNTERS || !D.GROUPS) {
  console.log('\nLINT FAILED — could not build the roster'); process.exit(1);
}
console.log('  roster built: ' + D.ENEMIES.length + ' enemies, ' + D.ENCOUNTERS.length +
            ' encounters, ' + D.GROUPS.length + ' groups' +
            (threw.length ? ' (blocks throwing on the DOM stub: ' + threw.length + ', expected)' : ''));

const beatKeys = new Set(Object.keys(D.BEATS));
const rampKeys = new Set(Object.keys(D.RAMPTYPES));
const statusIds = new Set((D.STATUSES || []).map(s => s.id));
const enemyIds = new Set(D.ENEMIES.map(e => e.id));
// The page's real rx vocabulary, read off the data rather than guessed.
const rxStates = new Set(['shipped', 'verdict', 'idea', 'pending', 'dial', 'flag', 'plumb', 'skipped', 'none']);

// Baseline diff: if a live copy is passed as argv[3], assert this build introduces
// no enum-ish string the live page did not already carry. That is the check that
// actually protects against the blank-page bug, because the renderer's lookups are
// unguarded and a brand-new key is exactly what throws.
const baseFile = process.argv[3];
if (baseFile && fs.existsSync(baseFile)) {
  const base = fs.readFileSync(baseFile, 'utf8');
  const harvest = (src, re) => new Set([...src.matchAll(re)].map(m => m[1]));
  const checks = [
    ['rx state', /\bs:"([a-z]+)"\}/g],
    ['beat', /\bbeat:"([A-Z_]+)"/g],
    ['ramp.type', /ramp:\{type:"([a-z]+)"/g]
  ];
  for (const [label, re] of checks) {
    const now = harvest(html, re), was = harvest(base, re);
    const added = [...now].filter(v => !was.has(v));
    if (added.length) bad('new ' + label + ' value(s) not present in the live page: ' + added.join(', ') +
                         ' — the renderer looks these up unguarded');
    else ok();
  }
}

// --- 3. per-enemy invariants (the enum checks that blank the page)
for (const e of D.ENEMIES) {
  if (!e.ramp || !rampKeys.has(e.ramp.type)) bad(e.id + ': ramp.type "' + (e.ramp && e.ramp.type) + '" is not a RAMPTYPES key'); else ok();
  if (!e.hp || !(e.defV in e.hp)) bad(e.id + ': defV "' + e.defV + '" has no hp entry'); else ok();
  for (const m of (e.moves || [])) { if (!beatKeys.has(m.beat)) bad(e.id + ' move "' + m.m + '": beat "' + m.beat + '" not a BEATS key'); else ok(); }
  for (const m of (e.tpl || [])) { if (m.beat && !beatKeys.has(m.beat)) bad(e.id + ' tpl "' + m.label + '": beat "' + m.beat + '" not a BEATS key'); else ok(); }
  for (const r of (e.rx || [])) { if (!rxStates.has(r.s)) bad(e.id + ': rx state "' + r.s + '" unknown'); else ok(); }
  for (const s of (e.carries || []).concat(e.inflicts || [])) {
    if (statusIds.size && !statusIds.has(s)) bad(e.id + ': status id "' + s + '" not in STATUSES'); else ok();
  }
}

// --- 4. every ai() runs 14 turns at several HP fractions and returns known beats
let seed = 7;
const rng = () => (seed = (seed * 1103515245 + 12345) & 0x7fffffff) / 0x7fffffff;
for (const e of D.ENEMIES) {
  if (typeof e.ai !== 'function') continue;
  for (const hpFrac of [1.0, 0.75, 0.5, 0.3]) {
    const st = { t: 1, ft: 0, rng, last: '', lastCount: 0, hpFrac, flags: {}, cycleIdx: 0 };
    try {
      for (let turn = 1; turn <= 14; turn++) {
        st.t = turn; st.ft = turn - 1;
        const m = e.ai(st, { act2: false });
        if (!m) { bad(e.id + ': ai() returned nothing on turn ' + turn); break; }
        if (!beatKeys.has(m.beat)) { bad(e.id + ': ai() returned beat "' + m.beat + '" on turn ' + turn); break; }
        if (m.key === st.last) st.lastCount++; else { st.last = m.key; st.lastCount = 1; }
      }
      ok();
    } catch (err) { bad(e.id + ': ai() threw at hpFrac ' + hpFrac + ': ' + err.message); }
  }
}

// --- 5. encounters resolve to real enemies and real hp variants
for (const enc of D.ENCOUNTERS) {
  for (const l of enc.lineup) {
    if (!enemyIds.has(l.e)) { bad('encounter ' + enc.id + ': unknown enemy "' + l.e + '"'); continue; }
    const en = D.ENEMIES.find(x => x.id === l.e);
    if (l.v && !(l.v in en.hp)) bad('encounter ' + enc.id + ': "' + l.e + '" has no hp variant "' + l.v + '"'); else ok();
  }
}

// --- 6. roster grouping is total and has no ghosts
const grouped = new Set();
for (const g of D.GROUPS) for (const id of g[1]) grouped.add(id);
for (const e of D.ENEMIES) { if (!grouped.has(e.id)) bad('enemy "' + e.id + '" is in no roster group — invisible in the Bestiary'); else ok(); }
for (const g of D.GROUPS) for (const id of g[1]) { if (!enemyIds.has(id)) bad('group "' + g[0] + '" lists unknown enemy "' + id + '"'); else ok(); }

// --- 7. behavioural spot-checks on the three kits edited 2026-09-06
function seq(id, turns, act2) {
  const e = D.ENEMIES.find(x => x.id === id);
  const st = { t: 1, ft: 0, rng, last: '', lastCount: 0, hpFrac: 1, flags: {}, cycleIdx: 0 };
  const out = [];
  for (let i = 1; i <= turns; i++) {
    st.t = i; st.ft = i - 1;
    const m = e.ai(st, { act2: !!act2 });
    out.push(m);
    if (m.key === st.last) st.lastCount++; else { st.last = m.key; st.lastCount = 1; }
  }
  return out;
}
const med = seq('medusa', 12);
if (med[2].key === 'gaze' && med[6].key === 'gaze' && med[10].key === 'gaze') ok();
else bad('medusa: Gaze not on turns 3/7/11 — got ' + med.map(m => m.key).join(','));
if (med[3].key === 'g' && med[7].key === 'g') ok(); else bad('medusa: guard not on turns 4/8');
if (med[2].dmg === 22) ok(); else bad('medusa: gaze damage is ' + med[2].dmg);
if (med.filter(m => m.key === 'gaze').length === 3) ok(); else bad('medusa: 12 turns produced ' + med.filter(m => m.key === 'gaze').length + ' gazes, expected 3');

const hound = D.ENEMIES.find(x => x.id === 'hound');
const hst = { t: 1, ft: 0, rng, last: '', lastCount: 0, hpFrac: 1, flags: {}, cycleIdx: 0 };
const hnd = [];
for (let i = 1; i <= 10; i++) {
  hst.t = i; hst.ft = i - 1;
  if (i >= 4) hst.hpFrac = 0.4;
  const m = hound.ai(hst);
  hnd.push(m);
  if (m.key === hst.last) hst.lastCount++; else { hst.last = m.key; hst.lastCount = 1; }
}
// Molten Roar was cut on 2026-09-06 (second rejection). Assert it stays GONE:
// if a roar beat ever reappears here without Julien asking, this turns red.
const roars = hnd.filter(m => m.key === 'roar').length;
if (roars === 0) ok(); else bad('hound: a roar beat fired ' + roars + ' times — Molten Roar was cut twice and must stay out');

const lev = seq('levi', 14);
const slam = lev.find(m => m.key === 'i');
const tide = lev.find(m => m.key === 'w');
if (slam && slam.dmg === 24) ok(); else bad('levi: Abyssal Slam damage is ' + (slam && slam.dmg));
if (tide && tide.dmg === 11) ok(); else bad('levi: Crushing Tide damage is ' + (tide && tide.dmg));
if (lev[2].key === 'g' && lev[6].key === 'g') ok(); else bad('levi: guard not on turns 3/7');

// --- 8. VERDICTS is append-only (checkbox state is index-keyed in localStorage)
if (D.VERDICTS.length >= 12) ok(); else bad('VERDICTS shrank — never remove or reorder, only append');

// --- 9. the two fights moved to act 2 are flagged
for (const id of ['t1_mimic', 't2_quartermaster']) {
  const enc = D.ENCOUNTERS.find(e => e.id === id);
  if (!enc) { bad('encounter "' + id + '" missing'); continue; }
  if (enc.act2 === true) ok(); else bad('encounter "' + id + '" is not flagged act2:true');
}

console.log('\n' + (fail === 0 ? 'LINT CLEAN' : 'LINT FAILED') + ' — ' + pass + ' checks passed, ' + fail + ' failed');
process.exit(fail ? 1 : 0);
