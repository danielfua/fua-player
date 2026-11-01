const fs=require('fs'),path=require('path');
const dataDir=path.resolve(process.env.FUA_DATA_DIR||path.join(__dirname,'data'));
process.env.FUA_DATA_DIR=dataDir;
fs.mkdirSync(dataDir,{recursive:true});fs.mkdirSync(path.join(dataDir,'sync-backups'),{recursive:true});
const file=name=>path.join(dataDir,name);
function settings(){try{const value=JSON.parse(fs.readFileSync(file('settings.json'),'utf8'));return {...value,folders:(value.folders||[]).filter(x=>x&&typeof x.path==='string'&&path.isAbsolute(x.path)&&['filmes','series'].includes(x.category))}}catch{return {folders:[]}}}
module.exports={dataDir,file,settings};
