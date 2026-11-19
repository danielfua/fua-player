using System;
partial class FuaNative {
 // The cast is drawn inside the playback overlay, without resizing the video.
 System.Windows.Forms.Panel castPanel=null;
 void CloseCast(){if(mpv!=IntPtr.Zero)Send("set","user-data/fua-cast-open","false");}
 void ToggleCast(bool open){Send("script-message","fua-cast-toggle",open?"yes":"no");}
}
