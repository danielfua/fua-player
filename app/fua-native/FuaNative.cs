using System;
using System.IO;
using System.Text;
using System.Runtime.InteropServices;
using System.Windows.Forms;
using System.Drawing;
using System.Web.Script.Serialization;
using System.Collections.Generic;
using System.Threading;
using Microsoft.Web.WebView2.Core;
using Microsoft.Web.WebView2.WinForms;
partial class FuaNative : Form {
 void OpenExternalPerson(object sender,CoreWebView2NewWindowRequestedEventArgs e){
  e.Handled=true;Uri target;
  if(!Uri.TryCreate(e.Uri,UriKind.Absolute,out target)||target.Scheme!="https"||(target.Host!="www.themoviedb.org"&&target.Host!="themoviedb.org")||!System.Text.RegularExpressions.Regex.IsMatch(target.AbsolutePath,@"^/person/[0-9]+/?$"))return;
  try{System.Diagnostics.Process.Start(new System.Diagnostics.ProcessStartInfo(target.AbsoluteUri){UseShellExecute=true});}
  catch{browser.CoreWebView2.ExecuteScriptAsync("toast('Não foi possível abrir o navegador.')");}
 }
 sealed class VideoPanel:Panel {public Func<bool> HideCursor;protected override void WndProc(ref Message message){if(message.Msg==0x20&&HideCursor!=null&&HideCursor()){SetCursor(IntPtr.Zero);message.Result=new IntPtr(1);return;}base.WndProc(ref message);}}

[DllImport("user32.dll")]static extern bool SetForegroundWindow(IntPtr h);
[DllImport("user32.dll")]static extern bool ShowWindow(IntPtr h,int mode);
[DllImport("user32.dll")]static extern short GetAsyncKeyState(int key);[DllImport("user32.dll")]static extern IntPtr GetForegroundWindow();[DllImport("user32.dll")]static extern IntPtr SetCursor(IntPtr cursor);[DllImport("user32.dll")]static extern IntPtr LoadCursor(IntPtr instance,IntPtr name);bool rightPointerDown=false,pointerDown=false,cursorHidden=false,uiMenuOpen=false;long cursorHideAt=0,cursorRevealAt=0,cursorLastMotion=0;Point cursorRevealOrigin;
 [DllImport("kernel32.dll",CharSet=CharSet.Unicode,SetLastError=true)] static extern IntPtr LoadLibraryEx(string p,IntPtr f,uint flags);
 [DllImport("kernel32.dll",CharSet=CharSet.Ansi)] static extern IntPtr GetProcAddress(IntPtr h,string n);
 [UnmanagedFunctionPointer(CallingConvention.Cdecl)] delegate IntPtr Create();
 [UnmanagedFunctionPointer(CallingConvention.Cdecl)] delegate int Option(IntPtr h,IntPtr n,IntPtr v);
 [UnmanagedFunctionPointer(CallingConvention.Cdecl)] delegate int Init(IntPtr h);
 [UnmanagedFunctionPointer(CallingConvention.Cdecl)] delegate int Command(IntPtr h,ulong u,IntPtr a);
 [UnmanagedFunctionPointer(CallingConvention.Cdecl)] delegate IntPtr GetString(IntPtr h,IntPtr n);
 [UnmanagedFunctionPointer(CallingConvention.Cdecl)] delegate void Free(IntPtr p);
 [UnmanagedFunctionPointer(CallingConvention.Cdecl)] delegate void Destroy(IntPtr h);
 [UnmanagedFunctionPointer(CallingConvention.Cdecl)] delegate IntPtr WaitEvent(IntPtr h,double timeout);
 [UnmanagedFunctionPointer(CallingConvention.Cdecl)] delegate int Logs(IntPtr h,IntPtr level);
 [StructLayout(LayoutKind.Sequential)] struct Event {public int id,error;public ulong user;public IntPtr data;}
 [StructLayout(LayoutKind.Sequential)] struct Log {public IntPtr prefix,level,text;public int verbosity;}
 IntPtr lib,mpv;Option opt;Init init;Command cmd;GetString get;Free free;Destroy destroy;WaitEvent wait;Logs logs;
 Panel bottom=new Panel();Panel playback=new Panel();WebView2 browser=new WebView2();bool libraryReady=false,libraryMode=false;string lastHud="";Panel video=new VideoPanel();Label info=new Label();TrackBar seek=new TrackBar();FlowLayoutPanel controls=new FlowLayoutPanel();System.Windows.Forms.Timer timer=new System.Windows.Forms.Timer();System.Windows.Forms.Timer pointerTimer=new System.Windows.Forms.Timer();Point lastPointer=new Point(-99999,-99999);bool lastPointerInside=false;
 JavaScriptSerializer json=new JavaScriptSerializer();string current="",rtx="Aguardando video";bool ready=false,rtxRequested=true,seeking=false,bridgeMode;double resume=0;bool startPaused=false;string lastError="";int ticks;bool full;Rectangle restore;FormBorderStyle priorBorder;
 T Fn<T>(string n){return (T)(object)Marshal.GetDelegateForFunctionPointer(GetProcAddress(lib,n),typeof(T));}
 static IntPtr Utf(string s){byte[] b=Encoding.UTF8.GetBytes(s+"\0");IntPtr p=Marshal.AllocHGlobal(b.Length);Marshal.Copy(b,0,p,b.Length);return p;}
 static string Str(IntPtr p){if(p==IntPtr.Zero)return "";int n=0;while(Marshal.ReadByte(p,n)!=0)n++;byte[] b=new byte[n];Marshal.Copy(p,b,0,n);return Encoding.UTF8.GetString(b);}
 int Set(string k,string v){IntPtr a=Utf(k),b=Utf(v);try{return opt(mpv,a,b);}finally{Marshal.FreeHGlobal(a);Marshal.FreeHGlobal(b);}}
 string Get(string k){IntPtr n=Utf(k);try{IntPtr p=get(mpv,n);if(p==IntPtr.Zero)return "";try{return Str(p);}finally{free(p);}}finally{Marshal.FreeHGlobal(n);}}
 void Send(params string[] args){IntPtr a=Marshal.AllocHGlobal((args.Length+1)*IntPtr.Size);IntPtr[] b=new IntPtr[args.Length];try{for(int i=0;i<args.Length;i++){b[i]=Utf(args[i]);Marshal.WriteIntPtr(a,i*IntPtr.Size,b[i]);}Marshal.WriteIntPtr(a,args.Length*IntPtr.Size,IntPtr.Zero);int code=cmd(mpv,0,a);if(code<0)lastError="Comando mpv recusado: "+args[0];}finally{foreach(IntPtr p in b)if(p!=IntPtr.Zero)Marshal.FreeHGlobal(p);Marshal.FreeHGlobal(a);}}
 double Number(string k){double d;return double.TryParse(Get(k),System.Globalization.NumberStyles.Float,System.Globalization.CultureInfo.InvariantCulture,out d)?d:0;}
 Button Btn(string label,Action action){Button b=new Button();b.Text=label;b.AutoSize=true;b.Height=32;b.FlatStyle=FlatStyle.Flat;b.ForeColor=Color.White;b.BackColor=Color.FromArgb(30,42,54);b.Click+=(s,e)=>action();controls.Controls.Add(b);return b;}
 public FuaNative(string[] args){bridgeMode=Array.IndexOf(args,"--bridge")>=0;Text="Fua Player";FormBorderStyle=FormBorderStyle.None;BackColor=Color.FromArgb(10,16,23);ForeColor=Color.White;Rectangle area=Screen.PrimaryScreen.WorkingArea;Size=new Size((int)(area.Width*0.92),(int)(area.Height*0.92));MinimumSize=new Size(700,420);StartPosition=FormStartPosition.CenterScreen;WindowState=FormWindowState.Normal;KeyPreview=true;Directory.CreateDirectory(DataRoot);InitShortcuts();Application.AddMessageFilter(new ShortcutFilter(this));
 string icon=Path.Combine(AppDomain.CurrentDomain.BaseDirectory,"..","fua-player-v2.ico");if(File.Exists(icon))Icon=new Icon(icon);
 ((VideoPanel)video).HideCursor=()=>!libraryMode&&cursorHidden;video.Dock=DockStyle.Fill;video.BackColor=Color.Black;playback.Dock=DockStyle.Fill;playback.Controls.Add(video);Controls.Add(playback);
 bottom.Dock=DockStyle.Bottom;bottom.Height=104;bottom.BackColor=BackColor;playback.Controls.Add(bottom);
 seek.Dock=DockStyle.Top;seek.Maximum=10000;seek.Height=28;seek.TickStyle=TickStyle.None;seek.MouseDown+=(s,e)=>seeking=true;seek.MouseUp+=(s,e)=>{Send("seek",(Number("duration")*seek.Value/10000).ToString(System.Globalization.CultureInfo.InvariantCulture),"absolute+exact");seeking=false;};bottom.Controls.Add(seek);
 controls.Dock=DockStyle.Top;controls.Top=28;controls.Height=38;bottom.Controls.Add(controls);controls.BringToFront();seek.BringToFront();
 Btn("Biblioteca",ShowLibrary);Btn("Abrir",()=>{using(OpenFileDialog d=new OpenFileDialog()){d.Filter="Videos|*.mkv;*.mp4;*.avi;*.webm;*.mov|Todos|*.*";if(d.ShowDialog()==DialogResult.OK)Open(d.FileName,0);}});
 Btn("Play / Pause",()=>Send("cycle","pause"));Btn("Audio",()=>Send("cycle","audio"));Btn("Legenda",()=>Send("cycle","sub"));Btn("RTX HDR",()=>{rtxRequested=!rtxRequested;Send("vf",rtxRequested?"add":"remove",rtxRequested?"@fua-rtx:d3d11vpp=nvidia-true-hdr":"@fua-rtx");rtx=rtxRequested?"RTX HDR solicitado; aguardando confirmacao":"RTX HDR desligado";});Btn("Tela cheia",ToggleFull);
 info.Dock=DockStyle.Bottom;info.Height=26;info.Padding=new Padding(12,3,0,0);info.ForeColor=Color.FromArgb(180,210,230);bottom.Controls.Add(info);

 browser.Dock=DockStyle.Fill;browser.DefaultBackgroundColor=Color.FromArgb(10,16,23);Controls.Add(browser);browser.Visible=false;Shown+=(s,e)=>{StartPlayer(args);BeginInvoke((Action)(()=>{FrontWindow();var startupFront=new System.Windows.Forms.Timer();int attempts=0;startupFront.Interval=500;startupFront.Tick+=(sender,eventArgs)=>{FrontWindow();if(++attempts>=2){startupFront.Stop();startupFront.Dispose();}};startupFront.Start();}));};FormClosing+=(s,e)=>{SavePlayerPreferences();Emit();timer.Stop();pointerTimer.Stop();SetCursor(LoadCursor(IntPtr.Zero,new IntPtr(32512)));};FormClosed+=(s,e)=>{if(mpv!=IntPtr.Zero){destroy(mpv);mpv=IntPtr.Zero;}};
 }
 async void InitLibrary(){try{var env=await CoreWebView2Environment.CreateAsync(null,(Environment.GetEnvironmentVariable("FUA_WEBVIEW_PROFILE")??DataFile("webview-profile")));await browser.EnsureCoreWebView2Async(env);browser.CoreWebView2.Settings.AreDevToolsEnabled=false;browser.CoreWebView2.NewWindowRequested+=OpenExternalPerson;browser.CoreWebView2.NavigationStarting+=(s,e)=>{if(!e.Uri.StartsWith("http://127.0.0.1:8780/",StringComparison.OrdinalIgnoreCase))e.Cancel=true;};browser.CoreWebView2.WebMessageReceived+=(s,e)=>{if(!e.Source.StartsWith("http://127.0.0.1:8780/",StringComparison.OrdinalIgnoreCase))return;string msg=e.TryGetWebMessageAsString();if(msg=="settings")AppSettings();if(msg=="minimize")WindowState=FormWindowState.Minimized;if(msg=="close")Close();if(msg=="fullscreen")ToggleFull();};browser.CoreWebView2.NavigationCompleted+=(s,e)=>{libraryReady=e.IsSuccess;};browser.CoreWebView2.Navigate("http://127.0.0.1:8780/");ShowLibrary();}catch(Exception ex){lastError="Biblioteca: "+ex.Message;MessageBox.Show(lastError,"Fua Player");}}
void FrontWindow(){if(WindowState==FormWindowState.Minimized){WindowState=FormWindowState.Normal;ShowWindow(Handle,9);}else ShowWindow(Handle,5);Show();TopMost=true;TopMost=false;BringToFront();Activate();SetForegroundWindow(Handle);}
void ShowLibrary(){SetCursor(LoadCursor(IntPtr.Zero,new IntPtr(32512)));cursorHidden=false;if(mpv!=IntPtr.Zero){Send("set","pause","yes");Send("script-message","fua-stats-close");}browser.Visible=true;browser.BringToFront();playback.Visible=false;libraryMode=true;Text="Fua Player";browser.Focus();FrontWindow();}
void ShowPlayback(){bottom.Visible=false;browser.Visible=false;playback.Visible=true;playback.BringToFront();libraryMode=false;video.Focus();}
void ToggleFull(){
 if(!full){Rectangle screen=Screen.FromControl(this).Bounds;restore=WindowState==FormWindowState.Normal?Bounds:RestoreBounds;if(restore.Width<=0||restore.Height<=0||restore.Width>=screen.Width&&restore.Height>=screen.Height){Rectangle area=Screen.FromControl(this).WorkingArea;restore=new Rectangle(area.X+area.Width/20,area.Y+area.Height/20,area.Width*9/10,area.Height*9/10);}priorBorder=FormBorderStyle;WindowState=FormWindowState.Normal;FormBorderStyle=FormBorderStyle.None;Bounds=screen;full=true;}
 else{WindowState=FormWindowState.Normal;FormBorderStyle=priorBorder;Bounds=restore;full=false;}
 }

