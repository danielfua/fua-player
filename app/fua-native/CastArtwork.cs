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
class CastArtwork {
 class Client:WebClient {protected override WebRequest GetWebRequest(Uri uri){var r=base.GetWebRequest(uri);r.Timeout=6000;return r;}}
 static int Main(string[] args){try{
  if(args.Length==0)return 1;
  string app=Path.GetFullPath(Path.Combine(AppDomain.CurrentDomain.BaseDirectory,".."));
  var p=new Process{StartInfo=new ProcessStartInfo(Path.Combine(app,"node.exe"),"\""+Path.Combine(app,"title-artwork.cjs")+"\" \""+args[0]+"\" --cast"){UseShellExecute=false,CreateNoWindow=true,RedirectStandardOutput=true}};
  p.Start();string output=p.StandardOutput.ReadToEnd();p.WaitForExit();p.Dispose();
  var j=new JavaScriptSerializer();var data=j.Deserialize<Dictionary<string,object>>(output);object value;
  var people=new List<Dictionary<string,object>>();
  if(data.TryGetValue("cast",out value))foreach(object item in (IEnumerable)value){var person=item as Dictionary<string,object>;if(person!=null)people.Add(person);}
  string dir=Environment.GetEnvironmentVariable("FUA_DATA_DIR");if(String.IsNullOrEmpty(dir))dir=Path.Combine(app,"data");dir=Path.Combine(dir,"cast-photo-cache");Directory.CreateDirectory(dir);
  ServicePointManager.SecurityProtocol=SecurityProtocolType.Tls12;
  Parallel.ForEach(people,new ParallelOptions{MaxDegreeOfParallelism=4},person=>{try{
   long id;if(!person.ContainsKey("id")||!long.TryParse(Convert.ToString(person["id"]),out id)||id<=0)return;
   string file=Path.Combine(dir,id+"-144.bgra");
   if(!File.Exists(file)){
    Uri uri;if(!person.ContainsKey("photo")||!Uri.TryCreate(Convert.ToString(person["photo"]),UriKind.Absolute,out uri)||uri.Scheme!="https"||uri.Host!="image.tmdb.org")return;
    byte[] imageBytes;using(var client=new Client())imageBytes=client.DownloadData(uri);
    using(var stream=new MemoryStream(imageBytes))using(var image=new Bitmap(stream))using(var b=new Bitmap(144,144,PixelFormat.Format32bppArgb)){
     using(var g=Graphics.FromImage(b))using(var clip=new GraphicsPath()){
      g.SmoothingMode=SmoothingMode.AntiAlias;g.InterpolationMode=InterpolationMode.HighQualityBicubic;clip.AddEllipse(1,1,142,142);g.SetClip(clip);
      int side=Math.Min(image.Width,image.Height),sx=(image.Width-side)/2,sy=(int)((image.Height-side)*.25);
      g.DrawImage(image,new Rectangle(0,0,144,144),new Rectangle(sx,sy,side,side),GraphicsUnit.Pixel);
     }
     var bits=b.LockBits(new Rectangle(0,0,144,144),ImageLockMode.ReadOnly,PixelFormat.Format32bppArgb);byte[] raw=new byte[144*144*4];Marshal.Copy(bits.Scan0,raw,0,raw.Length);b.UnlockBits(bits);
     string temp=file+"."+Process.GetCurrentProcess().Id+".tmp";File.WriteAllBytes(temp,raw);try{File.Move(temp,file);}catch{File.Delete(temp);}
    }
   }
   person["file"]=file;
  }catch{}});
  Console.Write(j.Serialize(new{cast=people}));return 0;
 }catch{return 1;}}
}
