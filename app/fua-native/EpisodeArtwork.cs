using System;
using System.IO;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Drawing.Imaging;
using System.Runtime.InteropServices;
using System.Web.Script.Serialization;
using System.Collections;
using System.Collections.Generic;
using System.Diagnostics;
using System.Net;
using System.Threading.Tasks;
class EpisodeArtwork {
 class Client:WebClient {protected override WebRequest GetWebRequest(Uri uri){var r=base.GetWebRequest(uri);r.Timeout=6000;return r;}}
 static int Main(string[] args){try{
  Console.OutputEncoding=new System.Text.UTF8Encoding(false);
  if(args.Length==0)return 1;
  string app=Path.GetFullPath(Path.Combine(AppDomain.CurrentDomain.BaseDirectory,".."));
  var p=new Process{StartInfo=new ProcessStartInfo(Path.Combine(app,"node.exe"),"\""+Path.Combine(app,"episode-list.cjs")+"\" \""+args[0]+"\" --images"){UseShellExecute=false,CreateNoWindow=true,RedirectStandardOutput=true}};
  p.Start();string output=p.StandardOutput.ReadToEnd();p.WaitForExit();p.Dispose();
  var j=new JavaScriptSerializer();var data=j.Deserialize<Dictionary<string,object>>(output);object value;
  var people=new List<Dictionary<string,object>>();
  if(data.TryGetValue("episodes",out value))foreach(object item in (IEnumerable)value){var person=item as Dictionary<string,object>;if(person!=null)people.Add(person);}
  string dir=Environment.GetEnvironmentVariable("FUA_DATA_DIR");if(String.IsNullOrEmpty(dir))dir=Path.Combine(app,"data");dir=Path.Combine(dir,"episode-photo-cache");Directory.CreateDirectory(dir);
  ServicePointManager.SecurityProtocol=SecurityProtocolType.Tls12;
  using(var measureBitmap=new Bitmap(1,1))using(var measure=Graphics.FromImage(measureBitmap))using(var font=new Font("Segoe UI",13,FontStyle.Bold,GraphicsUnit.Pixel)){
   foreach(var person in people)person["titleWidth"]=Math.Ceiling(measure.MeasureString(Convert.ToString(person["title"]),font,100000,StringFormat.GenericTypographic).Width)+2;
  }
  Parallel.ForEach(people,new ParallelOptions{MaxDegreeOfParallelism=4},person=>{try{
   string id=Convert.ToString(person["id"]);if(!System.Text.RegularExpressions.Regex.IsMatch(id,"^[a-f0-9]{20}$"))return;
   string file=Path.Combine(dir,id+"-320-r12.bgra");
   if(!File.Exists(file)){
    object cachedImage;if(!person.TryGetValue("imageFile",out cachedImage)||!File.Exists(Convert.ToString(cachedImage)))return;
    byte[] imageBytes=File.ReadAllBytes(Convert.ToString(cachedImage));
    using(var stream=new MemoryStream(imageBytes))using(var image=new Bitmap(stream))using(var b=new Bitmap(320,180,PixelFormat.Format32bppArgb)){
     using(var g=Graphics.FromImage(b))using(var clip=new GraphicsPath()){
      g.SmoothingMode=SmoothingMode.AntiAlias;g.InterpolationMode=InterpolationMode.HighQualityBicubic;
      clip.AddArc(0,0,24,24,180,90);clip.AddArc(296,0,24,24,270,90);clip.AddArc(296,156,24,24,0,90);clip.AddArc(0,156,24,24,90,90);clip.CloseFigure();g.SetClip(clip);
      g.DrawImage(image,new Rectangle(0,0,320,180));
     }
     var bits=b.LockBits(new Rectangle(0,0,320,180),ImageLockMode.ReadOnly,PixelFormat.Format32bppArgb);byte[] raw=new byte[320*180*4];Marshal.Copy(bits.Scan0,raw,0,raw.Length);b.UnlockBits(bits);
     string temp=file+"."+Process.GetCurrentProcess().Id+".tmp";File.WriteAllBytes(temp,raw);try{File.Move(temp,file);}catch{File.Delete(temp);}
    }
   }
   person["file"]=file;
  }catch(Exception ex){Console.Error.WriteLine("Episode thumbnail: "+ex.GetType().Name+": "+ex.Message);}});
  Console.Write(j.Serialize(new{episodes=people}));return 0;
 }catch{return 1;}}
}
