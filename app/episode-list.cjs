const path=require('path'),crypto=require('crypto');
async function episodes(file,request=fetch){
 const id=crypto.createHash('sha256').update(path.resolve(file)).digest('hex').slice(0,20);
 const response=await request('http://127.0.0.1:8780/api/shelf/library',{signal:AbortSignal.timeout(10000)});if(!response.ok)throw Error('Biblioteca indisponível');
 const library=await response.json(),group=library.titles.find(g=>g.type==='tv'&&g.items.some(i=>i.id===id));if(!group)return {episodes:[]};
 const currentSeason=group.items.find(i=>i.id===id).season??1;
 const items=group.items.filter(i=>(i.season??1)===currentSeason);
 const seasons=[currentSeason],metadata=new Map();
 await Promise.all(seasons.map(async season=>{try{const r=await request('http://127.0.0.1:8780/api/shelf/'+group.key+'/season/'+season,{signal:AbortSignal.timeout(10000)});if(r.ok)metadata.set(season,(await r.json()).episodes||[])}catch{}}));
 return {episodes:items.map(item=>{const season=item.season??1,extra=metadata.get(season)?.find(e=>e.episode===item.episode);return {id:item.id,current:item.id===id,title:'E'+String(item.episode??0).padStart(2,'0')+' · '+(extra?.title||'Episódio '+(item.episode??'')),photo:extra?.still||null,position:item.position||0,watched:!!item.watched}})};
}
if(require.main===module)episodes(process.argv[2]||'').then(v=>console.log(JSON.stringify(v))).catch(()=>console.log('{"episodes":[]}'));
module.exports={episodes};
