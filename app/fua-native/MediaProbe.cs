using System;using System.Text;using System.Runtime.InteropServices;
class MediaProbe {
 [DllImport("runtime\\MediaInfo.dll")]static extern IntPtr MediaInfo_New();
 [DllImport("runtime\\MediaInfo.dll",CharSet=CharSet.Unicode)]static extern IntPtr MediaInfo_Open(IntPtr h,string path);
 [DllImport("runtime\\MediaInfo.dll",CharSet=CharSet.Unicode)]static extern IntPtr MediaInfo_Option(IntPtr h,string key,string value);
 [DllImport("runtime\\MediaInfo.dll")]static extern IntPtr MediaInfo_Inform(IntPtr h,IntPtr reserved);
 [DllImport("runtime\\MediaInfo.dll")]static extern void MediaInfo_Delete(IntPtr h);
 static int Main(string[] args){Console.OutputEncoding=new UTF8Encoding(false);if(args.Length!=1)return 1;IntPtr h=MediaInfo_New();try{MediaInfo_Option(h,"Output","JSON");MediaInfo_Option(h,"ParseSpeed","0");if(MediaInfo_Open(h,args[0])==IntPtr.Zero)return 2;Console.Write(Marshal.PtrToStringUni(MediaInfo_Inform(h,IntPtr.Zero)));return 0;}catch{return 3;}finally{MediaInfo_Delete(h);}}
}
