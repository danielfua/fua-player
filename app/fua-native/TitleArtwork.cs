using System;using System.IO;using System.Diagnostics;using System.Drawing;using System.Drawing.Imaging;using System.Runtime.InteropServices;using System.Web.Script.Serialization;using System.Collections.Generic;using System.Net;
class TitleArtwork{
static int Main(string[] args){try{if(args.Length>0&&args[0]=="--resize")return Resize(args);if(args.Length<1)return 1;string root=AppDomain.CurrentDomain.BaseDirectory,app=Path.GetFullPath(Path.Combine(root,".."));var p=new Process();p.StartInfo=new ProcessStartInfo(Path.Combine(app,"node.exe"),"\""+Path.Combine(app,"title-artwork.cjs")+"\" \""+args[0]+"\""){UseShellExecute=false,CreateNoWindow=true,RedirectStandardOutput=true};p.Start();string output=p.StandardOutput.ReadToEnd();p.WaitForExit();var j=new JavaScriptSerializer();var v=j.Deserialize<Dictionary<string,object>>(output);if(!v.ContainsKey("url"))return 0;var uri=new Uri((string)v["url"]);if(uri.Scheme!="https"||uri.Host!="image.tmdb.org")return 1;uri=new Uri(uri.AbsoluteUri.Replace("/t/p/original/","/t/p/w500/"));string dir=Environment.GetEnvironmentVariable("FUA_DATA_DIR");if(String.IsNullOrEmpty(dir))dir=Path.Combine(app,"data");dir=Path.Combine(dir,"title-logo-cache");Directory.CreateDirectory(dir);string basefile=Path.Combine(dir,(string)v["key"]+"-compact");if(!File.Exists(basefile+".json")||!File.Exists(basefile+".bgra")){ServicePointManager.SecurityProtocol=SecurityProtocolType.Tls12;byte[] data;using(var client=new WebClient())data=client.DownloadData(uri);using(var stream=new MemoryStream(data))using(var image=new Bitmap(stream)){int w=Math.Min(500,image.Width),h=Math.Max(1,(int)Math.Round(image.Height*(double)w/image.Width));if(h>180){w=Math.Max(1,(int)Math.Round(w*180.0/h));h=180;}using(var b=new Bitmap(w,h,PixelFormat.Format32bppArgb)){using(var g=Graphics.FromImage(b)){g.InterpolationMode=System.Drawing.Drawing2D.InterpolationMode.HighQualityBicubic;g.DrawImage(image,0,0,w,h);}var bits=b.LockBits(new Rectangle(0,0,w,h),ImageLockMode.ReadOnly,PixelFormat.Format32bppArgb);byte[] raw=new byte[w*h*4];for(int y=0;y<h;y++)Marshal.Copy(IntPtr.Add(bits.Scan0,y*bits.Stride),raw,y*w*4,w*4);b.UnlockBits(bits);File.WriteAllBytes(basefile+".bgra",raw);File.WriteAllText(basefile+".json",j.Serialize(new{width=w,height=h,file=basefile+".bgra"}));}}}Console.Write(File.ReadAllText(basefile+".json"));return 0;}catch{return 1;}}

// Resample before overlay-add: its bitmap scaling can alias fine transparent lettering.
static int Resize(string[] args){
 if(args.Length!=6)return 1;
 int sw=int.Parse(args[2]),sh=int.Parse(args[3]),dw=int.Parse(args[4]),dh=int.Parse(args[5]);
 if(sw<1||sh<1||sw>500||sh>180||dw<1||dh<1||dw>2048||dh>512)return 1;
 string source=Path.GetFullPath(args[1]);
 string data=Environment.GetEnvironmentVariable("FUA_DATA_DIR");
 if(String.IsNullOrEmpty(data))data=Path.Combine(AppDomain.CurrentDomain.BaseDirectory,"..","data");
 string cache=Path.GetFullPath(Path.Combine(data,"title-logo-cache"))+Path.DirectorySeparatorChar;
 if(!source.StartsWith(cache,StringComparison.OrdinalIgnoreCase)||!source.EndsWith(".bgra",StringComparison.OrdinalIgnoreCase))return 1;
 string target=Path.Combine(Path.GetDirectoryName(source),Path.GetFileNameWithoutExtension(source)+"-smooth-v2-"+dw+"x"+dh+".bgra");
 if(!File.Exists(target)||new FileInfo(target).Length!=dw*dh*4){
  byte[] raw=File.ReadAllBytes(source);if(raw.Length!=sw*sh*4)return 1;
  using(var input=new Bitmap(sw,sh,PixelFormat.Format32bppArgb))using(var output=new Bitmap(dw,dh,PixelFormat.Format32bppArgb)){
   var bits=input.LockBits(new Rectangle(0,0,sw,sh),ImageLockMode.WriteOnly,PixelFormat.Format32bppArgb);
   try{for(int y=0;y<sh;y++)Marshal.Copy(raw,y*sw*4,IntPtr.Add(bits.Scan0,y*bits.Stride),sw*4);}finally{input.UnlockBits(bits);}
   using(var g=Graphics.FromImage(output))using(var attributes=new ImageAttributes()){
    g.CompositingMode=System.Drawing.Drawing2D.CompositingMode.SourceCopy;
    g.CompositingQuality=System.Drawing.Drawing2D.CompositingQuality.HighQuality;
    g.InterpolationMode=System.Drawing.Drawing2D.InterpolationMode.HighQualityBicubic;
    g.PixelOffsetMode=System.Drawing.Drawing2D.PixelOffsetMode.HighQuality;
    attributes.SetWrapMode(System.Drawing.Drawing2D.WrapMode.TileFlipXY);
    g.DrawImage(input,new Rectangle(0,0,dw,dh),0,0,sw,sh,GraphicsUnit.Pixel,attributes);
   }
   bits=output.LockBits(new Rectangle(0,0,dw,dh),ImageLockMode.ReadOnly,PixelFormat.Format32bppArgb);
   raw=new byte[dw*dh*4];try{for(int y=0;y<dh;y++)Marshal.Copy(IntPtr.Add(bits.Scan0,y*bits.Stride),raw,y*dw*4,dw*4);}finally{output.UnlockBits(bits);}
   // mpv requires premultiplied BGRA. Straight RGB on translucent edges
   // overflows the compositor and produces bright/colored outlines.
   for(int i=0;i<raw.Length;i+=4){int alpha=raw[i+3];for(int c=0;c<3;c++)raw[i+c]=(byte)((raw[i+c]*alpha+127)/255);}
   File.WriteAllBytes(target,raw);
  }
 }
 Console.Write(new JavaScriptSerializer().Serialize(new{file=target,width=dw,height=dh}));return 0;
}
}
