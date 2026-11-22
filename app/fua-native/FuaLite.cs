using System;using System.IO;using System.Drawing;using System.Windows.Forms;using System.Collections.Generic;using System.Threading.Tasks;
// Native playback build: no WebView2 assembly or local web service.
sealed class FuaLiteSurface:Panel {
 public Color DefaultBackgroundColor{get;set;}
 public readonly FuaLiteNoWeb CoreWebView2=new FuaLiteNoWeb();
}
sealed class FuaLiteNoWeb {
 public void PostWebMessageAsString(string message){}
 public Task<string> ExecuteScriptAsync(string script){return Task.FromResult("");}
}
partial class FuaNative {
 Panel liteStart;
 sealed class LiteCloseButton:Button {
  bool hover;
  public LiteCloseButton(){SetStyle(ControlStyles.UserPaint|ControlStyles.OptimizedDoubleBuffer|ControlStyles.AllPaintingInWmPaint,true);Cursor=Cursors.Hand;AccessibleName="Fechar Fua Player Lite";TabStop=true;}
  protected override void OnMouseEnter(EventArgs e){hover=true;Invalidate();base.OnMouseEnter(e);}
  protected override void OnMouseLeave(EventArgs e){hover=false;Invalidate();base.OnMouseLeave(e);}
  protected override void OnPaint(PaintEventArgs e){e.Graphics.Clear(hover?Color.FromArgb(163,43,57):Parent.BackColor);e.Graphics.SmoothingMode=System.Drawing.Drawing2D.SmoothingMode.AntiAlias;float cx=Width/2f,cy=Height/2f,r=6f*DeviceDpi/96f;using(var pen=new Pen(Color.FromArgb(218,234,244),1.7f*DeviceDpi/96f)){e.Graphics.DrawLine(pen,cx-r,cy-r,cx+r,cy+r);e.Graphics.DrawLine(pen,cx+r,cy-r,cx-r,cy+r);}if(Focused)ControlPaint.DrawFocusRectangle(e.Graphics,Rectangle.Inflate(ClientRectangle,-5,-5));}
 }
 sealed class LiteWelcomePanel:Panel {
  readonly Image logo;readonly SettingsButton open;readonly LiteCloseButton close;readonly Label edition,hint;
  public LiteWelcomePanel(Action pick,Action exit){
   Dock=DockStyle.Fill;BackColor=Color.FromArgb(10,16,23);AllowDrop=true;DoubleBuffered=true;
   using(var stream=typeof(FuaNative).Assembly.GetManifestResourceStream("FuaLiteLogo")){using(var image=Image.FromStream(stream))logo=new Bitmap(image);}
   open=new SettingsButton{Text="Abrir vídeo",AccessibleName="Abrir vídeo",Font=new Font("Segoe UI",16,FontStyle.Regular,GraphicsUnit.Pixel),BackColor=Color.FromArgb(26,42,58),ForeColor=Color.White};open.FlatAppearance.MouseOverBackColor=Color.FromArgb(38,60,81);open.Click+=(s,e)=>pick();
   close=new LiteCloseButton();close.Click+=(s,e)=>exit();
   edition=new Label{Text="L I T E",Font=new Font("Segoe UI",12,FontStyle.Bold,GraphicsUnit.Pixel),ForeColor=Color.FromArgb(140,177,200),TextAlign=ContentAlignment.MiddleCenter};
   hint=new Label{Text="Arraste um vídeo para a janela ou use Ctrl+O",Font=new Font("Segoe UI",14,FontStyle.Regular,GraphicsUnit.Pixel),ForeColor=Color.FromArgb(155,174,194),TextAlign=ContentAlignment.MiddleCenter};
   Controls.Add(open);Controls.Add(close);Controls.Add(edition);Controls.Add(hint);Resize+=(s,e)=>{Arrange();Invalidate();};
  }
  Rectangle LogoBounds(){float scale=DeviceDpi/96f;int w=Math.Min((int)(460*scale),ClientSize.Width-80);int h=(int)Math.Round(w*207D/870);int top=(ClientSize.Height-(h+(int)(170*scale)))/2;return new Rectangle((ClientSize.Width-w)/2,Math.Max((int)(60*scale),top),w,h);}
  void Arrange(){float scale=DeviceDpi/96f;Rectangle b=LogoBounds();edition.SetBounds(b.Left,b.Bottom+(int)(13*scale),b.Width,(int)(25*scale));open.SetBounds((ClientSize.Width-(int)(180*scale))/2,edition.Bottom+(int)(30*scale),(int)(180*scale),(int)(44*scale));hint.SetBounds(12,open.Bottom+(int)(20*scale),ClientSize.Width-24,(int)(32*scale));close.SetBounds(ClientSize.Width-(int)(48*scale),0,(int)(48*scale),(int)(42*scale));}
  protected override void OnPaint(PaintEventArgs e){base.OnPaint(e);e.Graphics.InterpolationMode=System.Drawing.Drawing2D.InterpolationMode.HighQualityBicubic;e.Graphics.DrawImage(logo,LogoBounds());}
  protected override void Dispose(bool disposing){if(disposing)logo.Dispose();base.Dispose(disposing);}
 }
 void PlayLibraryEpisode(string id){}
 void PickLiteFile(){using(var dialog=new OpenFileDialog()){dialog.Filter="Vídeos|*.mkv;*.mp4;*.avi;*.webm;*.mov;*.m4v;*.ts;*.m2ts;*.wmv|Todos os arquivos|*.*";if(dialog.ShowDialog(this)==DialogResult.OK)Open(dialog.FileName,0);}}
 void ShowLiteStart(){
  if(full)ToggleFull();FormBorderStyle=FormBorderStyle.None;MinimumSize=new Size(600,360);SetVideoWindowSize(1280,720);
  SaveExternal();CloseCast();if(mpv!=IntPtr.Zero){Send("stop");Send("script-message","fua-stats-close");}
  ready=false;current="";fitExternalWindow=false;libraryMode=false;Text=AppTitle;playback.Visible=false;browser.Visible=false;
  if(liteStart==null){
   var welcome=new LiteWelcomePanel(()=>PickLiteFile(),()=>Close());liteStart=welcome;
   Controls.Add(liteStart);AllowDrop=true;
   DragEventHandler enter=(s,e)=>{if(e.Data.GetDataPresent(DataFormats.FileDrop))e.Effect=DragDropEffects.Copy;};
   DragEventHandler drop=(s,e)=>{var files=e.Data.GetData(DataFormats.FileDrop)as string[];if(files!=null&&files.Length>0&&File.Exists(files[0]))Open(files[0],0);};
   DragEnter+=enter;DragDrop+=drop;liteStart.DragEnter+=enter;liteStart.DragDrop+=drop;
  }
  liteStart.Visible=true;liteStart.BringToFront();FrontWindow();
 }
 protected override bool ProcessCmdKey(ref Message message,Keys key){if(LiteMode&&!ready&&key==(Keys.Control|Keys.O)){PickLiteFile();return true;}return base.ProcessCmdKey(ref message,key);}
 void AppSettings(string initialPage=null){
  bool paused=Get("pause")=="yes";Send("set","pause","yes");
  using(var form=new Form{Text=AppTitle+" · Configurações",StartPosition=FormStartPosition.CenterParent,Size=new Size(740,590),MinimumSize=new Size(600,470),BackColor=Color.FromArgb(12,18,27),ForeColor=Color.White,Font=new Font("Segoe UI",10),MinimizeBox=false,MaximizeBox=false}){
   var tabs=new TabControl{Dock=DockStyle.Fill};form.Controls.Add(tabs);var buttons=new FlowLayoutPanel{Dock=DockStyle.Bottom,Height=48,FlowDirection=FlowDirection.RightToLeft};form.Controls.Add(buttons);buttons.BringToFront();
   var video=new TabPage("Vídeo"){BackColor=form.BackColor,ForeColor=Color.White};tabs.TabPages.Add(video);
   var modes=new ComboBox{Dock=DockStyle.Top,DropDownStyle=ComboBoxStyle.DropDownList};modes.Items.AddRange(new object[]{"Automático · HDR direto quando disponível","HDR direto · processamento pela TV","HDR processado pelo Player"});modes.SelectedIndex=hdrOutputMode=="direct"?1:hdrOutputMode=="processed"?2:0;
   var editor=new TextBox{Dock=DockStyle.Fill,Multiline=true,ReadOnly=true,ScrollBars=ScrollBars.Vertical,WordWrap=true,BackColor=Color.FromArgb(26,42,58),ForeColor=Color.FromArgb(207,225,240),Font=new Font("Consolas",10),Text=File.Exists(DataFile("video-engine.conf"))?File.ReadAllText(DataFile("video-engine.conf")):DefaultVideoConfig};editor.Text=editor.Text.Replace("# Configurações avançadas do Fua Player. Uma opção por linha.","# Advanced Player configuration. One option per line.");
   var videoActions=new FlowLayoutPanel{Dock=DockStyle.Bottom,Height=46};
   var edit=new SettingsButton{Text="Editar",Width=100,Height=34,BackColor=Color.FromArgb(26,42,58),ForeColor=Color.White};edit.Click+=(s,e)=>{editor.ReadOnly=false;editor.Focus();};videoActions.Controls.Add(edit);
   var defaults=new SettingsButton{Text="Restaurar padrão",Width=150,Height=34,BackColor=edit.BackColor,ForeColor=Color.White};defaults.Click+=(s,e)=>{editor.Text=DefaultVideoConfig;editor.ReadOnly=false;editor.Focus();};videoActions.Controls.Add(defaults);
   var apply=new SettingsButton{Text="OK",Width=70,Height=34,BackColor=edit.BackColor,ForeColor=Color.White};apply.Click+=(s,e)=>{try{ParseVideoConfig(editor.Text);editor.ReadOnly=true;}catch(Exception error){MessageBox.Show(form,error.Message,"Revise a configuração");}};videoActions.Controls.Add(apply);
   var help=new Label{Dock=DockStyle.Top,Height=55,Text="Edite opção=valor. Salve e reabra o Player para aplicar. Linhas com # são comentários.",Padding=new Padding(0,8,0,0)};
   video.Controls.Add(editor);video.Controls.Add(videoActions);video.Controls.Add(help);video.Controls.Add(modes);
   var subtitle=new TabPage("Legendas"){BackColor=form.BackColor,ForeColor=Color.White};tabs.TabPages.Add(subtitle);var table=new TableLayoutPanel{Dock=DockStyle.Top,ColumnCount=2,AutoSize=true,Padding=new Padding(16)};table.ColumnStyles.Add(new ColumnStyle(SizeType.Percent,55));table.ColumnStyles.Add(new ColumnStyle(SizeType.Percent,45));subtitle.Controls.Add(table);
   var values=SubtitleSettings();var font=new ComboBox{DropDownStyle=ComboBoxStyle.DropDownList,Width=210};foreach(var family in FontFamily.Families)font.Items.Add(family.Name);font.SelectedItem=values.ContainsKey("sub-font")?Convert.ToString(values["sub-font"]):"Segoe UI";if(font.SelectedIndex<0)font.SelectedItem="Arial";
   var size=new NumericUpDown{Minimum=10,Maximum=100,Value=values.ContainsKey("sub-font-size")?Math.Max(10,Math.Min(100,Convert.ToDecimal(values["sub-font-size"]))):36};
   var position=new NumericUpDown{Minimum=0,Maximum=100,Value=values.ContainsKey("sub-pos")?Math.Max(0,Math.Min(100,Convert.ToDecimal(values["sub-pos"]))):100};
   var delay=new NumericUpDown{Minimum=-120,Maximum=120,DecimalPlaces=1,Increment=.1M,Value=(decimal)Math.Max(-120,Math.Min(120,Number("sub-delay")))};
   Color color=Color.White;try{if(values.ContainsKey("sub-color"))color=ColorTranslator.FromHtml(Convert.ToString(values["sub-color"]));}catch{}
   var colorButton=new Button{Text="Escolher cor",AutoSize=true,BackColor=Color.FromArgb(32,48,64),ForeColor=Color.White};colorButton.Click+=(s,e)=>{using(var d=new ColorDialog{Color=color})if(d.ShowDialog(form)==DialogResult.OK)color=d.Color;};
   string[] labels={"Fonte","Tamanho","Posição vertical","Atraso (segundos)","Cor"};Control[] fields={font,size,position,delay,colorButton};for(int i=0;i<fields.Length;i++){table.Controls.Add(new Label{Text=labels[i],AutoSize=true,Margin=new Padding(5,10,5,10)},0,i);table.Controls.Add(fields[i],1,i);}
   var preview=new TabPage("Prévia"){BackColor=form.BackColor,ForeColor=Color.White};tabs.TabPages.Add(preview);var previewValues=PreviewSettings();var width=new NumericUpDown{Minimum=160,Maximum=1280,Value=PreviewLimit(previewValues,"width",480,160,1280),Location=new Point(24,60)};preview.Controls.Add(new Label{Text="Largura da miniatura de prévia (pixels)",AutoSize=true,Location=new Point(24,24)});preview.Controls.Add(width);
   var shortcut=new TabPage("Atalhos"){BackColor=form.BackColor};tabs.TabPages.Add(shortcut);Action saveKeys=BuildShortcutSettings(form,shortcut,1);
   if(initialPage=="Legendas")tabs.SelectedTab=subtitle;
   var cancel=new Button{Text="Cancelar",AutoSize=true};cancel.Click+=(s,e)=>form.Close();buttons.Controls.Add(cancel);
   var save=new Button{Text="Salvar e fechar",AutoSize=true};save.Click+=(s,e)=>{try{ParseVideoConfig(editor.Text);saveKeys();File.WriteAllText(DataFile("video-engine.conf"),editor.Text);File.WriteAllText(DataFile("subtitle-settings.json"),json.Serialize(new Dictionary<string,object>{{"sub-font",Convert.ToString(font.SelectedItem)},{"sub-font-size",(int)size.Value},{"sub-pos",(int)position.Value},{"sub-color",string.Format("#{0:X2}{1:X2}{2:X2}",color.R,color.G,color.B)}}));previewValues["width"]=(int)width.Value;File.WriteAllText(DataFile("preview-settings.json"),json.Serialize(previewValues));SetHdrOutputMode(modes.SelectedIndex==1?"direct":modes.SelectedIndex==2?"processed":"auto");ApplySubtitleSettings();Send("set","sub-delay",delay.Value.ToString(System.Globalization.CultureInfo.InvariantCulture));form.Close();}catch(Exception ex){MessageBox.Show(form,ex.Message,"Configurações");}};buttons.Controls.Add(save);form.ShowDialog(this);
  }
  Send("set","pause",paused?"yes":"no");
 }
}
