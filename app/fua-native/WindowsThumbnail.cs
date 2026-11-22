using System;using System.IO;using System.Drawing;using System.Drawing.Imaging;using System.Runtime.InteropServices;
class WindowsThumbnail {
 [StructLayout(LayoutKind.Sequential)]struct Size{public int Width,Height;public Size(int width,int height){Width=width;Height=height;}}
 [ComImport,Guid("bcc18b79-ba16-442f-80c4-8a59c30c463b"),InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]interface IImageFactory{[PreserveSig]int GetImage(Size size,uint flags,out IntPtr bitmap);}
 [DllImport("shell32.dll",CharSet=CharSet.Unicode,PreserveSig=true)]static extern int SHCreateItemFromParsingName(string file,IntPtr context,ref Guid iid,[MarshalAs(UnmanagedType.Interface)]out IImageFactory factory);
 [DllImport("gdi32.dll")]static extern bool DeleteObject(IntPtr handle);
 [STAThread]internal static int Main(string[] args){IImageFactory factory=null;IntPtr bitmap=IntPtr.Zero;try{if(args.Length!=2||!File.Exists(args[0]))return 1;Guid iid=typeof(IImageFactory).GUID;int result=SHCreateItemFromParsingName(Path.GetFullPath(args[0]),IntPtr.Zero,ref iid,out factory);if(result<0||factory==null)return 2;result=factory.GetImage(new Size(640,640),0x9,out bitmap);if(result<0||bitmap==IntPtr.Zero)return 3;using(var image=Image.FromHbitmap(bitmap)){if(image.Width<32||image.Height<32)return 4;Directory.CreateDirectory(Path.GetDirectoryName(Path.GetFullPath(args[1])));image.Save(args[1],ImageFormat.Png);}return 0;}catch{return 5;}finally{if(bitmap!=IntPtr.Zero)DeleteObject(bitmap);if(factory!=null)Marshal.ReleaseComObject(factory);}}
}
