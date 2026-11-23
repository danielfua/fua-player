const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict'),{spawnSync}=require('node:child_process');
const root=path.resolve(__dirname,'..');
const executable=[process.env.FUA_MPV,path.join(root,'.deps/mpv-extractor/mpv.com'),path.join(root,'app/fua-native/runtime/mpv.exe')].find(p=>p&&fs.existsSync(p));
assert(executable,'Set FUA_MPV to a local mpv executable');
fs.mkdirSync(path.join(root,'.deps'),{recursive:true});
const result=path.join(root,'.deps/title-artwork.result');
fs.rmSync(result,{force:true});
const run=spawnSync(executable,['--no-config','--vo=null','--ao=null','--idle=yes','--script=tests/title-artwork.lua','--msg-level=all=error'],{cwd:root,windowsHide:true,encoding:'utf8',timeout:15000});
assert.ifError(run.error);
assert.equal(run.status,0,run.stdout+run.stderr);
const report=fs.readFileSync(result,'utf8');
assert(report.startsWith('PASS:'),report);
console.log(report);

// Exercise the actual C# pixel output, including translucent and fully transparent edges.
const rasterDir=path.join(root,'.deps/title-artwork-raster');
const cache=path.join(rasterDir,'title-logo-cache');fs.mkdirSync(cache,{recursive:true});
const helper=path.join(rasterDir,'TitleArtwork.exe');
const compiler='C:/Windows/Microsoft.NET/Framework64/v4.0.30319/csc.exe';
const build=spawnSync(compiler,['/nologo','/target:exe','/reference:System.Drawing.dll','/reference:System.Web.Extensions.dll','/out:'+helper,path.join(root,'app/fua-native/TitleArtwork.cs')],{encoding:'utf8',windowsHide:true});
assert.ifError(build.error);assert.equal(build.status,0,build.stdout+build.stderr);
const source=path.join(cache,'transparent-edges.bgra'),pixels=Buffer.alloc(128*32*4);
for(let i=0;i<pixels.length;i+=4){pixels[i]=255;pixels[i+1]=180;pixels[i+2]=90;pixels[i+3]=(i/4)%3===0?0:128;}
fs.writeFileSync(source,pixels);
for(const [width,height] of [[128,32],[51,13],[256,64]]){
 const run=spawnSync(helper,['--resize',source,'128','32',String(width),String(height)],{env:{...process.env,FUA_DATA_DIR:rasterDir},encoding:'utf8',windowsHide:true});
 assert.ifError(run.error);assert.equal(run.status,0,run.stderr);
 const value=JSON.parse(run.stdout),raw=fs.readFileSync(value.file);assert.equal(raw.length,width*height*4);
 let translucent=0;
 for(let i=0;i<raw.length;i+=4){for(let c=0;c<3;c++)assert(raw[i+c]<=raw[i+3],'Every BGRA color must be premultiplied by alpha');if(raw[i+3]>0&&raw[i+3]<255)translucent++;}
 assert(translucent>0,'Test retains antialiased translucent pixels');
}
console.log('PASS: real bitmap transparency at native, reduced and enlarged sizes');
