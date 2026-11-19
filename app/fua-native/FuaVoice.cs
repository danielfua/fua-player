using System;
using System.IO;
using System.Runtime.InteropServices;
using System.Threading.Tasks;
using NAudio.Wave;
using System.Windows.Forms;
using System.Collections.Generic;
using System.Text;
using System.Globalization;
partial class FuaNative {
 Dictionary<string,string> DefaultVoiceCommands(){
  return new Dictionary<string,string>{{"pause","para"},{"play","continua"},{"forward","pra frente"},
   {"back","pra tras"},{"volume-up","aumenta"},{"volume-down","abaixa"},
   {"volume-up-more","aumenta mais"},{"volume-down-more","abaixa mais"},{"mute","silenciar"},
   {"unmute","ativar som"},{"fullscreen","tela cheia"},{"library","biblioteca"}};
 }
 string NormalizeVoice(string value){
  var result=new StringBuilder();
  foreach(char character in value.Trim().ToLowerInvariant().Normalize(NormalizationForm.FormD))
   if(CharUnicodeInfo.GetUnicodeCategory(character)!=UnicodeCategory.NonSpacingMark)result.Append(character);
  return System.Text.RegularExpressions.Regex.Replace(result.ToString(),@"\s+"," ");
 }
 Dictionary<string,string> VoiceCommands(){
  var result=DefaultVoiceCommands();
  try{
   var saved=json.Deserialize<Dictionary<string,string>>(File.ReadAllText(DataFile("voice-commands.json")));
   foreach(string action in new List<string>(result.Keys))
    if(saved.ContainsKey(action))result[action]=saved[action];
  }catch{}
  return result;
 }
 void ValidateVoiceCommands(Dictionary<string,string> commands){
  var used=new HashSet<string>();
  foreach(string phrase in commands.Values){
   string normalized=NormalizeVoice(phrase);
   if(normalized.Length==0||normalized.Length>80||!System.Text.RegularExpressions.Regex.IsMatch(normalized,@"^[a-z ]+$"))
    throw new Exception("Use uma frase em português, apenas com letras e espaços.");
   if(!used.Add(normalized))throw new Exception("Cada ação precisa de uma frase diferente.");
  }
 }
 [DllImport("libvosk.dll",CallingConvention=CallingConvention.Cdecl)]static extern IntPtr vosk_model_new(IntPtr path);
 [DllImport("libvosk.dll",CallingConvention=CallingConvention.Cdecl)]static extern void vosk_model_free(IntPtr model);
 [DllImport("libvosk.dll",CallingConvention=CallingConvention.Cdecl)]static extern IntPtr vosk_recognizer_new_grm(IntPtr model,float rate,IntPtr grammar);
 [DllImport("libvosk.dll",CallingConvention=CallingConvention.Cdecl)]static extern void vosk_recognizer_free(IntPtr recognizer);
 [DllImport("libvosk.dll",CallingConvention=CallingConvention.Cdecl)]static extern int vosk_recognizer_accept_waveform(IntPtr recognizer,byte[] data,int length);
 [DllImport("libvosk.dll",CallingConvention=CallingConvention.Cdecl)]static extern IntPtr vosk_recognizer_result(IntPtr recognizer);
 [DllImport("libvosk.dll",CallingConvention=CallingConvention.Cdecl)]static extern void vosk_set_log_level(int level);
 sealed class VoiceSession : IDisposable {
  public IntPtr Model,Recognizer;
  public WaveInEvent Input;
  public readonly object Gate=new object();
  public bool Closed;
  public Dictionary<string,string> Commands;
  public void Dispose(){
   lock(Gate){if(Closed)return;Closed=true;}
   if(Input!=null){Input.StopRecording();Input.Dispose();}
   lock(Gate){
    if(Recognizer!=IntPtr.Zero)vosk_recognizer_free(Recognizer);
    if(Model!=IntPtr.Zero)vosk_model_free(Model);
    Recognizer=Model=IntPtr.Zero;
   }
  }
 }
 VoiceSession voiceSession;
 int voiceGeneration;
 string voiceStatus="Desativado";
 bool voiceStarting;
 bool VoiceEnabled(){
  try{return File.ReadAllText(DataFile("voice-enabled.txt")).Trim()!="off";}
  catch{return true;}
 }
 async Task ActivateVoice(){
  if(voiceStarting)return;
  voiceStarting=true;
  try{await StartVoice();}
  catch(Exception error){voiceStatus=error.Message;}
  finally{voiceStarting=false;}
 }
 async void AutoStartVoice(){
  if(VoiceEnabled())await ActivateVoice();
 }
 void StopVoice(){
  voiceGeneration++;
  var session=voiceSession;voiceSession=null;
  if(session!=null)session.Dispose();
  voiceStatus="Desativado";
 }
 async Task StartVoice(){
  StopVoice();
  int generation=voiceGeneration;
  string root=Path.Combine(AppDomain.CurrentDomain.BaseDirectory,"voice");
  string modelPath=Path.Combine(root,"model");
  if(!Directory.Exists(modelPath))throw new InvalidOperationException("O pacote de voz em português não está instalado.");
  if(LoadLibraryEx(Path.Combine(root,"libvosk.dll"),IntPtr.Zero,0x00000008)==IntPtr.Zero)
   throw new InvalidOperationException("Não foi possível carregar o pacote de voz.");
  voiceStatus="Carregando voz em português…";
  var commands=VoiceCommands();
  ValidateVoiceCommands(commands);
  var grammarPhrases=new List<string>(commands.Values);
  grammarPhrases.Add("[unk]");
  string grammarJson=json.Serialize(grammarPhrases);
  var session=await Task.Run(()=>{
   var created=new VoiceSession();
   try{
    vosk_set_log_level(-1);
    IntPtr path=Utf(modelPath);
    try{created.Model=vosk_model_new(path);}finally{Marshal.FreeHGlobal(path);}
    if(created.Model==IntPtr.Zero)throw new InvalidOperationException("Não foi possível abrir o modelo de português.");
    IntPtr grammar=Utf(grammarJson);
    try{created.Recognizer=vosk_recognizer_new_grm(created.Model,16000,grammar);}finally{Marshal.FreeHGlobal(grammar);}
    if(created.Recognizer==IntPtr.Zero)throw new InvalidOperationException("Não foi possível preparar os comandos.");
    created.Commands=commands;
    return created;
   }catch{created.Dispose();throw;}
  });
  if(generation!=voiceGeneration||IsDisposed){session.Dispose();return;}
  try{
   session.Input=new WaveInEvent{WaveFormat=new WaveFormat(16000,16,1),BufferMilliseconds=100};
   session.Input.DataAvailable+=(sender,args)=>{
    string command=null;
    lock(session.Gate){
     if(session.Closed)return;
     if(vosk_recognizer_accept_waveform(session.Recognizer,args.Buffer,args.BytesRecorded)!=0){
      try{
       var result=new System.Web.Script.Serialization.JavaScriptSerializer().Deserialize<System.Collections.Generic.Dictionary<string,object>>(Str(vosk_recognizer_result(session.Recognizer)));
       if(result.ContainsKey("text"))command=Convert.ToString(result["text"]);
      }catch{}
     }
    }
    if(string.IsNullOrWhiteSpace(command)||IsDisposed||!IsHandleCreated)return;
    try{BeginInvoke((Action)(()=>VoiceCommand(session,command)));}catch(InvalidOperationException){}
   };
   voiceSession=session;
   session.Input.StartRecording();
   voiceStatus="Microfone ativo · reconhecimento local";
  }catch{session.Dispose();voiceSession=null;throw;}
 }
 void VoiceCommand(VoiceSession session,string command){
  if(voiceSession!=session||libraryMode||!ready||GetForegroundWindow()!=Handle)return;
  string action=null;
  foreach(var entry in session.Commands)
   if(NormalizeVoice(entry.Value)==NormalizeVoice(command)){action=entry.Key;break;}
  switch(action){
   case "pause":Send("set","pause","yes");break;
   case "play":Send("set","pause","no");break;
   case "forward":Send("seek","10");break;
   case "back":Send("seek","-10");break;
   case "volume-up":SyncSystemVolume();SetSystemVolume(systemVolume+2,null);break;
   case "volume-down":SyncSystemVolume();SetSystemVolume(systemVolume-2,null);break;
   case "volume-up-more":SyncSystemVolume();SetSystemVolume(systemVolume+5,null);break;
   case "volume-down-more":SyncSystemVolume();SetSystemVolume(systemVolume-5,null);break;
   case "mute":Send("set","mute","yes");break;
   case "unmute":Send("set","mute","no");break;
   case "fullscreen":ToggleFull();break;
   case "library":ShowLibrary();break;
   default:return;
  }
  if(!libraryMode)Send("show-text",command);
 }
}
