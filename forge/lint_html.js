// Data-integrity linter that runs against the ASSEMBLED forge HTML, not the part files.
//
// Same job as lint_forge.js: the page does RAMPTYPES[d.ramp.type].c unguarded while drawing
// the roster, so one enum string that is not in the table blanks the whole page, and neither
// `node --check` nor running the ai() functions can see it. This variant exists because the
// part-file pipeline lives in a different worktree.
//
// Getting the HTML: read the live artifact with the Artifact tool (action: "read", url:
// https://claude.ai/code/artifact/11c48352-224d-42dd-b91e-8893841c02f9). The page is ~2.2MB so
// the tool saves the whole thing to a local file and prints the path - lint THAT path. Always
// lint the live copy rather than a local part-file build: on 2026-09-01 a stale local copy was
// a full edit pass behind the artifact and silently patched the wrong numbers.
//
// Negative control (re-run it if you change this file): swap any ramp type for a string that is
// not in RAMPTYPES and the eval must fail with "Cannot read properties of undefined (reading
// 'c')" - the exact blank-page crash. A clean eval means the page genuinely renders.
//
// Run:  node lint_html.js <path-to-forge.html>
const fs = require('fs');
const html = fs.readFileSync(process.argv[2], 'utf8');

// Concatenate every inline script except the frame runtime, then evaluate it with a DOM stub
// so the data declarations are reachable. Anything that touches the DOM at load is trapped.
const re = /<script(?![^>]*\ssrc=)[^>]*>([\s\S]*?)<\/script>/g;
let m, code = '';
while ((m = re.exec(html)) !== null) {
  const body = m[1];
  if (body.includes('__FRAME_PREAMBLE') || body.includes('frame-runtime')) continue;
  code += body + '\n;\n';
}

const noop = () => {};
const el = new Proxy(function () {}, {
  get: (t, k) => (k === Symbol.toPrimitive || k === 'toString' || k === 'valueOf' ? () => ''
    : k === Symbol.iterator ? function* () {}
    : k === 'style' || k === 'classList' || k === 'dataset' ? el
    : k === 'children' || k === 'childNodes' ? []
    : k === 'length' ? 0 : el),
  set: () => true,
  apply: () => el,
});
const doc = {
  getElementById: () => el, querySelector: () => el, querySelectorAll: () => [],
  createElement: () => el, addEventListener: noop, body: el, documentElement: el,
  createDocumentFragment: () => el,
};
const sandbox = {
  document: doc, window: null, addEventListener: noop, requestAnimationFrame: noop,
  localStorage: { getItem: () => null, setItem: noop, removeItem: noop },
  matchMedia: () => ({ matches: false, addEventListener: noop, addListener: noop }),
  console, Math, JSON, Date, setTimeout: noop, clearTimeout: noop, location: { hash: '' },
};
sandbox.window = sandbox;
sandbox.globalThis = sandbox;

const fn = new Function('window', 'document', 'globalThis', 'sandbox', `
  with (sandbox) {
    ${code}
    return { ENEMIES, ENCOUNTERS, STATUSES, RAMPTYPES:
      (typeof RAMPTYPES !== 'undefined' ? RAMPTYPES : null) };
  }
`);

let data;
try {
  data = fn(sandbox, doc, sandbox, sandbox);
} catch (e) {
  console.log('EVAL FAILED: ' + e.message);
  process.exit(1);
}

const { ENEMIES, ENCOUNTERS, STATUSES, RAMPTYPES } = data;
const fails = [];
const bad = (s) => fails.push(s);

const statusIds = new Set(STATUSES.map((s) => s.id));
const enemyIds = new Set(ENEMIES.map((d) => d.id));

for (const d of ENEMIES) {
  // the exact crash from the blank-page incident
  if (d.ramp && d.ramp.type && RAMPTYPES && !RAMPTYPES[d.ramp.type]) {
    bad(`${d.id}: ramp.type "${d.ramp.type}" is not in RAMPTYPES`);
  }
  for (const id of d.carries || []) {
    if (!statusIds.has(id)) bad(`${d.id}: carries unknown status "${id}"`);
  }
  for (const id of d.inflicts || []) {
    if (!statusIds.has(id)) bad(`${d.id}: inflicts unknown status "${id}"`);
  }
  if (d.defV && d.hp && d.hp[d.defV] === undefined) {
    bad(`${d.id}: defV "${d.defV}" has no hp entry (hp keys: ${Object.keys(d.hp)})`);
  }
}

for (const enc of ENCOUNTERS) {
  for (const slot of enc.lineup || []) {
    if (!enemyIds.has(slot.e)) bad(`encounter ${enc.id}: unknown enemy "${slot.e}"`);
    else {
      const d = ENEMIES.find((x) => x.id === slot.e);
      if (slot.v && d.hp && d.hp[slot.v] === undefined) {
        bad(`encounter ${enc.id}: ${slot.e} has no hp variant "${slot.v}"`);
      }
    }
  }
}

console.log(`enemies ${ENEMIES.length} | encounters ${ENCOUNTERS.length} | statuses ${STATUSES.length}`);
for (const f of fails) console.log('  FAIL ' + f);
console.log(fails.length ? `\n${fails.length} FAILURE(S)` : '\n0 failures');
process.exit(fails.length ? 1 : 0);