 void StartPlayer(string[] args){try{
 string dll=Environment.GetEnvironmentVariable("FUA_LIBMPV");if(string.IsNullOrEmpty(dll))dll=Path.Combine(AppDomain.CurrentDomain.BaseDirectory,"runtime","libmpv-2.dll");
 lib=LoadLibraryEx(dll,IntPtr.Zero,0x00000008);if(lib==IntPtr.Zero)throw new Exception("Nao foi possivel carregar libmpv: "+Marshal.GetLastWin32Error());
 mpv=Fn<Create>("mpv_create")();if(mpv==IntPtr.Zero)throw new Exception("mpv_create falhou");opt=Fn<Option>("mpv_set_option_string");init=Fn<Init>("mpv_initialize");cmd=Fn<Command>("mpv_command_async");get=Fn<GetString>("mpv_get_property_string");free=Fn<Free>("mpv_free");destroy=Fn<Destroy>("mpv_terminate_destroy");wait=Fn<WaitEvent>("mpv_wait_event");logs=Fn<Logs>("mpv_request_log_messages");
 string[][] settings={new[]{"config","no"},new[]{"alang","pt-BR,por"},new[]{"slang","pt-BR,por"},new[]{"subs-with-matching-audio","forced"},new[]{"subs-fallback","no"},new[]{"vo","gpu-next"},new[]{"gpu-api","d3d11"},new[]{"gpu-context","d3d11"},new[]{"hwdec","d3d11va"},new[]{"wid",video.Handle.ToInt64().ToString()},new[]{"keep-open","yes"},new[]{"input-default-bindings","no"},new[]{"input-vo-keyboard","no"},new[]{"osc","no"},new[]{"cursor-autohide","always"},new[]{"target-colorspace-hint","yes"},new[]{"target-peak","1100"},new[]{"hdr-compute-peak","yes"},new[]{"tone-mapping","bt.2446a"},new[]{"gamut-mapping-mode","perceptual"},new[]{"scale","ewa_lanczossharp"},new[]{"cscale","ewa_lanczossharp"},new[]{"dscale","mitchell"},new[]{"correct-downscaling","yes"},new[]{"sigmoid-upscaling","yes"},new[]{"linear-downscaling","yes"},new[]{"deband","yes"},new[]{"deband-iterations","2"},new[]{"deband-threshold","48"},new[]{"deband-range","16"},new[]{"deband-grain","4"},new[]{"cache","auto"},new[]{"demuxer-seekable-cache","no"},new[]{"demuxer-max-bytes","768MiB"},new[]{"demuxer-max-back-bytes","256MiB"},new[]{"vf","@fua-rtx:d3d11vpp=nvidia-true-hdr"}};
 foreach(string[] kv in settings){int code=Set(kv[0],kv[1]);if(code<0)File.AppendAllText(DataFile("native.log"),"Opcao recusada: "+kv[0]+"="+kv[1]+Environment.NewLine);}
 IntPtr level=Utf("v");logs(mpv,level);Marshal.FreeHGlobal(level);if(init(mpv)<0)throw new Exception("Falha ao iniciar mpv");
 LoadPlayerPreferences();Send("load-script",Path.Combine(AppDomain.CurrentDomain.BaseDirectory,"fua-ui.lua"));timer.Interval=200;timer.Tick+=(s,e)=>{try{TickPlayer();}catch(Exception ex){lastError=ex.Message;}};timer.Start();pointerTimer.Interval=15;pointerTimer.Tick+=(s,e)=>ForwardPointer();pointerTimer.Start();if(Array.IndexOf(args,"--library")>=0)InitLibrary();if(bridgeMode){Thread t=new Thread(ReadCommands);t.IsBackground=true;t.Start();}else if(args.Length>0&&File.Exists(args[0]))Open(args[0],0);else info.Text="Abra um video. RTX HDR requer tela HDR com HDR ativo no Windows.";
 }catch(Exception ex){lastError=ex.Message;Console.WriteLine(json.Serialize(new{error=lastError}));MessageBox.Show(lastError,"Fua Player");Close();}}
 void ReadCommands(){JavaScriptSerializer inputJson=new JavaScriptSerializer();string l;while((l=Console.ReadLine())!=null){try{Dictionary<string,object> d=inputJson.Deserialize<Dictionary<string,object>>(l);BeginInvoke((Action)(()=>{string a=Convert.ToString(d["action"]);if(a=="open")Open(Convert.ToString(d["file"]),Convert.ToDouble(d["position"]),d.ContainsKey("paused") && Convert.ToBoolean(d["paused"]));if(a=="front")FrontWindow();if(a=="fullscreen")ToggleFull();if(a=="menu-key")Send("script-message","fua-menu-key",Convert.ToString(d["key"]));if(a=="menu-scroll")Send("script-message","fua-menu-scroll",Convert.ToString(d["delta"]));if(a=="shortcut")InvokeShortcut(Convert.ToString(d["id"]));if(a=="audio")Send("script-message","fua-select-audio",Convert.ToString(d["id"]));if(a=="volume")Send("set","volume",Convert.ToString(d["value"]));if(a=="capture"){Send("set","pause","yes");Send("screenshot-to-file",Convert.ToString(d["file"]),"window");}if(a=="library")ShowLibrary();if(a=="quit")Close();}));}catch{}}}
 void Open(string file,double position,bool paused=false){startPaused=paused;ShowPlayback();current=file;resume=position;ready=false;lastError="";rtx="RTX HDR solicitado; aguardando confirmacao";Text="Fua Player - "+Path.GetFileName(file);Send("loadfile",file,"replace");FrontWindow();}
 sealed class ShortcutFilter:IMessageFilter {
  readonly FuaNative owner;public ShortcutFilter(FuaNative value){owner=value;}
  public bool PreFilterMessage(ref Message message){
   if(!owner.libraryMode&&owner.ready&&GetForegroundWindow()==owner.Handle){
    bool trackMenu=owner.Get("user-data/fua-track-menu")=="true";
    if(message.Msg==0x20A&&trackMenu){int delta=(short)((message.WParam.ToInt64()>>16)&65535);owner.Send("script-message","fua-menu-scroll",delta>0?"-3":"3");return true;}
    if(message.Msg==0x100&&Control.ModifierKeys==Keys.None){Keys code=(Keys)message.WParam.ToInt32();if((trackMenu&&(code==Keys.Up||code==Keys.Down||code==Keys.PageUp||code==Keys.PageDown||code==Keys.Home||code==Keys.End||code==Keys.Enter))||(code==Keys.Escape&&owner.Get("user-data/fua-menu-open")=="true")){owner.Send("script-message","fua-menu-key",code==Keys.Enter?"Enter":code==Keys.PageUp?"PageUp":code==Keys.PageDown?"PageDown":code.ToString());return true;}}
   }
   if((message.Msg!=0x100&&message.Msg!=0x104)||owner.libraryMode||!owner.ready||GetForegroundWindow()!=owner.Handle)return false;
   Keys key=(Keys)message.WParam.ToInt32()|Control.ModifierKeys;bool repeat=(message.LParam.ToInt64()&(1L<<30))!=0;
   return owner.DispatchShortcut(key,repeat);
  }
 }
 void ForwardPointer(){
  if(mpv==IntPtr.Zero)return;if(libraryMode||!ready)return;
  Point p=video.PointToClient(Cursor.Position);
  bool foreground=GetForegroundWindow()==Handle;
  bool inside=foreground&&WindowState!=FormWindowState.Minimized&&video.ClientRectangle.Contains(p);
  bool down=(GetAsyncKeyState(1)&0x8000)!=0;
  double nx=p.X/(double)Math.Max(1,video.ClientSize.Width),ny=p.Y/(double)Math.Max(1,video.ClientSize.Height);
  string sx=nx.ToString(System.Globalization.CultureInfo.InvariantCulture),sy=ny.ToString(System.Globalization.CultureInfo.InvariantCulture);
  bool pointerMoved=p!=lastPointer;
  if(pointerMoved||inside!=lastPointerInside){
   lastPointer=p;lastPointerInside=inside;
   Send("script-message","fua-native-pointer",sx,sy,inside?"yes":"no");
   if(inside)Send("mouse",p.X.ToString(),p.Y.ToString());
  }
  if(down&&!pointerDown&&inside)Send("script-message","fua-native-button",sx,sy,"down");
  if(!down&&pointerDown)Send("script-message","fua-native-button",sx,sy,"up");
  pointerDown=down;
  bool rightDown=(GetAsyncKeyState(2)&0x8000)!=0;
  if(rightDown&&!rightPointerDown&&inside)Send("script-message","fua-native-context",sx,sy);
  rightPointerDown=rightDown;
  bool controls=inside&&(uiMenuOpen||ny>=590.0/720.0||ny<=100.0/720.0);
  if(inside){long now=DateTime.UtcNow.Ticks;bool reveal=!cursorHidden;
   if(controls||down){if(cursorHidden&&!down){if(cursorRevealAt==0)cursorRevealAt=now+TimeSpan.TicksPerMillisecond*50;reveal=now>=cursorRevealAt;}else reveal=true;if(reveal)cursorHideAt=now+TimeSpan.TicksPerMillisecond*300;}
   else if(cursorHidden){
    if(pointerMoved){if(cursorRevealAt==0){cursorRevealAt=now+TimeSpan.TicksPerMillisecond*50;cursorRevealOrigin=p;}cursorLastMotion=now;}
    if(now-cursorLastMotion>TimeSpan.TicksPerMillisecond*50)cursorRevealAt=0;
    int dx=p.X-cursorRevealOrigin.X,dy=p.Y-cursorRevealOrigin.Y;
    reveal=cursorRevealAt>0&&now>=cursorRevealAt&&(dx*dx+dy*dy>=16);
    if(reveal)cursorHideAt=now+TimeSpan.TicksPerMillisecond*300;
   }else{cursorRevealAt=0;if(pointerMoved||cursorHideAt==0)cursorHideAt=now+TimeSpan.TicksPerMillisecond*300;reveal=now<cursorHideAt;}
   if(reveal){SetCursor(LoadCursor(IntPtr.Zero,new IntPtr(32512)));cursorHidden=false;cursorRevealAt=0;}else{SetCursor(IntPtr.Zero);cursorHidden=true;}
  }else{cursorRevealAt=0;if(cursorHidden){SetCursor(LoadCursor(IntPtr.Zero,new IntPtr(32512)));cursorHidden=false;}}

 }
void TickPlayer(){uiMenuOpen=Get("user-data/fua-menu-open")=="true";for(int n=0;n<100;n++){IntPtr p=wait(mpv,0);Event ev=(Event)Marshal.PtrToStructure(p,typeof(Event));if(ev.id==0)break;if(ev.id==16){int count=Marshal.ReadInt32(ev.data);IntPtr argv=Marshal.ReadIntPtr(ev.data,8);if(count>=2 && Str(Marshal.ReadIntPtr(argv))=="fua-host")HandleUi(Str(Marshal.ReadIntPtr(argv,IntPtr.Size)));}if(ev.id==8){ready=true;if(resume>0){Send("seek",(resume/1000).ToString(System.Globalization.CultureInfo.InvariantCulture),"absolute+exact");resume=0;}Send("set","pause",startPaused?"yes":"no");}if(ev.id==7){ready=false;int err=Marshal.ReadInt32(ev.data,4);if(err<0)lastError="Falha ao reproduzir o arquivo: "+err;}if(ev.id==2){Log log=(Log)Marshal.PtrToStructure(ev.data,typeof(Log));string text=Str(log.text);if(text.IndexOf("NVIDIA RTX Video HDR enabled",StringComparison.OrdinalIgnoreCase)>=0)rtx="RTX HDR confirmado pelo mpv";if(text.IndexOf("Failed to enable NVIDIA RTX Video HDR",StringComparison.OrdinalIgnoreCase)>=0)rtx="RTX HDR indisponivel neste video";File.AppendAllText(Path.Combine(AppDomain.CurrentDomain.BaseDirectory,"native.log"),Str(log.prefix)+": "+text);}}
 if(ready&&!libraryMode&&Get("eof-reached")=="yes"){ShowLibrary();if(libraryReady)browser.CoreWebView2.ExecuteScriptAsync("setTimeout(()=>load(),3500)");}
 if(ready){double duration=Number("duration"),pos=Number("time-pos");if(!seeking&&duration>0)seek.Value=Math.Max(0,Math.Min(10000,(int)(pos/duration*10000)));string source=Get("video-params/gamma");info.Text=TimeSpan.FromSeconds(pos).ToString(@"hh\:mm\:ss")+" / "+TimeSpan.FromSeconds(duration).ToString(@"hh\:mm\:ss")+"   |   "+((source=="pq"||source=="hlg")?"Fonte HDR nativa":rtx);}
 if(++ticks%2==0)Emit();}
 void HandleUi(string action){if(action=="settings")AppSettings();if(action=="shortcuts")EditShortcuts();if(action.StartsWith("nav:")){string filter=action.Substring(4);if(new List<string>{"all","movie","tv","continue","video"}.Contains(filter)){ShowLibrary();browser.CoreWebView2.ExecuteScriptAsync("document.querySelector(\"nav button[data-filter=\\\""+filter+"\\\"]\").click()");}}if(action=="search"){ShowLibrary();browser.CoreWebView2.ExecuteScriptAsync("document.getElementById(\"search\").focus()");}if(action=="refresh-library"){browser.CoreWebView2.ExecuteScriptAsync("document.getElementById(\"scan\").click()");Send("show-text","Atualizando biblioteca...");}if(action=="library")ShowLibrary();if(action=="fullscreen")ToggleFull();if(action=="minimize")WindowState=FormWindowState.Minimized;if(action=="close")Close();if(action=="screenshot"){using(SaveFileDialog d=new SaveFileDialog()){d.Filter="PNG|*.png";d.FileName="Fua-frame.png";if(d.ShowDialog()==DialogResult.OK)Send("screenshot-to-file",d.FileName,"subtitles");}}if(action=="rtx"){rtxRequested=!rtxRequested;Send("vf",rtxRequested?"add":"remove",rtxRequested?"@fua-rtx:d3d11vpp=nvidia-true-hdr":"@fua-rtx");rtx=rtxRequested?"RTX HDR solicitado; aguardando confirmacao":"RTX HDR desligado";}}
void Emit(){if(mpv==IntPtr.Zero)return;if(lastHud!=rtx){lastHud=rtx;Send("script-message","fua-hdr",rtx);}Console.WriteLine(json.Serialize(new{connected=true,libraryReady=libraryReady,view=libraryMode?"library":"video",ready=ready,filepath=current,position=Number("time-pos")*1000,duration=Number("duration")*1000,updated=DateTimeOffset.UtcNow.ToUnixTimeMilliseconds(),hdr=rtx,filters=Get("vf"),outputGamma=Get("video-out-params/gamma"),sourceGamma=Get("video-params/gamma"),pointerX=lastPointer.X,pointerY=lastPointer.Y,pointerInside=lastPointerInside,paused=Get("pause"),statsPage=Get("user-data/fua-stats-page"),trackMenu=Get("user-data/fua-track-menu"),trackMenuState=Get("user-data/fua-track-menu-state"),feedback=Get("user-data/fua-feedback"),avsync=Get("avsync"),audioPts=Get("audio-pts"),audioCodec=Get("audio-codec-name"),contrast=Number("contrast"),brightness=Number("brightness"),gamma=Number("gamma"),saturation=Number("saturation"),audioTrack=Get("aid"),subtitleTrack=Get("sid"),audioLanguage=Get("user-data/fua-audio-language"),subtitleLanguage=Get("user-data/fua-sub-language"),subtitleForced=Get("user-data/fua-sub-forced"),fullscreen=full,windowState=WindowState.ToString(),windowWidth=Width,windowHeight=Height,volume=Number("volume"),controlsVisible=Get("user-data/fua-controls-visible"),error=string.IsNullOrEmpty(lastError)?null:lastError}));}
 [DllImport("user32.dll")]static extern bool SetProcessDpiAwarenessContext(IntPtr value);
 [STAThread] static void Main(string[] args){SetProcessDpiAwarenessContext(new IntPtr(-4));Console.SetIn(new StreamReader(Console.OpenStandardInput(),Encoding.UTF8));Console.SetOut(new StreamWriter(Console.OpenStandardOutput(),new UTF8Encoding(false)){AutoFlush=true});Application.EnableVisualStyles();Application.Run(new FuaNative(args));}
}















