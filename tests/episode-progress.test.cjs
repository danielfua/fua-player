const fs=require('fs'),vm=require('vm'),assert=require('assert');
const source=fs.readFileSync('app/library.js','utf8');
function el(tag,cls,text){return {tag,className:cls,text,children:[],append(...n){this.children.push(...n)},replaceChildren(){this.children=[]},setAttribute(){}}}
let plays=0;
const context={g:{key:'test',type:'tv',items:[{id:'episode',episode:1,season:0,name:'special.mkv',position:1000}]},season:0,list:el('div'),el,button:(text,cls,fn)=>Object.assign(el('button',cls,text),{onclick:fn}),play:async()=>{plays++},episodeAction:i=>'Continue '+i.position,label:i=>'Resume '+i.position,bundledDetails:{files:{}},refreshOpenEpisodes:null};
vm.createContext(context);
const start=source.indexOf('const seasonInfo=new Map();'),end=source.indexOf(';d.hidden=false;',start);
vm.runInContext(source.slice(start,end)+';episodes(false)',context);
(async()=>{
 let row=context.list.children[0];assert.equal(row.tag,'article');assert.equal(row.onclick,undefined);assert.equal(row.children[1].onclick,undefined);
 await row.children[0].onclick();await row.children[2].onclick();assert.equal(plays,2);
 context.refreshOpenEpisodes({...context.g,items:[{...context.g.items[0],position:9000}]});
 row=context.list.children[0];assert.equal(row.children[2].text,'Continue 9000');assert.equal(row.children[1].children[1].text,'Resume 9000');
 const media=fs.readFileSync('app/media.cjs','utf8');let writes=0;
 const c={require:p=>p==='./app-config.cjs'?{}:p==='./fua-native/bridge.cjs'?{}:require(p),module:{exports:{}},setInterval:()=>({unref(){}}),setTimeout,console};vm.createContext(c);
 vm.runInContext(media+`;active={entry:{file:path.resolve('C:/test.mkv')},started:Date.now(),lastPosition:0,lastOwnWrite:Date.now()};status=async()=>({filepath:'C:/test.mkv',position:500,duration:100000});readResume=()=>null;writeResume=()=>{writes++};`,Object.assign(c,{writes:0}));
 await c.module.exports.flush();assert.equal(c.writes,1,'explicit return flush saves even during first five seconds');
 console.log('PASS: only thumbnail/button activate; season zero and refreshed progress preserved; immediate flush saves early progress.');
})().catch(e=>{console.error(e);process.exitCode=1});
