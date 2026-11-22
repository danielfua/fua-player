const fs=require('fs'),vm=require('vm'),assert=require('node:assert/strict'),path=require('path'),cp=require('child_process');
const source=fs.readFileSync('app/library.js','utf8'),start=source.indexOf('function retryCastPhoto('),end=source.indexOf('\nconst bundledDetails',start);
const timers=[],context={setTimeout:(fn,delay)=>timers.push({fn,delay})};vm.createContext(context);vm.runInContext(source.slice(start,end),context);
let removed=0;const image={src:'https://image.tmdb.org/t/p/w185/a.jpg',style:{},isConnected:true,after(){}};context.retryCastPhoto(image,()=>({remove(){removed++}}));
image.onerror();assert.equal(timers[0].delay,2000);timers.shift().fn();assert(image.src.includes('fua_retry=1'));image.onerror();assert.equal(timers[0].delay,5000);timers.shift().fn();image.onload();assert.equal(removed,1);assert.equal(image.style.visibility,'');image.onerror();assert.equal(timers[0].delay,10000);timers.shift().fn();image.onerror();assert.equal(timers.length,0);image.isConnected=false;
const ui=fs.readFileSync('app/fua-native/fua-ui.lua','utf8');const chunk=ui.slice(ui.indexOf('local castPeople,'),ui.indexOf('local function activateCastPerson'));
const lua=`local mp=require 'mp';local utils=require 'mp.utils';local scriptDir='.';local isLite=false;local draw=nil
local original=mp.commandv;local timers={};local calls=0;local mode='missing'
mp.get_property=function()return 'test.mkv'end
mp.add_timeout=function(delay,fn)local t={delay=delay,fn=fn,kill=function()end};table.insert(timers,t);return t end
mp.command_native_async=function(request,fn)calls=calls+1;local person={id=1,name='Actor'};if mode~='absent'then person.photo='https://image.tmdb.org/t/p/a.jpg'end;if mode=='success'then person.file='cached.bgra'end;fn(true,{status=0,stdout=utils.format_json({cast={person}})})end
local ok,err=pcall(function()
${chunk}
loadCast();assert(calls==1 and timers[1].delay==2);table.remove(timers,1).fn();assert(calls==2 and timers[1].delay==5);table.remove(timers,1).fn();assert(calls==3 and timers[1].delay==10);table.remove(timers,1).fn();assert(calls==4 and #timers==0)
castAttempts=0;castLoaded=false;mode='success';loadCast();assert(#timers==0)
castAttempts=0;castLoaded=false;mode='absent';loadCast();assert(#timers==0)
castAttempts=0;castLoaded=false;mode='missing';loadCast();local before=calls;castGeneration=castGeneration+1;table.remove(timers,1).fn();assert(calls==before)
end)
local f=assert(io.open('.deps/cast-photo-retry.result','w'));f:write(ok and 'PASS' or tostring(err));f:close();original('quit',ok and '0' or '1')
`;fs.mkdirSync('.deps',{recursive:true});fs.writeFileSync('.deps/cast-photo-retry.lua',lua);const exe=['.deps/mpv-extractor/mpv.com','app/fua-native/runtime/mpv.exe'].find(fs.existsSync);const run=cp.spawnSync(path.resolve(exe),['--no-config','--vo=null','--ao=null','--idle=yes','--script=.deps/cast-photo-retry.lua'],{encoding:'utf8',timeout:15000,windowsHide:true});assert.equal(run.status,0,run.stdout+run.stderr);assert.equal(fs.readFileSync('.deps/cast-photo-retry.result','utf8'),'PASS');console.log('PASS photo retry delays, bounded attempts, successful recovery, missing photo exclusion and episode-change cancellation');
