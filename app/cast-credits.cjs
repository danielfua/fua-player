const fs=require('fs');
const config=require('./app-config.cjs');
const file=config.file('cast-credits.json'),pending=new Map();
let cache={};try{cache=JSON.parse(fs.readFileSync(file,'utf8'))}catch{}
function normalize(people){const byId=new Map();for(const p of people||[]){if(!Number.isSafeInteger(p.id)||p.id<=0)continue;const roles=(p.roles||[{character:p.character}]).map(r=>r.character).filter(Boolean);const old=byId.get(p.id);if(old){old.character=[...new Set([...old.character.split(' / ').filter(Boolean),...roles])].join(' / ');continue}byId.set(p.id,{id:p.id,name:p.name||'',character:[...new Set(roles)].join(' / '),photo:p.profile_path?'https://image.tmdb.org/t/p/w185'+p.profile_path:null})}return [...byId.values()]}
async function read(tmdb,route){if(cache[route]?.expires>Date.now())return cache[route].cast;if(pending.has(route))return pending.get(route);const job=(async()=>{const d=await tmdb(route);const cast=normalize([...(d.cast||[]),...(d.guest_stars||[])]);cache[route]={cast,expires:Date.now()+(cast.length?7*86400000:3600000)};try{let disk={};try{disk=JSON.parse(fs.readFileSync(file,'utf8'))}catch{}const temp=file+'.'+process.pid+'.tmp';fs.writeFileSync(temp,JSON.stringify({...disk,...cache}));fs.renameSync(temp,file)}catch{}return cast})();pending.set(route,job);try{return await job}finally{pending.delete(route)}}
async function get(tmdb,type,id,season=null,episode=null){
 if(!['tv','movie'].includes(type)||!Number.isSafeInteger(Number(id))||Number(id)<=0)return {cast:[],scope:'none'};
 const root=type+'/'+Number(id),levels=[];
 if(type==='tv'&&Number.isInteger(season)&&season>=0){if(Number.isInteger(episode)&&episode>0)levels.push(['episode',root+'/season/'+season+'/episode/'+episode+'/credits']);levels.push(['season',root+'/season/'+season+'/aggregate_credits'])}
 levels.push([type==='tv'?'series':'movie',root+(type==='tv'?'/aggregate_credits':'/credits')]);
 for(const [scope,route]of levels){try{const cast=await read(tmdb,route);if(cast.length)return {cast,scope,fallback:scope!==levels[0][0]}}catch{}}
 return {cast:[],scope:'none',fallback:false};
}
module.exports={get,normalize};
