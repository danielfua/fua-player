const fs=require('fs'),path=require('path'),crypto=require('crypto');
const config=require('./app-config.cjs');
const input=process.argv[2]||'';let name=path.basename(input).replace(/\.[^.]+$/,'').replace(/^\[[^\]]+\]\s*/,'');
const m=name.match(/S(\d{1,2})E(\d{1,3})/i);let prefix=m?name.slice(0,m.index):name;
const year=prefix.match(/(?:^|[. (])((?:19|20)\d{2})(?=[. )]|$)/);let title=prefix.slice(0,year?year.index:undefined);
if(!m&&!year){const ep=name.match(/\s-\s(\d{1,3})(?:\s|$)/);if(ep)title=name.slice(0,ep.index)}
title=title.replace(/[._]+/g,' ').replace(/\s+/g,' ').replace(/[\s-]+$/,'').trim().replace(/^A Marvel Television Special Presentation /i,'');
const fold=s=>s.normalize('NFD').replace(/[\u0300-\u036f]/g,'').toLowerCase().replace(/[^a-z0-9]+/g,' ').trim();
try{const cache=JSON.parse(fs.readFileSync(config.file('library-metadata.json'),'utf8'));for(const type of m?['tv']:['movie','tv']){const key=crypto.createHash('sha256').update(type+':'+fold(title)).digest('hex').slice(0,16);if(process.argv[3]==='--cast'&&cache[key]){let extra={};try{extra=JSON.parse(fs.readFileSync(config.file('library-enrichment.json'),'utf8'))}catch{}console.log(JSON.stringify({cast:extra.titles?.[key]?.cast||[]}));process.exit(0)}const url=cache[key]?.metadata?.logo;if(url){const u=new URL(url);if(u.protocol==='https:'&&u.hostname==='image.tmdb.org'){console.log(JSON.stringify({url,key}));process.exit(0)}}}}catch{}
console.log('{}');