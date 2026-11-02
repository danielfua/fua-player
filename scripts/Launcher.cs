using System;using System.IO;using System.Diagnostics;using System.Windows.Forms;
class Launcher {
 [STAThread]static int Main(string[] args){try{string root=AppDomain.CurrentDomain.BaseDirectory;
 if(args.Length>0){string file=Path.GetFullPath(args[0]);if(!File.Exists(file))throw new FileNotFoundException("O vídeo não foi encontrado.",file);Process.Start(new ProcessStartInfo(Path.Combine(root,"fua-native","FuaPlayer.exe"),"\""+file+"\" --standalone"){UseShellExecute=false,WorkingDirectory=root});return 0;}
 var start=new ProcessStartInfo(Path.Combine(root,"node.exe"),"\""+Path.Combine(root,"native-launcher.cjs")+"\""){UseShellExecute=false,CreateNoWindow=true,RedirectStandardOutput=true,RedirectStandardError=true,WorkingDirectory=root};using(var process=Process.Start(start)){string output=process.StandardOutput.ReadToEnd();string error=process.StandardError.ReadToEnd();process.WaitForExit();if(process.ExitCode!=0)throw new Exception(string.IsNullOrWhiteSpace(error)?"Não foi possível iniciar o Fua Player.":error);return 0;}}catch(Exception ex){MessageBox.Show(ex.Message,"Fua Player",MessageBoxButtons.OK,MessageBoxIcon.Error);return 1;}}
}
