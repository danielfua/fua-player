using System;using System.IO;using System.Linq;using System.Diagnostics;using System.Windows.Forms;
class LiteLauncher{
 [STAThread]static void Main(string[] args){try{string exe=Path.Combine(AppDomain.CurrentDomain.BaseDirectory,"fua-native","FuaPlayerLite.exe");Process.Start(new ProcessStartInfo(exe,string.Join(" ",args.Select(a=>"\""+(File.Exists(a)?Path.GetFullPath(a):a).TrimEnd('\\')+"\""))){UseShellExecute=false,WorkingDirectory=Path.GetDirectoryName(exe)});}catch(Exception e){MessageBox.Show(e.Message,"Fua Player Lite");}}
}
