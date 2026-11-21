// Exercise the real native HDR policy without displaying a window or changing Windows HDR.
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict'),{spawnSync}=require('node:child_process');
const root=path.resolve(__dirname,'..'),dir=path.join(root,'.deps/hdr-policy-test');fs.mkdirSync(dir,{recursive:true});
const source=fs.readFileSync(path.join(root,'app/fua-native/FuaDisplayColor.cs'),'utf8');
const stub=`
partial class FuaNative : Form {
 bool ready=true,rtxRequested=false; string rtx;
 System.Collections.Generic.Dictionary<string,string> options=new System.Collections.Generic.Dictionary<string,string>();
 System.Web.Script.Serialization.JavaScriptSerializer json=new System.Web.Script.Serialization.JavaScriptSerializer();
 int sends;
 string DataFile(string name){return System.IO.Path.Combine(".deps/hdr-policy-test",name);}
 string Get(string name){string value;return options.TryGetValue(name,out value)?value:"";}
 void Send(params string[] args){sends++;if(args[0]=="set")options[args[1]]=args[2];}
 static void Check(bool value,string message){if(!value)throw new Exception(message);}
 [STAThread]static void Main(){
  using(var p=new FuaNative()){
   Check(p.hdrOutputMode=="direct","New installations must default to direct HDR");
   p.hdrOutputMode="auto";
   p.hdrDisplay=true;p.options["video-params/gamma"]="pq";
   p.ApplyHdrOutput();Check(p.Get("target-colorspace-hint-mode")=="source","Auto must choose direct for HDR on an HDR display");
   Check(p.Get("hdr-compute-peak")=="no","Direct mode must avoid dynamic remapping");
   Check(p.Get("target-peak")=="auto","Never fix a TV luminance value");
   Check(!p.hdrXpRequested&&p.Get("inverse-tone-mapping")==""&&p.Get("tone-mapping")=="","HDR XP must start disabled without touching the original rendering curve");
   p.options["tone-mapping-spline-contrast"]="0.42";p.options["tone-mapping-knee-adaptation"]="0.23";
   p.ToggleHdrXp();Check(p.Get("tone-mapping-spline-contrast")=="0.42"&&p.Get("tone-mapping-knee-adaptation")=="0","XP disables average adaptation without forcing contrast");Check(p.Get("inverse-tone-mapping")=="yes"&&p.Get("tone-mapping")=="spline","HDR XP must enable inverse mapping with a supported curve");
   Check(p.Get("target-colorspace-hint-mode")=="target"&&p.Get("hdr-compute-peak")=="yes","Expansion must use the display capacity and scene peak analysis");
   Check(p.Get("user-data/fua-hdr-xp")=="true","Button animation must follow the applied effect");
   p.ToggleHdrXp();Check(p.Get("inverse-tone-mapping")=="no"&&p.Get("target-colorspace-hint-mode")=="source"&&p.Get("tone-mapping")=="bt.2446a","Disabling XP must restore the selected HDR mode and configured curve");
   Check(p.Get("tone-mapping-spline-contrast")=="0.42"&&p.Get("tone-mapping-knee-adaptation")=="0.23","XP off restores exact prior curve parameters");
   p.options["brightness"]="5";
   p.SetHdrXpMode(1);Check(p.Get("brightness")=="4","Minus one is relative to original brightness");
   p.SetHdrXpMode(2);Check(p.Get("brightness")=="3","Switching compensation must not accumulate");
   p.SetHdrXpMode(0);Check(p.Get("brightness")=="5","No compensation restores original brightness while XP stays on");
   p.SetHdrXpMode(2);p.options["brightness"]="4";
   Check(p.HdrXpBaseBrightness()==6,"Manual changes while compensated preserve an independent baseline");
   p.SetHdrXpMode(-1);Check(p.Get("brightness")=="6","XP off removes compensation without losing manual changes");
   p.CycleHdrXp();Check(p.Get("user-data/fua-hdr-xp-mode")=="0","Cycle starts without compensation");
   p.CycleHdrXp();Check(p.Get("brightness")=="5"&&p.Get("user-data/fua-hdr-xp-mode")=="1","Cycle selects minus one");
   p.CycleHdrXp();Check(p.Get("brightness")=="4"&&p.Get("user-data/fua-hdr-xp-mode")=="2","Cycle selects minus two");
   p.CycleHdrXp();Check(p.Get("brightness")=="6"&&!p.hdrXpRequested,"Cycle returns to off and restores brightness");
   p.SetHdrXpMode(2);p.SetBaseBrightness(10);
   Check(p.Get("brightness")=="8"&&p.HdrXpBaseBrightness()==10,"Menu brightness stays independent from minus two compensation");
   p.SetHdrXpMode(1);Check(p.Get("brightness")=="9"&&p.HdrXpBaseBrightness()==10,"Cycling compensation keeps the same menu value");
   p.SetBaseBrightness(0);Check(p.Get("brightness")=="-1"&&p.HdrXpBaseBrightness()==0,"Resetting the menu preserves active compensation");
   p.SetBaseBrightness(-100);Check(p.Get("brightness")=="-100"&&p.HdrXpBaseBrightness()==-100,"Compensation clamps without losing the base value");
   p.SetHdrXpMode(-1);Check(p.Get("brightness")=="-100","Turning XP off preserves base brightness at the limit");
   p.UpdateHdrXpScreen("tv-test",950);
   p.SetHdrXpPeak(800);Check(p.hdrXpManualPeak==0,"Peak slider must be inactive when XP is off");
   p.SetHdrXpMode(0);p.SetHdrXpPeak(800);Check(p.Get("target-peak")=="800","Manual peak applies only to XP");
   p.SetHdrXpMode(-1);Check(p.Get("target-peak")=="auto","Normal HDR restores automatic target peak");
   p.SetHdrXpMode(0);Check(p.Get("target-peak")=="800","XP remembers this screen's manual limit");
   p.UpdateHdrXpScreen("work-test",500);p.ApplyHdrOutput();Check(p.hdrXpManualPeak==0&&p.Get("target-peak")=="auto","A new monitor uses its own automatic limit");
   p.SetHdrXpPeak(950);Check(p.Get("target-peak")=="500","Manual requests cannot exceed the reported monitor limit");
   p.UpdateHdrXpScreen("tv-test",950);p.ApplyHdrOutput();Check(p.Get("target-peak")=="800","Returning to the TV restores its separate setting");
   p.SetHdrXpPeak(0);Check(p.Get("target-peak")=="auto","Restore automatic removes the override");
   p.SetHdrXpMode(-1);
   int before=p.sends;p.ApplyHdrOutput();Check(p.sends==before,"Unchanged policy must not reset the renderer each tick");
   p.SetHdrOutputMode("processed");Check(p.Get("target-colorspace-hint-mode")=="target","Processed mode must retain display adaptation");
   Check(p.Get("hdr-compute-peak")=="yes","Processed mode must restore configured peak detection");
   p.SetHdrOutputMode("direct");Check(p.Get("target-colorspace-hint-mode")=="source","Direct selection must apply immediately");
   p.hdrDisplay=false;p.ApplyHdrOutput();Check(p.Get("target-trc")=="srgb"&&p.Get("target-colorspace-hint")=="no","SDR screen must never be forced to HDR");
   p.ToggleHdrXp();Check(!p.hdrXpRequested,"XP must not enable on an SDR display");
   p.hdrDisplay=true;p.options["video-params/gamma"]="bt.1886";p.ApplyHdrOutput();Check(p.Get("target-colorspace-hint-mode")=="target","SDR content must keep the existing rendering/RTX path");
   p.ToggleHdrXp();Check(!p.hdrXpRequested,"XP must not stack over the SDR/RTX HDR path");
   p.options["video-params/gamma"]="hlg";p.ApplyHdrOutput();Check(p.Get("target-colorspace-hint-mode")=="source","HLG content must be recognized as HDR");
   p.ready=false;p.ApplyHdrOutput();Check(p.Get("target-colorspace-hint-mode")=="target","Unloaded files must clear direct HDR");
   p.ready=true;p.ApplyHdrOutput();Check(p.Get("target-colorspace-hint-mode")=="source","Loading HDR must reapply source mode");
   p.hdrOutputMode="auto";p.LoadHdrOutputMode();Check(p.hdrOutputMode=="direct","Mode selection must survive restart");
  }
  Console.WriteLine("PASS: HDR direct/processed/auto, SDR fallback, HLG, renderer cache, file transitions and persistent selection");
 }
}
`;
const cs=path.join(dir,'HdrPolicyCheck.cs'),exe=path.join(dir,'HdrPolicyCheck.exe');fs.writeFileSync(cs,source+stub);
const compiler=path.join(process.env.WINDIR||'C:/Windows','Microsoft.NET/Framework64/v4.0.30319/csc.exe');
const build=spawnSync(compiler,['/nologo','/target:exe','/reference:System.Windows.Forms.dll','/reference:System.Drawing.dll','/reference:System.Web.Extensions.dll','/out:'+exe,cs],{cwd:root,encoding:'utf8',windowsHide:true});
assert.ifError(build.error);assert.equal(build.status,0,build.stdout+build.stderr);
const run=spawnSync(exe,[],{cwd:root,encoding:'utf8',windowsHide:true,timeout:10000});assert.ifError(run.error);assert.equal(run.status,0,run.stdout+run.stderr);console.log(run.stdout.trim());
