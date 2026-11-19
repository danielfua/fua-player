using System;
using System.Globalization;
using NAudio.CoreAudioApi;

partial class FuaNative {
 double systemVolume=100;
 bool systemMuted;
 bool systemVolumeAvailable;

 void SyncSystemVolume(){
  try{
   using(var enumerator=new MMDeviceEnumerator())
   using(var device=enumerator.GetDefaultAudioEndpoint(DataFlow.Render,Role.Multimedia)){
    systemVolume=device.AudioEndpointVolume.MasterVolumeLevelScalar*100.0;
    systemMuted=device.AudioEndpointVolume.Mute;
    systemVolumeAvailable=true;
   }
  }catch{systemVolumeAvailable=false;}
  if(mpv!=IntPtr.Zero){
   Send("script-message","fua-system-volume",systemVolume.ToString(CultureInfo.InvariantCulture),systemMuted?"yes":"no");
  }
 }
 bool SetSystemVolume(double? volume,bool? mute){
  try{
   using(var enumerator=new MMDeviceEnumerator())
   using(var device=enumerator.GetDefaultAudioEndpoint(DataFlow.Render,Role.Multimedia)){
    if(volume.HasValue)device.AudioEndpointVolume.MasterVolumeLevelScalar=(float)(Math.Max(0,Math.Min(100,volume.Value))/100);
    if(mute.HasValue)device.AudioEndpointVolume.Mute=mute.Value;
   }
   SyncSystemVolume();
   return true;
  }catch{lastError="Não foi possível ajustar o volume do Windows.";return false;}
 }
 bool HandleSystemVolume(string[] args){
  if(args.Length<2)return false;
  if(args[0]=="set"&&args.Length>=3&&args[1]=="volume"){
   double value;
   if(double.TryParse(args[2],NumberStyles.Float,CultureInfo.InvariantCulture,out value))
    SetSystemVolume(value,null);
   return true;
  }
  if(args[1]=="mute"){
   if(args[0]=="cycle"){SyncSystemVolume();SetSystemVolume(null,!systemMuted);return true;}
   if(args[0]=="set"&&args.Length>=3){SetSystemVolume(null,args[2]=="yes");return true;}
  }
  return false;
 }
}
