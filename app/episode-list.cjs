const path=require('path'),crypto=require('crypto');
function canonicalFile(file){let value=String(file);if(/^file:\/\//i.test(value))try{value=require('url').fileURLToPath(value)}catch{}return path.resolve(value.replace(/^\\\\\?\\/,'')).normalize('NFC').toLowerCase()}
function resolveEpisodeId(file){
 const media=require('./media.cjs'),canonical=canonicalFile(file);
 return media.index().find(item=>{const candidate=media.resolveFile(item.id);return candidate&&canonicalFile(candidate)===canonical})?.id||null;
}
async function episodes(file,request=fetch,resolveId=resolveEpisodeId){
 let id=crypto.createHash('sha256').update(path.resolve(file)).digest('hex').slice(0,20);
 const response=await request('http://127.0.0.1:8780/api/shelf/library',{signal:AbortSignal.timeout(20000)});if(!response.ok)throw Error('Biblioteca indisponível');
 const library=await response.json();let group=library.titles.find(g=>g.type==='tv'&&g.items.some(i=>i.id===id));
 if(!group){id=resolveId(file);group=library.titles.find(g=>g.type==='tv'&&g.items.some(i=>i.id===id))}
 if(!group)return {episodes:[]};
 const currentSeason=group.items.find(i=>i.id===id).season??1;
 const items=group.items.filter(i=>(i.season??1)===currentSeason);
 const seasons=[currentSeason],metadata=new Map();
 await Promise.all(seasons.map(async season=>{try{const r=await request('http://127.0.0.1:8780/api/shelf/'+group.key+'/season/'+season,{signal:AbortSignal.timeout(10000)});if(r.ok)metadata.set(season,(await r.json()).episodes||[])}catch{}}));
 return {episodes:items.map(item=>{const season=item.season??1,extra=metadata.get(season)?.find(e=>e.episode===item.episode);return {id:item.id,current:item.id===id,title:'E'+String(item.episode??0).padStart(2,'0')+' · '+(extra?.title||'Episódio '+(item.episode??'')),photo:extra?.still||null,position:item.position||0,watched:!!item.watched}})};
}
async function thumbnailImages(data,request=fetch){
 const fs=require('fs'),config=require('./app-config.cjs'),directory=config.file('episode-photo-cache');fs.mkdirSync(directory,{recursive:true});
 let cursor=0;
 async function worker(){while(cursor<data.episodes.length){const item=data.episodes[cursor++];if(!/^[a-f0-9]{20}$/.test(item.id)||!item.photo)continue;try{
  const imageFile=path.join(directory,item.id+'-source.jpg');
  if(!fs.existsSync(imageFile)||fs.statSync(imageFile).size===0){const url=new URL(item.photo);if(url.protocol!=='https:'||url.hostname!=='image.tmdb.org')continue;
   const r=await request(url,{signal:AbortSignal.timeout(15000)});if(!r.ok)continue;const bytes=Buffer.from(await r.arrayBuffer());if(!bytes.length)continue;
   const temporary=imageFile+'.'+process.pid+'.tmp';fs.writeFileSync(temporary,bytes);fs.renameSync(temporary,imageFile);
  }
  item.imageFile=imageFile;
 }catch{}}}
 await Promise.all(Array.from({length:Math.min(4,data.episodes.length)},worker));return data;
}
if(require.main===module)episodes(process.argv[2]||'').then(data=>process.argv[3]==='--images'?thumbnailImages(data):data).then(v=>console.log(JSON.stringify(v))).catch(()=>console.log('{"episodes":[]}'));
module.exports={episodes,canonicalFile};
