const path=require('path'),{spawn}=require('child_process'),readline=require('readline');
let child=null,latest=null,opening=false,lastFailure='';
function start(){if(child)return;latest=null;lastFailure='';child=spawn(path.join(__dirname,'FuaPlayer.exe'),['--bridge','--library'],{stdio:['pipe','pipe','pipe'],windowsHide:false});child.on('error',e=>{lastFailure=e.message;child=null});child.on('exit',code=>{lastFailure='O reprodutor foi fechado ('+code+').';child=null;latest=null});readline.createInterface({input:child.stdout}).on('line',line=>{try{latest=JSON.parse(line)}catch{}});child.stderr.on('data',()=>{});child.stdin.on('error',()=>{});}
function command(value){start();child.stdin.write(JSON.stringify(value)+'\n')}
async function status(){if(!latest?.connected||Date.now()-latest.updated>5000)throw Error(lastFailure||'Reprodutor Fua indisponível');return latest}
const wait=ms=>new Promise(r=>setTimeout(r,ms));
async function open(file,position){if(opening)throw Error('Aguarde o vídeo anterior abrir');opening=true;try{latest=null;command({action:'open',file,position});for(let i=0;i<150;i++){await wait(200);if(lastFailure)throw Error(lastFailure);if(latest?.error)throw Error(latest.error);if(latest?.ready&&latest.filepath?.toLowerCase()===file.toLowerCase()){command({action:'front'});return latest}}throw Error('O reprodutor Fua não confirmou a abertura')}finally{opening=false}}
process.on('exit',()=>{try{child?.stdin.end()}catch{}});
async function show(){command({action:'library'});for(let i=0;i<100;i++){await wait(150);if(lastFailure)throw Error(lastFailure);if(latest?.error)throw Error(latest.error);if(latest?.connected&&latest.libraryReady)return latest}throw Error('A biblioteca integrada nao respondeu')}
module.exports={open,status,command,show};


