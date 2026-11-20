const fs=require('fs'),vm=require('vm'),assert=require('assert');
const source=fs.readFileSync(require('path').join(__dirname,'../app/library.js'),'utf8');
const start=source.indexOf('async function signature()'),end=source.indexOf(" if(new URLSearchParams(location.search)",start);
const oscillators=[];let closed=0;const timers=[];
class AudioContext{
 constructor(){this.state='running';this.currentTime=0;this.destination={}}
 createGain(){return {gain:{setValueAtTime(){},linearRampToValueAtTime(){},exponentialRampToValueAtTime(){}},connect(){},disconnect(){}}}
 createOscillator(){const oscillator={frequency:{setValueAtTime(){}},connect(){},disconnect(){},start(){},stop(value){this.stopAt=value}};oscillators.push(oscillator);return oscillator}
 close(){closed++;this.state='closed';return Promise.resolve()}
}
const sandbox={window:{AudioContext},setTimeout:(fn,ms)=>timers.push({fn,ms})};vm.createContext(sandbox);
vm.runInContext('let enabled=true,context=null,master=null,finished=false;'+source.slice(start,end)+'signature();',sandbox);
assert.equal(oscillators.length,5);assert.equal(closed,0);assert.equal(timers.length,0,'No wall-clock timer may cut off the intro audio');
for(const oscillator of oscillators.slice(0,4))oscillator.onended();assert.equal(closed,0);
oscillators[4].onended();assert.equal(closed,1,'Close audio context only after the last voice has ended');
assert(source.includes('intro.inert=true;if(skip===true)stopSound();'));
console.log('PASS: startup audio survives visual intro and closes only when all notes have ended');
