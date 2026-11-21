using System;
using System.Runtime.InteropServices;
using System.Windows.Forms;

partial class FuaNative
{
    [StructLayout(LayoutKind.Explicit, Size = 72)]
    struct DisplayPath
    {
        [FieldOffset(0)] public long SourceAdapter;
        [FieldOffset(8)] public uint SourceId;
        [FieldOffset(20)] public long TargetAdapter;
        [FieldOffset(28)] public uint TargetId;
    }

    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode, Pack = 4)]
    struct DisplaySource
    {
        public uint Type, Size;
        public long Adapter;
        public uint Id;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 32)] public string Name;
    }

    [StructLayout(LayoutKind.Sequential, Pack = 4)]
    struct DisplayColor
    {
        public uint Type, Size;
        public long Adapter;
        public uint Id, Flags, Encoding, BitsPerChannel, Mode;
    }

    [DllImport("user32.dll")]
    static extern int GetDisplayConfigBufferSizes(uint flags, out uint paths, out uint modes);
    [DllImport("user32.dll")]
    static extern int QueryDisplayConfig(uint flags, ref uint paths, [Out] DisplayPath[] entries,
        ref uint modes, IntPtr modeEntries, IntPtr topology);
    [DllImport("user32.dll", EntryPoint = "DisplayConfigGetDeviceInfo")]
    static extern int GetDisplaySource(ref DisplaySource source);
    [DllImport("user32.dll", EntryPoint = "DisplayConfigGetDeviceInfo")]
    static extern int GetDisplayColor(ref DisplayColor color);

    static bool IsHdrEnabled(string deviceName)
    {
        const uint activePaths = 2;
        uint paths, modes;
        if (GetDisplayConfigBufferSizes(activePaths, out paths, out modes) != 0 || paths == 0)
            return false;

        var entries = new DisplayPath[paths];
        IntPtr modeEntries = Marshal.AllocHGlobal(checked((int)modes * 64));
        try
        {
            if (QueryDisplayConfig(activePaths, ref paths, entries, ref modes, modeEntries, IntPtr.Zero) != 0)
                return false;

            bool matched = false;
            for (int i = 0; i < paths; i++)
            {
                var path = entries[i];
                var source = new DisplaySource { Type = 1, Size = 84, Adapter = path.SourceAdapter, Id = path.SourceId };
                if (GetDisplaySource(ref source) != 0 || !string.Equals(source.Name, deviceName, StringComparison.OrdinalIgnoreCase))
                    continue;

                matched = true;
                var color = new DisplayColor { Type = 15, Size = 36, Adapter = path.TargetAdapter, Id = path.TargetId };
                if (GetDisplayColor(ref color) == 0)
                {
                    if (color.Mode != 2) return false;
                    continue;
                }

                color.Type = 9;
                color.Size = 32;
                if (GetDisplayColor(ref color) != 0 || (color.Flags & 3) != 3)
                    return false;
            }
            return matched;
        }
        finally
        {
            Marshal.FreeHGlobal(modeEntries);
        }
    }


    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    struct HdrOutputDesc {
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst=32)] public string Name;
        public int Left, Top, Right, Bottom, Attached, Rotation;
        public IntPtr Monitor;
        public uint Bits, ColorSpace;
        public float Rx,Ry,Gx,Gy,Bx,By,Wx,Wy,Min,Max,Full;
    }
    [UnmanagedFunctionPointer(CallingConvention.StdCall)] delegate int EnumDxgi(IntPtr self,uint index,out IntPtr result);
    [UnmanagedFunctionPointer(CallingConvention.StdCall)] delegate int ReadHdrDesc(IntPtr self,out HdrOutputDesc desc);
    [DllImport("dxgi.dll")] static extern int CreateDXGIFactory1(ref Guid iid,out IntPtr factory);
    static T DxgiMethod<T>(IntPtr obj,int slot) where T:class {
        return Marshal.GetDelegateForFunctionPointer(Marshal.ReadIntPtr(Marshal.ReadIntPtr(obj),slot*IntPtr.Size),typeof(T)) as T;
    }
    static int ReadScreenPeak(string device) {
        IntPtr factory=IntPtr.Zero;
        try {
            Guid iid=new Guid("770aae78-f26f-4dba-a829-253c83d1b387");
            if(CreateDXGIFactory1(ref iid,out factory)<0)return 0;
            for(uint a=0;;a++) {
                IntPtr adapter;if(DxgiMethod<EnumDxgi>(factory,12)(factory,a,out adapter)<0)break;
                try { for(uint o=0;;o++) {
                    IntPtr output;if(DxgiMethod<EnumDxgi>(adapter,7)(adapter,o,out output)<0)break;
                    IntPtr output6=IntPtr.Zero;
                    try {
                        Guid six=new Guid("068346e8-aaec-4b84-add7-137f513f77a1");
                        if(Marshal.QueryInterface(output,ref six,out output6)<0)continue;
                        HdrOutputDesc desc;
                        if(DxgiMethod<ReadHdrDesc>(output6,27)(output6,out desc)>=0&&string.Equals(desc.Name,device,StringComparison.OrdinalIgnoreCase))
                            return !float.IsNaN(desc.Max)&&desc.Max>=10&&desc.Max<=10000?(int)Math.Round(desc.Max):0;
                    }finally{if(output6!=IntPtr.Zero)Marshal.Release(output6);Marshal.Release(output);}
                }}finally{Marshal.Release(adapter);}
            }
        }catch{}finally{if(factory!=IntPtr.Zero)Marshal.Release(factory);}
        return 0;
    }
    [StructLayout(LayoutKind.Sequential, CharSet=CharSet.Unicode)] struct PeakDisplayDevice {
        public int Size;
        [MarshalAs(UnmanagedType.ByValTStr,SizeConst=32)]public string Name;
        [MarshalAs(UnmanagedType.ByValTStr,SizeConst=128)]public string Description;
        public int Flags;
        [MarshalAs(UnmanagedType.ByValTStr,SizeConst=128)]public string Id;
        [MarshalAs(UnmanagedType.ByValTStr,SizeConst=128)]public string Key;
    }
    [DllImport("user32.dll",CharSet=CharSet.Unicode)]static extern bool EnumDisplayDevices(string device,uint index,ref PeakDisplayDevice result,uint flags);
    static string PeakScreenKey(string device) {
        var result=new PeakDisplayDevice{Size=Marshal.SizeOf(typeof(PeakDisplayDevice))};
        return EnumDisplayDevices(device,0,ref result,1)&&!string.IsNullOrEmpty(result.Id)?result.Id:Environment.MachineName+":"+device;
    }
    int hdrXpScreenPeak, hdrXpManualPeak;
    string hdrXpScreenKey;
    bool hdrXpPeakDirty;
    DateTime hdrXpPeakSaveAt;
    void SaveHdrXpPeaks() {
        if(!hdrXpPeakDirty)return;
        try{System.IO.File.WriteAllText(DataFile("hdr-xp-peaks.json"),json.Serialize(hdrXpPeaks));hdrXpPeakDirty=false;}catch{}
    }
    System.Collections.Generic.Dictionary<string,int> hdrXpPeaks=new System.Collections.Generic.Dictionary<string,int>();
    void PublishHdrXpPeak() {
        Send("set","user-data/fua-hdr-xp-screen-peak",hdrXpScreenPeak.ToString());
        Send("set","user-data/fua-hdr-xp-manual-peak",hdrXpManualPeak.ToString());
    }
    void SetHdrXpPeak(int value) {
        if(!hdrXpApplied)return;
        int next=value<=0?0:Math.Max(10,Math.Min(hdrXpScreenPeak>0?hdrXpScreenPeak:10000,value));
        if(next==hdrXpManualPeak)return;
        hdrXpManualPeak=next;
        if(!string.IsNullOrEmpty(hdrXpScreenKey)) {
            hdrXpPeaks[hdrXpScreenKey]=hdrXpManualPeak;
            hdrXpPeakDirty=true;hdrXpPeakSaveAt=DateTime.UtcNow.AddMilliseconds(500);
        }
        hdrOutputPolicy=null;ApplyHdrOutput();PublishHdrXpPeak();
    }
    void RefreshHdrXpScreen(string device) {
        if(hdrXpPeakDirty&&DateTime.UtcNow>=hdrXpPeakSaveAt)SaveHdrXpPeaks();
        UpdateHdrXpScreen(PeakScreenKey(device),ReadScreenPeak(device));
    }
    void UpdateHdrXpScreen(string key,int peak) {
        if(key==hdrXpScreenKey&&peak==hdrXpScreenPeak)return;
        hdrXpScreenKey=key;hdrXpScreenPeak=peak;
        int saved;hdrXpManualPeak=hdrXpPeaks.TryGetValue(key,out saved)?Math.Max(0,Math.Min(10000,saved)):0;
        if(peak>0)hdrXpManualPeak=Math.Min(hdrXpManualPeak,peak);
        hdrOutputPolicy=null;PublishHdrXpPeak();
    }

    bool? hdrDisplay;
    bool rtxFilterApplied;
    string hdrOutputMode = "direct";
    string hdrOutputPolicy;
    string processedHdrPeak = "yes";
    string processedToneMapping = "bt.2446a";
    bool hdrXpRequested;
    bool hdrXpApplied;
    int hdrXpCompensation;
    double hdrXpBrightnessOffset;

    double HdrXpBaseBrightness()
    {
        double value;
        if (!double.TryParse(Get("brightness"), System.Globalization.NumberStyles.Float, System.Globalization.CultureInfo.InvariantCulture, out value)) value = 0;
        return value - hdrXpBrightnessOffset;
    }

    void SetBaseBrightness(double baseline)
    {
        baseline = Math.Max(-100, Math.Min(100, baseline));
        double desired = hdrXpApplied ? -hdrXpCompensation : 0;
        double value = Math.Max(-100, Math.Min(100, baseline + desired));
        hdrXpBrightnessOffset = value - baseline;
        Send("set", "brightness", value.ToString(System.Globalization.CultureInfo.InvariantCulture));
        Send("set", "user-data/fua-hdr-xp-brightness-offset", hdrXpBrightnessOffset.ToString(System.Globalization.CultureInfo.InvariantCulture));
    }

    void ApplyHdrXpBrightness(bool enabled)
    {
        double desired = enabled ? -hdrXpCompensation : 0;
        if (desired == hdrXpBrightnessOffset) return;
        SetBaseBrightness(HdrXpBaseBrightness());
    }

    void SetHdrXpMode(int mode)
    {
        if (mode < -1 || mode > 2) return;
        string transfer = ready ? Get("video-params/gamma") : "";
        if (mode >= 0 && (hdrDisplay != true || (transfer != "pq" && transfer != "hlg"))) return;
        hdrXpRequested = mode >= 0;
        if (mode >= 0) hdrXpCompensation = mode;
        hdrOutputPolicy = null;
        ApplyHdrOutput();
    }
    string hdrXpSavedToneMapping;
    string hdrXpSavedInverse;
    string hdrXpSavedSplineContrast;
    string hdrXpSavedKneeAdaptation;

    static bool UseDirectHdr(string mode, bool hdrEnabled, string transfer)
    {
        return hdrEnabled && mode != "processed" && (transfer == "pq" || transfer == "hlg");
    }

    void LoadHdrOutputMode()
    {
        try{hdrXpPeaks=json.Deserialize<System.Collections.Generic.Dictionary<string,int>>(System.IO.File.ReadAllText(DataFile("hdr-xp-peaks.json")))??hdrXpPeaks;}catch{}
        string peak = Get("hdr-compute-peak");
        if (!string.IsNullOrEmpty(peak)) processedHdrPeak = peak;
        string curve = Get("tone-mapping");
        if (!string.IsNullOrEmpty(curve)) processedToneMapping = curve;
        try
        {
            var values = json.Deserialize<System.Collections.Generic.Dictionary<string, string>>(
                System.IO.File.ReadAllText(DataFile("hdr-output.json")));
            string mode;
            if (values.TryGetValue("mode", out mode) && (mode == "auto" || mode == "direct" || mode == "processed"))
                hdrOutputMode = mode;
        }
        catch { }
    }

    void SetHdrOutputMode(string mode)
    {
        if (mode != "auto" && mode != "direct" && mode != "processed") return;
        System.IO.File.WriteAllText(DataFile("hdr-output.json"), json.Serialize(new { mode = mode }));
        hdrOutputMode = mode;
        hdrOutputPolicy = null;
        ApplyHdrOutput();
    }

    void ApplyHdrOutput()
    {
        if (!hdrDisplay.HasValue) return;
        string transfer = ready ? Get("video-params/gamma") : "";
        bool xp = hdrXpRequested && hdrDisplay.Value && (transfer == "pq" || transfer == "hlg");
        bool direct = !xp && UseDirectHdr(hdrOutputMode, hdrDisplay.Value, transfer);
        string policy = hdrDisplay.Value + ":" + direct + ":" + transfer + ":" + hdrOutputMode + ":" + xp + ":" + hdrXpCompensation + ":" + hdrXpManualPeak;
        if (policy == hdrOutputPolicy) return;
        hdrOutputPolicy = policy;
        // Source metadata keeps native HDR for the TV; target metadata retains the
        // existing display-adapted path. SDR screens always receive SDR output.
        Send("set", "target-colorspace-hint", hdrDisplay.Value ? "yes" : "no");
        Send("set", "target-colorspace-hint-mode", direct ? "source" : "target");
        Send("set", "target-trc", hdrDisplay.Value ? "auto" : "srgb");
        Send("set", "target-peak", xp && hdrXpManualPeak > 0 ? hdrXpManualPeak.ToString() : "auto");
        Send("set", "hdr-compute-peak", xp ? "yes" : direct ? "no" : processedHdrPeak);
        if (xp && !hdrXpApplied)
        {
            hdrXpSavedToneMapping = Get("tone-mapping");
            if (string.IsNullOrEmpty(hdrXpSavedToneMapping)) hdrXpSavedToneMapping = processedToneMapping;
            hdrXpSavedInverse = Get("inverse-tone-mapping");
            if (string.IsNullOrEmpty(hdrXpSavedInverse)) hdrXpSavedInverse = "no";
            hdrXpSavedSplineContrast = Get("tone-mapping-spline-contrast");
            if (string.IsNullOrEmpty(hdrXpSavedSplineContrast)) hdrXpSavedSplineContrast = "0.5";
            hdrXpSavedKneeAdaptation = Get("tone-mapping-knee-adaptation");
            if (string.IsNullOrEmpty(hdrXpSavedKneeAdaptation)) hdrXpSavedKneeAdaptation = "0.4";
            hdrXpApplied = true;
            Send("set", "tone-mapping", "spline");
            Send("set", "tone-mapping-spline-contrast", hdrXpSavedSplineContrast);
            Send("set", "tone-mapping-knee-adaptation", "0");
            Send("set", "inverse-tone-mapping", "yes");
        }
        else if (!xp && hdrXpApplied)
        {
            hdrXpApplied = false;
            Send("set", "inverse-tone-mapping", hdrXpSavedInverse);
            Send("set", "tone-mapping", hdrXpSavedToneMapping);
            Send("set", "tone-mapping-spline-contrast", hdrXpSavedSplineContrast);
            Send("set", "tone-mapping-knee-adaptation", hdrXpSavedKneeAdaptation);
        }
        ApplyHdrXpBrightness(xp);
        Send("set", "user-data/fua-hdr-xp", xp ? "true" : "false");
        Send("set", "user-data/fua-hdr-xp-mode", xp ? hdrXpCompensation.ToString() : "-1");
    }

    void CycleHdrXp()
    {
        SetHdrXpMode(!hdrXpRequested ? 0 : hdrXpCompensation >= 2 ? -1 : hdrXpCompensation + 1);
    }

    void ToggleHdrXp()
    {
        string transfer = ready ? Get("video-params/gamma") : "";
        if (!hdrXpRequested && (hdrDisplay != true || (transfer != "pq" && transfer != "hlg")))
        {
            Send("show-text", "HDR XP requer vídeo HDR e HDR ativo no Windows", "2500");
            return;
        }
        hdrXpRequested = !hdrXpRequested;
        hdrOutputPolicy = null;
        ApplyHdrOutput();
    }

    void RefreshDisplayColor()
    {
        string device=Screen.FromControl(this).DeviceName;
        RefreshHdrXpScreen(device);
        bool hdr = IsHdrEnabled(device);
        if (hdrDisplay != hdr)
        {
            hdrDisplay = hdr;
            UpdateRtxFilter();
        }
        UpdateRtxFilter();
        ApplyHdrOutput();
    }

    void UpdateRtxFilter()
    {
        string transfer = ready ? Get("video-params/gamma") : "";
        bool nativeHdr = transfer == "pq" || transfer == "hlg";
        ApplyHdrOutput();
        bool enable = hdrDisplay == true && rtxRequested && transfer.Length > 0 && !nativeHdr;
        if (enable != rtxFilterApplied)
        {
            rtxFilterApplied = enable;
            rtx = enable ? "RTX HDR solicitado; aguardando confirmação" : "RTX HDR desligado";
            Send("vf", enable ? "add" : "remove", enable ? "@fua-rtx:d3d11vpp=nvidia-true-hdr" : "@fua-rtx");
        }
        if (!enable)
            rtx = hdrDisplay != true ? "RTX HDR indisponível nesta tela SDR" :
                nativeHdr ? "Fonte HDR nativa" : "RTX HDR desligado";
    }

    void ToggleRtxHdr()
    {
        RefreshDisplayColor();
        if (hdrDisplay != true)
        {
            Send("show-text", "RTX HDR requer HDR ativo no Windows nesta tela", "2500");
            return;
        }
        rtxRequested = !rtxRequested;
        UpdateRtxFilter();
    }
}
