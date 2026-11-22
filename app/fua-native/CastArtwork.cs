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
 static int Main(string[] args){try{
  if(args.Length==0)return 1;
  string app=Path.GetFullPath(Path.Combine(AppDomain.CurrentDomain.BaseDirectory,".."));
  var p=new Process{StartInfo=new ProcessStartInfo(Path.Combine(app,"node.exe"),"\""+Path.Combine(app,"title-artwork.cjs")+"\" \""+args[0]+"\" --cast"){UseShellExecute=false,CreateNoWindow=true,RedirectStandardOutput=true}};
  p.Start();string output=p.StandardOutput.ReadToEnd();p.WaitForExit();p.Dispose();
  var j=new JavaScriptSerializer();var data=j.Deserialize<Dictionary<string,object>>(output);object value;
  var people=new List<Dictionary<string,object>>();
  if(data.TryGetValue("cast",out value))foreach(object item in (IEnumerable)value){var person=item as Dictionary<string,object>;if(person!=null)people.Add(person);}
  string dir=Environment.GetEnvironmentVariable("FUA_DATA_DIR");if(String.IsNullOrEmpty(dir))dir=Path.Combine(app,"data");dir=Path.Combine(dir,"cast-photo-cache");Directory.CreateDirectory(dir);

  Parallel.ForEach(people,new ParallelOptions{MaxDegreeOfParallelism=4},person=>{string sourceFile=null;try{
   long id;if(!person.ContainsKey("id")||!long.TryParse(Convert.ToString(person["id"]),out id)||id<=0)return;
   string file=Path.Combine(dir,id+"-144.bgra");
   if(File.Exists(file)&&new FileInfo(file).Length!=144*144*4)File.Delete(file);
   if(!File.Exists(file)){
    object source;string sourceRoot=Path.GetFullPath(Path.Combine(Path.GetDirectoryName(dir),"cast-photo-source-cache"))+Path.DirectorySeparatorChar;
    if(!person.TryGetValue("image",out source)||source==null)return;
    string imageFile=Path.GetFullPath(Convert.ToString(source));
    if(!imageFile.StartsWith(sourceRoot,StringComparison.OrdinalIgnoreCase)||!File.Exists(imageFile))return;
    sourceFile=imageFile;byte[] imageBytes=File.ReadAllBytes(imageFile);
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
  }catch(Exception error){if(sourceFile!=null&&(error is ArgumentException||error is OutOfMemoryException)){try{File.Delete(sourceFile);}catch{}}if(Environment.GetEnvironmentVariable("FUA_CAST_DEBUG")=="1")Console.Error.WriteLine(Convert.ToString(person["id"])+": "+error.GetType().Name+": "+error.Message);}});
  data["cast"]=people;Console.Write(j.Serialize(data));return 0;
 }catch{return 1;}}
}
