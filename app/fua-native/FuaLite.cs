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
 void AutoStartVoice(){} void StopVoice(){} void PlayLibraryEpisode(string id){}
 void PickLiteFile(){using(var dialog=new OpenFileDialog()){dialog.Filter="Vídeos|*.mkv;*.mp4;*.avi;*.webm;*.mov;*.m4v;*.ts;*.m2ts;*.wmv|Todos os arquivos|*.*";if(dialog.ShowDialog(this)==DialogResult.OK)Open(dialog.FileName,0);}}
 void ShowLiteStart(){
  if(full)ToggleFull();FormBorderStyle=FormBorderStyle.Sizable;MinimumSize=new Size(600,360);
  SaveExternal();CloseCast();if(mpv!=IntPtr.Zero){Send("stop");Send("script-message","fua-stats-close");}
  ready=false;current="";fitExternalWindow=false;libraryMode=false;Text=AppTitle;playback.Visible=false;browser.Visible=false;
  if(liteStart==null){
   liteStart=new Panel{Dock=DockStyle.Fill,BackColor=Color.FromArgb(10,16,23),AllowDrop=true};
   var layout=new TableLayoutPanel{Dock=DockStyle.Fill,ColumnCount=1,RowCount=5};layout.RowStyles.Add(new RowStyle(SizeType.Percent,50));layout.RowStyles.Add(new RowStyle(SizeType.Absolute,65));layout.RowStyles.Add(new RowStyle(SizeType.Absolute,56));layout.RowStyles.Add(new RowStyle(SizeType.Absolute,42));layout.RowStyles.Add(new RowStyle(SizeType.Percent,50));
   layout.Controls.Add(new Label{Text=AppTitle,Dock=DockStyle.Fill,TextAlign=ContentAlignment.MiddleCenter,ForeColor=Color.FromArgb(183,223,248),Font=new Font("Segoe UI",26,FontStyle.Bold)},0,1);
   var open=new SettingsButton{Text="Abrir vídeo",Size=new Size(170,42),Anchor=AnchorStyles.None,BackColor=Color.FromArgb(26,42,58),ForeColor=Color.White};open.Click+=(s,e)=>PickLiteFile();layout.Controls.Add(open,0,2);
   layout.Controls.Add(new Label{Text="Arraste um vídeo para a janela ou use Ctrl+O",Dock=DockStyle.Fill,TextAlign=ContentAlignment.MiddleCenter,ForeColor=Color.FromArgb(155,174,194)},0,3);
   liteStart.Controls.Add(layout);Controls.Add(liteStart);AllowDrop=true;
   DragEventHandler enter=(s,e)=>{if(e.Data.GetDataPresent(DataFormats.FileDrop))e.Effect=DragDropEffects.Copy;};
   DragEventHandler drop=(s,e)=>{var files=e.Data.GetData(DataFormats.FileDrop)as string[];if(files!=null&&files.Length>0&&File.Exists(files[0]))Open(files[0],0);};
   DragEnter+=enter;DragDrop+=drop;liteStart.DragEnter+=enter;liteStart.DragDrop+=drop;layout.AllowDrop=true;layout.DragEnter+=enter;layout.DragDrop+=drop;
  }
  liteStart.Visible=true;liteStart.BringToFront();FrontWindow();
 }
 protected override bool ProcessCmdKey(ref Message message,Keys key){if(LiteMode&&!ready&&key==(Keys.Control|Keys.O)){PickLiteFile();return true;}return base.ProcessCmdKey(ref message,key);}
 void AppSettings(string initialPage=null){
  bool paused=Get("pause")=="yes";Send("set","pause","yes");
  using(var form=new Form{Text=AppTitle+" · Configurações",StartPosition=FormStartPosition.CenterParent,Size=new Size(740,590),MinimumSize=new Size(600,470),BackColor=Color.FromArgb(12,18,27),ForeColor=Color.White,Font=new Font("Segoe UI",10),MinimizeBox=false,MaximizeBox=false}){
   var tabs=new TabControl{Dock=DockStyle.Fill};form.Controls.Add(tabs);var buttons=new FlowLayoutPanel{Dock=DockStyle.Bottom,Height=48,FlowDirection=FlowDirection.RightToLeft};form.Controls.Add(buttons);buttons.BringToFront();
   var video=new TabPage("Vídeo"){BackColor=form.BackColor,ForeColor=Color.White};tabs.TabPages.Add(video);
   var modes=new ComboBox{Dock=DockStyle.Top,DropDownStyle=ComboBoxStyle.DropDownList};modes.Items.AddRange(new object[]{"HDR automático","HDR direto","HDR processado"});modes.SelectedIndex=hdrOutputMode=="direct"?1:hdrOutputMode=="processed"?2:0;
   var editor=new TextBox{Dock=DockStyle.Fill,Multiline=true,ScrollBars=ScrollBars.Both,WordWrap=false,Font=new Font("Consolas",10),Text=File.Exists(DataFile("video-engine.conf"))?File.ReadAllText(DataFile("video-engine.conf")):DefaultVideoConfig};video.Controls.Add(editor);video.Controls.Add(modes);
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
