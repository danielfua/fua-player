const fs=require('fs'),path=require('path'),crypto=require('crypto');
const config=require('./app-config.cjs');
const fold=s=>s.normalize('NFD').replace(/[\u0300-\u036f]/g,'').toLowerCase().replace(/[^a-z0-9]+/g,' ').trim();
async function displayTitle(file){
 const name=path.basename(file).replace(/\.[^.]+$/,'').replace(/^\[[^\]]+\]\s*/,'');
 const episode=name.match(/S(\d{1,2})E(\d{1,3})/i),prefix=episode?name.slice(0,episode.index):name;
 const year=prefix.match(/(?:^|[. (])((?:19|20)\d{2})(?=[. )]|$)/);
 const localTitle=prefix.slice(0,year?year.index:undefined).replace(/[._]+/g,' ').replace(/\s+/g,' ').replace(/[\s-]+$/,'').trim();
 let cache={};try{cache=JSON.parse(fs.readFileSync(config.file('library-metadata.json'),'utf8'))}catch{}
 for(const type of episode?['tv']:['movie','tv']){
  const key=crypto.createHash('sha256').update(type+':'+fold(localTitle)).digest('hex').slice(0,16),meta=cache[key]?.metadata;
  if(!meta)continue;
  if(!episode)return {title:meta.title||localTitle};
  const season=Number(episode[1]),number=Number(episode[2]);let episodeTitle='';
  try{const r=await fetch('http://127.0.0.1:8780/api/shelf/'+key+'/season/'+season,{signal:AbortSignal.timeout(5000)});if(r.ok){const data=await r.json();episodeTitle=data.episodes?.find(e=>e.episode===number)?.title||''}}catch{}
  return {title:(meta.title||localTitle)+' · T'+String(season).padStart(2,'0')+'E'+String(number).padStart(2,'0')+(episodeTitle?' · '+episodeTitle:'')};
 }
 return {title:localTitle||name};
}
if(require.main===module)displayTitle(process.argv[2]||'').then(value=>console.log(JSON.stringify(value))).catch(()=>console.log('{}'));
module.exports={displayTitle};
