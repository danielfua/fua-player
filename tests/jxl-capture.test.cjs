// Integration: node tests/jxl-capture.test.cjs <local-video> [seconds]
// Uses the bundled encoder and decoder; no network or external conversion tools.
const fs=require('node:fs'),path=require('node:path'),os=require('node:os'),assert=require('node:assert/strict'),{spawnSync}=require('node:child_process');
const root=path.resolve(__dirname,'..'),input=process.argv[2]||process.env.FUA_CAPTURE_TEST_VIDEO;
assert(input&&fs.existsSync(input),'Pass a local video to test HDR/SDR screenshot capture');
const mpv=[process.env.FUA_MPV,path.join(root,'.deps/mpv-extractor/mpv.com'),path.join(root,'app/fua-native/runtime/mpv.exe')].find(p=>p&&fs.existsSync(p));
assert(mpv,'Bundled mpv is required');
fs.mkdirSync(path.join(root,'.deps'),{recursive:true});
const dir=fs.mkdtempSync(path.join(root,'.deps','fua-jxl-')),output=path.join(dir,'frame.jxl'),sourceReport=path.join(dir,'source.json'),decodedReport=path.join(dir,'decoded.json');
function run(args){const r=spawnSync(mpv,['--no-config','--vo=null','--ao=null','--pause','--script=tests/jxl-capture.lua',...args],{cwd:root,encoding:'utf8',windowsHide:true,timeout:30000});assert.ifError(r.error);assert.equal(r.status,0,r.stdout+r.stderr);}
try{
 run(['--start='+Number(process.argv[3]||80),'--screenshot-sw=yes','--screenshot-format=jxl','--screenshot-jxl-distance=0','--screenshot-high-bit-depth=yes','--screenshot-tag-colorspace=yes',`--script-opts=jxl-test-mode=capture,jxl-test-output=${output.replaceAll('\\','/')},jxl-test-report=${sourceReport.replaceAll('\\','/')}`,path.resolve(input)]);
 assert(fs.existsSync(output),'Encoder did not create a screenshot: '+(fs.existsSync(sourceReport)?fs.readFileSync(sourceReport,'utf8'):'no source report'));
 assert(fs.statSync(output).size>0,'Screenshot must contain image data');
 const source=JSON.parse(fs.readFileSync(sourceReport)).video;
 run([`--script-opts=jxl-test-mode=decode,jxl-test-report=${decodedReport.replaceAll('\\','/')}`,output]);
 const decoded=JSON.parse(fs.readFileSync(decodedReport)).video;
 assert.equal(decoded.w,source.dw);assert.equal(decoded.h,source.dh);
 assert.equal(decoded.gamma,source.gamma,'Transfer function must survive encoding');
 assert.equal(decoded.primaries,source.primaries,'Color primaries must survive encoding');
 if(['pq','hlg'].includes(source.gamma))assert(decoded['average-bpp']>=48,'HDR capture must retain high-depth RGB');
 console.log(JSON.stringify({pass:true,width:decoded.w,height:decoded.h,gamma:decoded.gamma,primaries:decoded.primaries,pixelFormat:decoded.pixelformat,bytes:fs.statSync(output).size}));
}finally{for(const file of [output,sourceReport,decodedReport])fs.rmSync(file,{force:true});fs.rmdirSync(dir);}
