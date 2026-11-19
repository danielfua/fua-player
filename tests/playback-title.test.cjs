const fs=require('fs'),vm=require('vm'),crypto=require('crypto'),assert=require('assert');
const key=crypto.createHash('sha256').update('tv:carrie').digest('hex').slice(0,16);
const mockRequire=p=>p==='./app-config.cjs'?{file:()=>''}:p==='fs'?{readFileSync:()=>JSON.stringify({[key]:{metadata:{title:'Carrie: A Estranha'}}})}:require(p);
const c={require:mockRequire,module:{exports:{}},fetch:async()=>({ok:true,json:async()=>({episodes:[{episode:1,title:'Bem-vindos de volta'}]})}),AbortSignal,process,console};vm.createContext(c);vm.runInContext(fs.readFileSync('app/playback-title.cjs','utf8'),c);
c.module.exports.displayTitle('Carrie.S01E01.2160p.mkv').then(v=>{assert.equal(v.title,'Carrie: A Estranha · T01E01 · Bem-vindos de volta');console.log('PASS: Portuguese series and episode title');}).catch(e=>{console.error(e);process.exitCode=1});
