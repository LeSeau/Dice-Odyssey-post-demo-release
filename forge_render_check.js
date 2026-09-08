// Render smoke test for the Encounter Forge. forge_lint.js validates DATA; this one
// actually DRAWS every enemy sheet and the roster, which is the failure mode that
// blanked the page once (unguarded table lookups throw mid-render, node --check is blind).
const fs=require('fs'), vm=require('vm');
const html=fs.readFileSync(process.argv[2],'utf8');
const scripts=[...html.matchAll(/<script>([\s\S]*?)<\/script>/g)].map(m=>m[1]);
function stub(name){const f=function(){return stub(name+'()');};
  return new Proxy(f,{get(t,p){if(p===Symbol.toPrimitive)return()=>0;if(p===Symbol.iterator)return function*(){};
    if(p==='toString')return()=>name;if(p==='length')return 0;return stub(name+'.'+String(p));},
    set(){return true;},has(){return true;},apply(){return stub(name+'()');},construct(){return stub('new '+name);}});}
const ctx=vm.createContext({console:{log(){},warn(){},error(){}},document:stub('document'),window:stub('window'),
  localStorage:{getItem:()=>null,setItem(){},removeItem(){}},requestAnimationFrame:()=>0,
  matchMedia:()=>({matches:false,addEventListener(){}}),setTimeout:()=>0,clearTimeout:()=>{},setInterval:()=>0,
  navigator:stub('navigator'),location:stub('location'),
  Math,JSON,Object,Array,String,Number,Boolean,Set,Map,RegExp,Date,isNaN,parseFloat,parseInt,Symbol,Error});
scripts.forEach(s=>{try{vm.runInContext(s,ctx,{timeout:20000});}catch(e){}});
const g=e=>{try{return vm.runInContext(e,ctx);}catch(err){return undefined;}};
let fail=0,pass=0;
const ENEMIES=g('ENEMIES'), GROUPS=g('GROUPS');
if(!ENEMIES||!GROUPS){console.log('FATAL: globals missing');process.exit(1);}
// roster
try{const h=vm.runInContext('rosterHTML("")',ctx);
    if(typeof h!=='string'||h.length<500)throw new Error('roster HTML suspiciously short: '+(h&&h.length));
    for(const id of ['b_odd','b_even','dp'])
      if(!vm.runInContext('rosterHTML("")',ctx).includes(id))console.log('  note: '+id+' not in roster markup');
    pass++;}catch(e){console.log('  FAIL rosterHTML: '+e.message);fail++;}
// every enemy sheet
for(const d of ENEMIES){
  try{ctx.__id=d.id; const h=vm.runInContext('renderSheet(__id)||""',ctx);
      pass++;}catch(e){console.log('  FAIL renderSheet("'+d.id+'"): '+e.message.split('\n')[0]);fail++;}
}
// every enemy's 12-turn pattern strip (runs the real kit logic)
for(const d of ENEMIES){
  if(typeof d.ai!=='function'){continue;}
  try{const st={t:1,ft:0,rng:Math.random,last:null,lastCount:0,hpFrac:1,flags:{},cycleIdx:0};
      for(let i=1;i<=12;i++){st.t=i;st.ft=i-1;st.hpFrac=Math.max(0.1,1-i*0.08);const m=d.ai(st);
        if(!m||typeof m!=='object')throw new Error('turn '+i+' returned '+m);}
      pass++;}catch(e){console.log('  FAIL ai("'+d.id+'"): '+e.message.split('\n')[0]);fail++;}
}
console.log(fail?('\nRENDER FAILED — '+pass+' ok, '+fail+' failed'):('\nRENDER CLEAN — '+pass+' checks passed'));
process.exit(fail?1:0);
