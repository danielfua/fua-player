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

    bool? hdrDisplay;
    bool rtxFilterApplied;

    void RefreshDisplayColor()
    {
        bool hdr = IsHdrEnabled(Screen.FromControl(this).DeviceName);
        if (hdrDisplay != hdr)
        {
            hdrDisplay = hdr;
            UpdateRtxFilter();
            Send("set", "target-colorspace-hint", hdr ? "yes" : "no");
            Send("set", "target-trc", hdr ? "auto" : "srgb");
            Send("set", "target-peak", "auto");
        }
        UpdateRtxFilter();
    }

    void UpdateRtxFilter()
    {
        string transfer = ready ? Get("video-params/gamma") : "";
        bool nativeHdr = transfer == "pq" || transfer == "hlg";
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
