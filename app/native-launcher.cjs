require('./app-config.cjs');
const http=require('http'),path=require('path'),{spawn}=require('child_process');const url='http://127.0.0.1:8780/';
function request(route,method='GET'){return new Promise((resolve,reject)=>{const r=http.request(url+route,{method,headers:{Origin:url.slice(0,-1)}},res=>{let body='';res.on('data',c=>body+=c);res.on('end',()=>{try{const d=JSON.parse(body);if(res.statusCode!==200)return reject(Error(d.error||'HTTP '+res.statusCode));resolve(d)}catch(e){reject(e)}})});r.setTimeout(22000,()=>r.destroy(Error('Tempo esgotado')));r.on('error',reject);r.end()})}
async function running(){try{return Array.isArray((await request('api/shelf/library')).titles)}catch{return false}}
const wait=ms=>new Promise(r=>setTimeout(r,ms));
(async()=>{let ready=await running();if(process.argv.includes('--check')){console.log(ready?'Fua Player respondeu corretamente.':'Biblioteca indisponivel.');process.exitCode=ready?0:1;return}if(!ready){const p=spawn(process.execPath,[path.join(__dirname,'native-server.cjs')],{cwd:__dirname,detached:true,stdio:'ignore',windowsHide:true});p.unref();for(let i=0;i<30&&!ready;i++){await wait(500);ready=await running()}}if(!ready)throw Error('Nao foi possivel iniciar o Fua Player.');await request('api/native/window','POST');console.log('Fua Player aberto em janela unica.')})().catch(e=>{console.error(e.message);process.exitCode=1});

