const {episodes}=require('../app/episode-list.cjs'),assert=require('assert'),crypto=require('crypto'),path=require('path');
const file=path.resolve('test.S00E02.mkv'),id=crypto.createHash('sha256').update(file).digest('hex').slice(0,20);
const request=async url=>({ok:true,json:async()=>url.endsWith('/library')?{titles:[{type:'tv',key:'abc',items:[{id,season:0,episode:2},{id:'next',season:0,episode:1},{id:'other-season',season:1,episode:1}]}]}:{episodes:[{episode:2,title:'Especial em português',still:'https://image.tmdb.org/t/p/w780/test.jpg'},{episode:1,title:'Primeiro episódio'}]}});
(async()=>{
 const v=await episodes(file,request);assert.equal(v.episodes.length,2);assert.equal(v.episodes[0].title,'E02 · Especial em português');assert.equal(v.episodes[0].current,true);assert.equal(v.episodes[1].current,false);
 const alternate=await episodes(file.toUpperCase(),request,()=>id);assert.equal(alternate.episodes.length,2);assert.equal(alternate.episodes[0].current,true);
 const {canonicalFile}=require('../app/episode-list.cjs');assert.equal(canonicalFile(file),canonicalFile(file.toUpperCase()));assert.equal(canonicalFile(file),canonicalFile(require('url').pathToFileURL(file).href));
 const missing=await episodes('missing.mkv',request,()=>null);assert.equal(missing.episodes.length,0);
 console.log('PASS: current season, season zero, translated names, case-insensitive paths, file URLs and missing files');
})().catch(e=>{console.error(e);process.exitCode=1});
