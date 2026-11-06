using System;using System.IO;using System.Collections.Generic;using System.Drawing;using System.Windows.Forms;using System.Diagnostics;using System.Net;using System.Text;using System.Threading.Tasks;
partial class FuaNative {
 const string DefaultVideoConfig =
  "# Configurações avançadas do Fua Player. Uma opção por linha.\r\n"+
  "vo=gpu-next\r\ngpu-api=d3d11\r\ngpu-context=d3d11\r\nhwdec=d3d11va\r\n"+
  "scale=ewa_lanczossharp\r\ncscale=ewa_lanczossharp\r\ndscale=mitchell\r\n"+
  "tone-mapping=bt.2446a\r\ngamut-mapping-mode=perceptual\r\nhdr-compute-peak=yes\r\n"+
  "correct-downscaling=yes\r\nsigmoid-upscaling=yes\r\nlinear-downscaling=yes\r\n"+
  "deband=yes\r\ndeband-iterations=2\r\ndeband-threshold=48\r\ndeband-range=16\r\ndeband-grain=4\r\n"+
  "video-sync=audio\r\ncache=auto\r\ndemuxer-seekable-cache=no\r\n"+
  "demuxer-max-bytes=768MiB\r\ndemuxer-max-back-bytes=256MiB\r\n";
 Dictionary<string,string> ParseVideoConfig(string text){
  var allowed=new HashSet<string>();
  foreach(string line in DefaultVideoConfig.Split('\n')){
   int separator=line.IndexOf('=');
   if(separator>0)allowed.Add(line.Substring(0,separator).Trim());
  }
  var values=new Dictionary<string,string>();
  int number=0;
  foreach(string raw in text.Split('\n')){
   number++;
   string line=raw.Trim();
   if(line.Length==0||line.StartsWith("#"))continue;
   int separator=line.IndexOf('=');
   if(separator<1)throw new Exception("Linha "+number+": use opção=valor.");
   string name=line.Substring(0,separator).Trim(),value=line.Substring(separator+1).Trim();
   if(!allowed.Contains(name)||value.Length==0)throw new Exception("Opção inválida na linha "+number+": "+name);
   values[name]=value;
  }
  return values;
 }
 void ApplyAdvancedVideoConfig(){
  string file=DataFile("video-engine.conf");
  if(!File.Exists(file))return;
  try{
   foreach(var option in ParseVideoConfig(File.ReadAllText(file))){
    if(Set(option.Key,option.Value)<0)
     File.AppendAllText(DataFile("native.log"),"Configuração de vídeo recusada: "+option.Key+Environment.NewLine);
   }
  }catch(Exception error){File.AppendAllText(DataFile("native.log"),error.Message+Environment.NewLine);}
 }
 Dictionary<string,object> SubtitleSettings(){
  try{return json.Deserialize<Dictionary<string,object>>(File.ReadAllText(DataFile("subtitle-settings.json")));}
  catch{return new Dictionary<string,object>();}
 }
 void ApplySubtitleSettings(){
  if(mpv==IntPtr.Zero)return;
  var values=SubtitleSettings();
  Send("set","sub-ass-override","no");
  foreach(string property in new[]{"sub-font","sub-font-size","sub-color","sub-pos"})
   if(values.ContainsKey(property))Send("set",property,Convert.ToString(values[property],System.Globalization.CultureInfo.InvariantCulture));
 }
 sealed class SettingsButton : Button {
  bool hovered;
  public SettingsButton() {
   SetStyle(ControlStyles.UserPaint | ControlStyles.AllPaintingInWmPaint | ControlStyles.OptimizedDoubleBuffer, true);
   Cursor=Cursors.Hand;
  }
  protected override void OnMouseEnter(EventArgs e){hovered=true;Invalidate();base.OnMouseEnter(e);}
  protected override void OnMouseLeave(EventArgs e){hovered=false;Invalidate();base.OnMouseLeave(e);}
  protected override void OnPaint(PaintEventArgs e){
   e.Graphics.SmoothingMode=System.Drawing.Drawing2D.SmoothingMode.AntiAlias;
   e.Graphics.Clear(Parent==null?BackColor:Parent.BackColor);
   float inset=1.0f;
   float diameter=Math.Min(16f*DeviceDpi/96f,Height-3f);
   var bounds=new RectangleF(inset,inset,Width-3,Height-3);
   using(var shape=new System.Drawing.Drawing2D.GraphicsPath()){
    shape.AddArc(bounds.Left,bounds.Top,diameter,diameter,180,90);
    shape.AddArc(bounds.Right-diameter,bounds.Top,diameter,diameter,270,90);
    shape.AddArc(bounds.Right-diameter,bounds.Bottom-diameter,diameter,diameter,0,90);
    shape.AddArc(bounds.Left,bounds.Bottom-diameter,diameter,diameter,90,90);
    shape.CloseFigure();
    using(var fill=new SolidBrush(hovered?FlatAppearance.MouseOverBackColor:BackColor))
     e.Graphics.FillPath(fill,shape);
    using(var pen=new Pen(hovered?Color.FromArgb(143,205,243):Color.FromArgb(53,72,89),1f))
     e.Graphics.DrawPath(pen,shape);
   }
   var textBounds=ClientRectangle;
   textBounds.Inflate(-Padding.Left,-Padding.Top);
   TextRenderer.DrawText(e.Graphics,Text,Font,textBounds,Enabled?ForeColor:SystemColors.GrayText,
    TextFormatFlags.HorizontalCenter|TextFormatFlags.VerticalCenter|TextFormatFlags.WordBreak);
   if(Focused&&ShowFocusCues)ControlPaint.DrawFocusRectangle(e.Graphics,Rectangle.Inflate(ClientRectangle,-5,-5));
  }
 }
 string DataRoot {get{string root=Environment.GetEnvironmentVariable("FUA_DATA_DIR")??Path.GetFullPath(Path.Combine(AppDomain.CurrentDomain.BaseDirectory,"..","data"));Directory.CreateDirectory(root);return root;}}
 string DataFile(string name){return Path.Combine(DataRoot,name);}
 void Maintenance(string action){try{var request=(HttpWebRequest)WebRequest.Create("http://127.0.0.1:8780/api/maintenance/"+action);request.Method="POST";request.Headers["Origin"]="http://127.0.0.1:8780";request.ContentLength=0;request.Timeout=10000;using(var response=request.GetResponse()){} }catch{}}
 string ReadApiKey(string name){try{return Convert.ToString(json.Deserialize<Dictionary<string,object>>(File.ReadAllText(DataFile(name)))["key"]);}catch{return "";}}
 void SavePlayerPreferences(){if(mpv==IntPtr.Zero)return;try{var values=new Dictionary<string,object>();foreach(string key in new[]{"contrast","brightness","gamma","saturation","volume"})values[key]=Number(key);values["mute"]=Get("mute")=="yes";values["rtx"]=rtxRequested;File.WriteAllText(DataFile("player-settings.json"),json.Serialize(values));}catch{}}
 void LoadPlayerPreferences(){try{var values=json.Deserialize<Dictionary<string,object>>(File.ReadAllText(DataFile("player-settings.json")));foreach(string key in new[]{"contrast","brightness","gamma","saturation","volume"})if(values.ContainsKey(key)){double value=Convert.ToDouble(values[key]);value=Math.Max(key=="volume"?0:-100,Math.Min(100,value));Send("set",key,value.ToString(System.Globalization.CultureInfo.InvariantCulture));}if(values.ContainsKey("mute"))Send("set","mute",Convert.ToBoolean(values["mute"])?"yes":"no");if(values.ContainsKey("rtx"))rtxRequested=Convert.ToBoolean(values["rtx"]);if(hdrDisplay.HasValue)UpdateRtxFilter();}catch{}}
 void AppSettings(){bool paused=mpv!=IntPtr.Zero&&Get("pause")=="yes";if(mpv!=IntPtr.Zero)Send("set","pause","yes");
 using(var form=new Form()){float scale;using(var graphics=CreateGraphics())scale=graphics.DpiX/96f;var work=Screen.FromControl(this).WorkingArea;form.Text="Fua Player · Configurações";form.StartPosition=FormStartPosition.CenterParent;form.AutoScaleMode=AutoScaleMode.None;form.Size=new Size(Math.Min((int)(800*scale),(int)(work.Width*.9)),Math.Min((int)(590*scale),(int)(work.Height*.9)));form.Font=new Font("Segoe UI",10);form.Icon=Icon;form.MinimumSize=new Size(Math.Min((int)(760*scale),work.Width),Math.Min((int)(560*scale),work.Height));form.BackColor=Color.FromArgb(12,18,27);form.ForeColor=Color.White;form.MinimizeBox=false;form.MaximizeBox=false;
 var accent=Color.FromArgb(143,205,243);
 var muted=Color.FromArgb(155,174,194);
 var surface=Color.FromArgb(20,31,44);
 var host=new Panel{Dock=DockStyle.Fill};
 form.Controls.Add(host);
 var body=new Panel{Dock=DockStyle.Fill};form.Controls.Remove(host);body.Controls.Add(host);form.Controls.Add(body);
 var navigation=new FlowLayoutPanel{Dock=DockStyle.Left,Width=(int)(175*scale),FlowDirection=FlowDirection.TopDown,WrapContents=false,Padding=new Padding((int)(12*scale)),BackColor=Color.FromArgb(10,16,24)};
 body.Controls.Add(navigation);
 var heading=new Panel{Dock=DockStyle.Top,Height=(int)(86*scale)};
 heading.Controls.Add(new Label{Text="Configurações",AutoSize=true,Font=new Font("Segoe UI",18,FontStyle.Bold),ForeColor=Color.FromArgb(194,228,250),Location=new Point((int)(24*scale),(int)(12*scale))});
 heading.Controls.Add(new Label{Text="Personalize sua experiência no Fua Player",AutoSize=true,ForeColor=muted,Location=new Point((int)(26*scale),(int)(49*scale))});
 form.Controls.Add(heading);
 var actions=new FlowLayoutPanel{Dock=DockStyle.Bottom,Height=(int)(65*scale),Padding=new Padding((int)(20*scale),(int)(12*scale),0,0),BackColor=Color.FromArgb(10,16,24)};
 form.Controls.Add(actions);
 actions.BringToFront();
 navigation.BringToFront();
 heading.BringToFront();
 body.SendToBack();
 // Assign each region its own cell so DPI scaling cannot overlap them.
 var rootLayout=new TableLayoutPanel{Dock=DockStyle.Fill,ColumnCount=1,RowCount=3,Margin=Padding.Empty,Padding=Padding.Empty};
 rootLayout.ColumnStyles.Add(new ColumnStyle(SizeType.Percent,100));
 rootLayout.RowStyles.Add(new RowStyle(SizeType.Absolute,(int)(100*scale)));
 rootLayout.RowStyles.Add(new RowStyle(SizeType.Percent,100));
 rootLayout.RowStyles.Add(new RowStyle(SizeType.Absolute,(int)(70*scale)));
 form.Controls.Remove(heading);
 form.Controls.Remove(body);
 form.Controls.Remove(actions);
 heading.Dock=DockStyle.Fill;heading.Margin=Padding.Empty;
 body.Dock=DockStyle.Fill;body.Margin=Padding.Empty;
 actions.Dock=DockStyle.Fill;actions.Margin=Padding.Empty;
 rootLayout.Controls.Add(heading,0,0);
 rootLayout.Controls.Add(body,0,1);
 rootLayout.Controls.Add(actions,0,2);
 form.Controls.Add(rootLayout);
 var contentLayout=new TableLayoutPanel{Dock=DockStyle.Fill,ColumnCount=2,RowCount=1,Margin=Padding.Empty,Padding=Padding.Empty};
 contentLayout.ColumnStyles.Add(new ColumnStyle(SizeType.Absolute,(int)(175*scale)));
 contentLayout.ColumnStyles.Add(new ColumnStyle(SizeType.Percent,100));
 contentLayout.RowStyles.Add(new RowStyle(SizeType.Percent,100));
 body.Controls.Remove(navigation);
 body.Controls.Remove(host);
 navigation.Dock=DockStyle.Fill;navigation.Margin=Padding.Empty;navigation.AutoScroll=true;
 host.Dock=DockStyle.Fill;host.Margin=Padding.Empty;
 contentLayout.Controls.Add(navigation,0,0);
 contentLayout.Controls.Add(host,1,0);
 body.Controls.Add(contentLayout);
 var pages=new List<Panel>();
 var navigationButtons=new List<Button>();
 Func<string,Panel> tab=title=>{
  var page=new Panel{Dock=DockStyle.Fill,BackColor=form.BackColor,ForeColor=Color.White,Padding=new Padding((int)(22*scale)),AutoScroll=true,Visible=false};
  host.Controls.Add(page);
  pages.Add(page);
  var nav=new SettingsButton{Text=title,Width=(int)(150*scale),Height=(int)(48*scale),FlatStyle=FlatStyle.Flat,TextAlign=ContentAlignment.MiddleLeft,Padding=new Padding((int)(10*scale),0,0,0),Margin=new Padding(0,0,0,(int)(6*scale)),ForeColor=muted,BackColor=navigation.BackColor};
  nav.FlatAppearance.BorderSize=0;
  nav.FlatAppearance.MouseOverBackColor=surface;
  Action activate=()=>{
   for(int i=0;i<pages.Count;i++){
    bool active=pages[i]==page;
    pages[i].Visible=active;
    navigationButtons[i].BackColor=active?surface:navigation.BackColor;
    navigationButtons[i].ForeColor=active?accent:muted;
   }
   page.BringToFront();
  };
  nav.Click+=(sender,eventArgs)=>activate();
  navigationButtons.Add(nav);
  navigation.Controls.Add(nav);
  if(pages.Count==1)activate();
  return page;
 };
 Action<Control,string,Action> button=(parent,label,click)=>{var b=new SettingsButton{Text=label,AutoSize=true,Height=(int)(34*scale),FlatStyle=FlatStyle.Flat,BackColor=Color.FromArgb(26,42,58),ForeColor=Color.White};b.FlatAppearance.BorderSize=0;b.FlatAppearance.MouseOverBackColor=Color.FromArgb(39,66,89);b.Padding=new Padding((int)(10*scale),(int)(5*scale),(int)(10*scale),(int)(5*scale));b.Margin=new Padding(0,0,(int)(7*scale),0);if(label=="Salvar e fechar"){b.Font=new Font("Segoe UI Semibold",10f,FontStyle.Regular);b.BackColor=accent;b.ForeColor=Color.FromArgb(12,28,40);b.FlatAppearance.MouseOverBackColor=Color.FromArgb(185,226,252);}b.Click+=(s,e)=>click();parent.Controls.Add(b);};
 var library=tab("Biblioteca");var grid=new DataGridView{Dock=DockStyle.Fill,ReadOnly=true,AllowUserToAddRows=false,AllowUserToDeleteRows=false,RowHeadersVisible=false,SelectionMode=DataGridViewSelectionMode.FullRowSelect,MultiSelect=false,AutoSizeColumnsMode=DataGridViewAutoSizeColumnsMode.Fill,BackgroundColor=form.BackColor,BorderStyle=BorderStyle.None,CellBorderStyle=DataGridViewCellBorderStyle.SingleHorizontal,ColumnHeadersBorderStyle=DataGridViewHeaderBorderStyle.None,GridColor=Color.FromArgb(37,50,66),EnableHeadersVisualStyles=false};grid.Columns.Add("category","Tipo");grid.Columns.Add("path","Pasta");grid.Columns[0].FillWeight=25;grid.Columns[1].FillWeight=75;grid.RowTemplate.Height=(int)(42*scale);grid.ColumnHeadersHeight=(int)(38*scale);grid.DefaultCellStyle.Padding=new Padding((int)(8*scale),0,0,0);grid.ColumnHeadersDefaultCellStyle.Padding=new Padding((int)(8*scale),0,0,0);grid.ColumnHeadersDefaultCellStyle.BackColor=Color.FromArgb(25,38,53);grid.ColumnHeadersDefaultCellStyle.ForeColor=muted;grid.AlternatingRowsDefaultCellStyle.BackColor=Color.FromArgb(15,23,33);grid.DefaultCellStyle.BackColor=form.BackColor;grid.DefaultCellStyle.ForeColor=Color.White;grid.DefaultCellStyle.SelectionBackColor=Color.FromArgb(36,66,88);library.Controls.Add(grid);
 try{var settings=json.Deserialize<Dictionary<string,object>>(File.ReadAllText(DataFile("settings.json")));foreach(var entry in (System.Collections.IEnumerable)settings["folders"]){var folder=(Dictionary<string,object>)entry;grid.Rows.Add(Convert.ToString(folder["category"])=="series"?"Séries":"Filmes",Convert.ToString(folder["path"]));}}catch{}
 var folderButtons=new FlowLayoutPanel{Dock=DockStyle.Top,Height=(int)(55*scale)};library.Controls.Add(folderButtons);foreach(string category in new[]{"Filmes","Séries"}){string type=category;button(folderButtons,"Adicionar "+type,()=>{using(var dialog=new FolderBrowserDialog{Description="Escolha a pasta de "+type})if(dialog.ShowDialog(form)==DialogResult.OK)grid.Rows.Add(type,dialog.SelectedPath);});}button(folderButtons,"Remover pasta",()=>{if(grid.CurrentRow!=null)grid.Rows.Remove(grid.CurrentRow);});
 var api=tab("APIs");var apiLayout=new TableLayoutPanel{Dock=DockStyle.Top,ColumnCount=2,RowCount=3,AutoSize=true,Padding=new Padding(0,(int)(8*scale),0,0)};apiLayout.ColumnStyles.Add(new ColumnStyle(SizeType.Percent,25));apiLayout.ColumnStyles.Add(new ColumnStyle(SizeType.Percent,75));api.Controls.Add(apiLayout);var tmdb=new TextBox{Text=ReadApiKey("tmdb-secret.json"),UseSystemPasswordChar=true,Dock=DockStyle.Fill,BorderStyle=BorderStyle.FixedSingle,BackColor=surface,ForeColor=Color.FromArgb(218,233,246),Margin=new Padding(0,0,0,(int)(16*scale))};var omdb=new TextBox{Text=ReadApiKey("omdb-secret.json"),UseSystemPasswordChar=true,Dock=DockStyle.Fill,BorderStyle=BorderStyle.FixedSingle,BackColor=surface,ForeColor=Color.FromArgb(218,233,246),Margin=new Padding(0,0,0,(int)(16*scale))};apiLayout.Controls.Add(new Label{Text="TMDB",AutoSize=true},0,0);apiLayout.Controls.Add(tmdb,1,0);apiLayout.Controls.Add(new Label{Text="OMDb (opcional)",AutoSize=true},0,1);apiLayout.Controls.Add(omdb,1,1);apiLayout.Controls.Add(new Label{Text="As chaves ficam somente nos dados locais do aplicativo.",AutoSize=true,Padding=new Padding(0,(int)(18*scale),0,0)},0,2);apiLayout.SetColumnSpan(apiLayout.GetControlFromPosition(0,2),2);
 var subtitles=tab("Legendas");
 var subtitleValues=SubtitleSettings();
 var subtitleLayout=new TableLayoutPanel{Dock=DockStyle.Top,ColumnCount=2,AutoSize=true,RowCount=0};
 subtitleLayout.ColumnStyles.Add(new ColumnStyle(SizeType.Percent,45));
 subtitleLayout.ColumnStyles.Add(new ColumnStyle(SizeType.Percent,55));
 subtitles.Controls.Add(subtitleLayout);
 Action<string,Control> subtitleField=(label,control)=>{
  int row=subtitleLayout.RowCount++;
  control.Dock=DockStyle.Fill;
  control.Margin=new Padding(0,(int)(7*scale),0,(int)(7*scale));
  control.BackColor=surface;
  control.ForeColor=Color.White;
  subtitleLayout.Controls.Add(new Label{Text=label,AutoSize=true,Padding=new Padding(0,(int)(10*scale),0,(int)(10*scale))},0,row);
  subtitleLayout.Controls.Add(control,1,row);
 };
 var subtitleFont=new ComboBox{DropDownStyle=ComboBoxStyle.DropDownList,FlatStyle=FlatStyle.Flat};
 using(var fonts=new System.Drawing.Text.InstalledFontCollection())
  foreach(var family in fonts.Families)subtitleFont.Items.Add(family.Name);
 string savedFont=subtitleValues.ContainsKey("sub-font")?Convert.ToString(subtitleValues["sub-font"]):"sans-serif";
 subtitleFont.SelectedItem=savedFont;
 if(subtitleFont.SelectedIndex<0){
  subtitleFont.Items.Add(savedFont);
  subtitleFont.SelectedItem=savedFont;
 }
 subtitleField("Fonte",subtitleFont);
 var subtitleSize=new NumericUpDown{Minimum=12,Maximum=100,Value=55,BorderStyle=BorderStyle.FixedSingle};
 decimal savedSize;
 if(subtitleValues.ContainsKey("sub-font-size")&&decimal.TryParse(Convert.ToString(subtitleValues["sub-font-size"]),out savedSize))
  subtitleSize.Value=Math.Max(12,Math.Min(100,savedSize));
 subtitleField("Tamanho",subtitleSize);
 var subtitlePosition=new NumericUpDown{Minimum=0,Maximum=100,Value=100,BorderStyle=BorderStyle.FixedSingle};
 decimal savedPosition;
 if(subtitleValues.ContainsKey("sub-pos")&&decimal.TryParse(Convert.ToString(subtitleValues["sub-pos"]),out savedPosition))
  subtitlePosition.Value=Math.Max(0,Math.Min(100,savedPosition));
 subtitleField("Posição · 0 acima, 100 abaixo",subtitlePosition);
 Color subtitleColor=Color.White;
 if(subtitleValues.ContainsKey("sub-color")){
  try{subtitleColor=ColorTranslator.FromHtml(Convert.ToString(subtitleValues["sub-color"]));}catch{}
 }
 var colorActions=new FlowLayoutPanel{AutoSize=true};
 button(colorActions,"Escolher cor",()=>{
  using(var picker=new ColorDialog{Color=subtitleColor,FullOpen=true})
   if(picker.ShowDialog(form)==DialogResult.OK){subtitleColor=picker.Color;colorActions.BackColor=subtitleColor;}
 });
 colorActions.BackColor=subtitleColor;
 subtitleField("Cor",colorActions);
 var subtitleDelay=new NumericUpDown{Minimum=-600,Maximum=600,DecimalPlaces=1,Increment=.1m,Value=(decimal)Math.Max(-600,Math.Min(600,mpv==IntPtr.Zero?0:Number("sub-delay"))),BorderStyle=BorderStyle.FixedSingle};
 subtitleField("Sincronização (segundos)",subtitleDelay);
 var delayKeys=new List<string>();
 foreach(var shortcut in shortcuts)
  if(shortcut.Id=="subtitle-earlier"||shortcut.Id=="subtitle-later")delayKeys.Add(shortcut.Label+" · "+KeyLabel(shortcut.Key));
 var delayHelp=new Label{Text="Negativo adianta a legenda. Positivo atrasa.\n"+string.Join("\n",delayKeys.ToArray())+"\nEdite os atalhos com Ctrl+K no player. O sincronismo também se aplica a ASS.",AutoSize=true,MaximumSize=new Size((int)(440*scale),0),ForeColor=muted};
 delayHelp.Text=delayHelp.Text.Replace("\n",Environment.NewLine);
 subtitleLayout.Controls.Add(delayHelp,0,subtitleLayout.RowCount++);
 subtitleLayout.SetColumnSpan(delayHelp,2);
 var subtitleNote=new Label{Text="Estes ajustes se aplicam às legendas de texto simples, como SRT. Legendas ASS mantêm a fonte, as cores e a posição definidas pelo autor.",AutoSize=true,MaximumSize=new Size((int)(450*scale),0),ForeColor=muted,Padding=new Padding(0,(int)(18*scale),0,0)};
 subtitleLayout.Controls.Add(subtitleNote,0,subtitleLayout.RowCount++);
 subtitleLayout.SetColumnSpan(subtitleNote,2);
 var videoSettings=tab("Vídeo");
 var engineInfo=new TextBox{Dock=DockStyle.Fill,Multiline=true,ReadOnly=true,ScrollBars=ScrollBars.Vertical,BorderStyle=BorderStyle.None,BackColor=form.BackColor,ForeColor=Color.FromArgb(207,225,240),Font=new Font("Segoe UI",10)};
 var lines=new List<string>{"Motor de vídeo · libmpv","Configurações atuais do player",""};
 if(mpv!=IntPtr.Zero){
  foreach(var entry in new[]{
   new[]{"Versão","mpv-version"},new[]{"Saída de vídeo","vo"},new[]{"API gráfica","gpu-api"},
   new[]{"Contexto gráfico","gpu-context"},new[]{"Decodificação configurada","hwdec"},
   new[]{"Decodificação ativa","hwdec-current"},new[]{"Ampliação","scale"},new[]{"Escala de cor","cscale"},
   new[]{"Redução","dscale"},new[]{"Mapeamento de tons","tone-mapping"},new[]{"Mapeamento de cores","gamut-mapping-mode"},
   new[]{"Transferência de saída","target-trc"},new[]{"Pico de brilho","target-peak"},
   new[]{"Detecção de pico HDR","hdr-compute-peak"},new[]{"Redução de faixas de cor","deband"},
   new[]{"Sincronização de vídeo","video-sync"},new[]{"Shaders ativos","glsl-shaders"},
   new[]{"Filtros ativos","vf"},new[]{"Cache","cache"},new[]{"Buffer máximo","demuxer-max-bytes"}
  }){
   string value=Get(entry[1]);
   lines.Add(entry[0]+" · "+(string.IsNullOrEmpty(value)?"Indisponível no momento":value));
  }
  lines.Add("");lines.Add("RTX HDR · "+rtx);
 }
 engineInfo.Text=string.Join(Environment.NewLine,lines.ToArray());
 videoSettings.Controls.Add(engineInfo);
 var videoEditor=new TextBox{Dock=DockStyle.Fill,Multiline=true,AcceptsReturn=true,AcceptsTab=true,ScrollBars=ScrollBars.Both,WordWrap=false,Visible=false,BorderStyle=BorderStyle.None,BackColor=surface,ForeColor=Color.FromArgb(207,225,240),Font=new Font("Consolas",10)};
 videoEditor.Text=File.Exists(DataFile("video-engine.conf"))?File.ReadAllText(DataFile("video-engine.conf")):DefaultVideoConfig;
 videoSettings.Controls.Add(videoEditor);
 var videoButtons=new FlowLayoutPanel{Dock=DockStyle.Bottom,Height=(int)(60*scale),Padding=new Padding(0,(int)(10*scale),0,0)};
 bool videoEdited=false;
 button(videoButtons,"Editar",()=>{
  videoEdited=true;engineInfo.Visible=false;videoEditor.Visible=true;videoEditor.BringToFront();videoEditor.Focus();
 });
 button(videoButtons,"Restaurar padrão",()=>{
  videoEdited=true;videoEditor.Text=DefaultVideoConfig;engineInfo.Visible=false;videoEditor.Visible=true;videoEditor.BringToFront();
 });
 button(videoButtons,"OK",()=>{
  try{
   ParseVideoConfig(videoEditor.Text);
   if(videoEdited){
    engineInfo.Text="Configuração editada · aguardando salvar"+Environment.NewLine+Environment.NewLine+videoEditor.Text;
   }
   videoEditor.Visible=false;
   engineInfo.Visible=true;
   engineInfo.BringToFront();
  }catch(Exception error){
   MessageBox.Show(form,error.Message,"Revise a configuração",MessageBoxButtons.OK,MessageBoxIcon.Information);
   videoEditor.Focus();
  }
 });
 videoSettings.Controls.Add(videoButtons);
 videoButtons.BringToFront();
 var videoHelp=new Label{Dock=DockStyle.Top,Height=(int)(45*scale),Text="Edite opção=valor. Salve e reabra o Fua Player para aplicar. Linhas com # são comentários.",ForeColor=muted};
 videoSettings.Controls.Add(videoHelp);
 videoHelp.BringToFront();
 var videoLayout=new TableLayoutPanel{Dock=DockStyle.Fill,ColumnCount=1,RowCount=3,Margin=Padding.Empty,Padding=Padding.Empty};
 videoLayout.ColumnStyles.Add(new ColumnStyle(SizeType.Percent,100));
 videoLayout.RowStyles.Add(new RowStyle(SizeType.AutoSize));
 videoLayout.RowStyles.Add(new RowStyle(SizeType.Percent,100));
 videoLayout.RowStyles.Add(new RowStyle(SizeType.Absolute,(int)(64*scale)));
 videoSettings.Controls.Remove(videoHelp);
 videoSettings.Controls.Remove(videoButtons);
 videoSettings.Controls.Remove(engineInfo);
 videoSettings.Controls.Remove(videoEditor);
 var videoTextArea=new Panel{Dock=DockStyle.Fill,Margin=new Padding(0,(int)(12*scale),0,(int)(12*scale))};
 videoTextArea.Controls.Add(engineInfo);
 videoTextArea.Controls.Add(videoEditor);
 videoHelp.AutoSize=true;videoHelp.MaximumSize=new Size((int)(540*scale),0);videoHelp.Dock=DockStyle.Fill;videoHelp.Margin=Padding.Empty;
 videoButtons.Dock=DockStyle.Fill;videoButtons.Margin=Padding.Empty;
 videoLayout.Controls.Add(videoHelp,0,0);
 videoLayout.Controls.Add(videoTextArea,0,1);
 videoLayout.Controls.Add(videoButtons,0,2);
 videoSettings.Controls.Add(videoLayout);
 videoSettings.AutoScroll=false;
 var previewPage=tab("Prévia e histórico");var previewConfig=PreviewSettings();var previewLayout=new TableLayoutPanel{Dock=DockStyle.Top,ColumnCount=2,AutoSize=true,RowCount=0};previewLayout.ColumnStyles.Add(new ColumnStyle(SizeType.Percent,65));previewLayout.ColumnStyles.Add(new ColumnStyle(SizeType.Percent,35));previewPage.Controls.Add(previewLayout);var previewFields=new Dictionary<string,NumericUpDown>();
 Action<string,string,int,int,int> number=(key,label,initial,min,max)=>{int row=previewLayout.RowCount++;var value=new NumericUpDown{Minimum=min,Maximum=max,Value=PreviewLimit(previewConfig,key,initial,min,max),Dock=DockStyle.Fill,Margin=new Padding((int)(12*scale),(int)(7*scale),0,(int)(7*scale)),BorderStyle=BorderStyle.FixedSingle,BackColor=Color.FromArgb(26,42,58),ForeColor=Color.White};previewFields[key]=value;previewLayout.Controls.Add(new Label{Text=label,AutoSize=true,Padding=new Padding(0,8,0,8)},0,row);previewLayout.Controls.Add(value,1,row);};
 number("maxMedia","Mídias no cache de capas locais",10,1,100);number("idleSeconds","Liberar prévia após inatividade (segundos)",30,5,300);number("maxHistoryMedia","Vídeos externos com retomada guardada",200,10,10000);
 var previewNote=new Label{Dock=DockStyle.Bottom,Height=(int)(100*scale),Text="A barra usa Thumbfast e mantém apenas uma imagem temporária.\nA retomada dos vídeos externos é guardada separadamente.\nAlterações da prévia passam a valer ao reabrir o player."};previewPage.Controls.Add(previewNote);
 var shortcutPage=tab("Teclas de atalho");
 var saveShortcutSettings=BuildShortcutSettings(form,shortcutPage,scale);
 button(actions,"Salvar e fechar",()=>{try{if(videoEdited){ParseVideoConfig(videoEditor.Text);}saveShortcutSettings();Maintenance("flush");var folders=new List<object>();foreach(DataGridViewRow row in grid.Rows)folders.Add(new{category=Convert.ToString(row.Cells[0].Value)=="Séries"?"series":"filmes",path=Convert.ToString(row.Cells[1].Value)});File.WriteAllText(DataFile("settings.json"),json.Serialize(new{folders=folders}));File.WriteAllText(DataFile("tmdb-secret.json"),json.Serialize(new{key=tmdb.Text.Trim()}));File.WriteAllText(DataFile("omdb-secret.json"),json.Serialize(new{key=omdb.Text.Trim()}));foreach(var field in previewFields)previewConfig[field.Key]=Convert.ToInt32(field.Value.Value);File.WriteAllText(DataFile("preview-settings.json"),json.Serialize(previewConfig));if(videoEdited){string temp=DataFile("video-engine.conf.tmp");File.WriteAllText(temp,videoEditor.Text);File.Copy(temp,DataFile("video-engine.conf"),true);File.Delete(temp);}File.WriteAllText(DataFile("subtitle-settings.json"),json.Serialize(new Dictionary<string,object>{{"sub-font",Convert.ToString(subtitleFont.SelectedItem)},{"sub-font-size",Convert.ToInt32(subtitleSize.Value)},{"sub-pos",Convert.ToInt32(subtitlePosition.Value)},{"sub-color",ColorTranslator.ToHtml(subtitleColor)}}));ApplySubtitleSettings();if(mpv!=IntPtr.Zero)Send("set","sub-delay",subtitleDelay.Value.ToString(System.Globalization.CultureInfo.InvariantCulture));Maintenance("reload");form.Close();}catch(Exception ex){MessageBox.Show(form,ex.Message,"Não foi possível salvar");}});button(actions,"Cancelar",()=>form.Close());uint darkMode=1;DwmSetWindowAttribute(form.Handle,20,ref darkMode,sizeof(uint));form.ShowDialog(this);
 }if(mpv!=IntPtr.Zero)Send("set","pause",paused?"yes":"no");if(libraryReady)browser.CoreWebView2.ExecuteScriptAsync("lastSignature='';load()");}
}
