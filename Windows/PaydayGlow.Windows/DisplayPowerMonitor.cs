using System;
using System.Runtime.InteropServices;
using System.Windows;
using System.Windows.Interop;

namespace PaydayGlow.Windows;

internal sealed class DisplayPowerMonitor : IDisposable
{
    // Microsoft recommends GUID_SESSION_DISPLAY_STATUS for interactive user apps.
    private static readonly Guid DisplayStatus = new("2B84C20E-AD23-4DDF-93DB-05FFBD7EFCA5");
    private readonly HwndSource source;
    private readonly nint registration;
    private bool asleep;
    private bool screenAwake = true;
    public bool ScreenAwake => screenAwake && !asleep;
    public bool Registered => registration != 0;
    public event Action? Changed;

    public DisplayPowerMonitor(Window window)
    {
        nint hwnd = new WindowInteropHelper(window).EnsureHandle();
        source = HwndSource.FromHwnd(hwnd)!;
        source.AddHook(Hook);
        Guid guid = DisplayStatus;
        registration = RegisterPowerSettingNotification(hwnd, ref guid, 0);
    }
    private nint Hook(nint hwnd, int message, nint wParam, nint lParam, ref bool handled)
    {
        if (message != 0x0218) return 0; // WM_POWERBROADCAST
        if ((int)wParam == 0x8013 && lParam != 0) // PBT_POWERSETTINGCHANGE
        {
            Guid guid = Marshal.PtrToStructure<Guid>(lParam);
            int length = Marshal.ReadInt32(lParam, 16);
            if (guid == DisplayStatus && length >= 4)
            {
                int state = Marshal.ReadInt32(lParam, 20);
                if (state is >= 0 and <= 2) { screenAwake = state != 0; if (state != 0) asleep = false; Changed?.Invoke(); }
            }
        }
        else if ((int)wParam == 4) { asleep = true; Changed?.Invoke(); } // PBT_APMSUSPEND
        else if ((int)wParam is 7 or 18) { asleep = false; Changed?.Invoke(); } // Resume, wait for display status if off
        return 0;
    }
    // Exercise the real HWND message path without changing a runner's screen power.
    internal void SendTestDisplayState(bool awake)
    {
        nint data = Marshal.AllocHGlobal(24);
        try
        {
            Marshal.StructureToPtr(DisplayStatus, data, false);
            Marshal.WriteInt32(data, 16, 4); Marshal.WriteInt32(data, 20, awake ? 1 : 0);
            SendMessage(source.Handle, 0x0218, 0x8013, data);
        }
        finally { Marshal.FreeHGlobal(data); }
    }
    public void Dispose()
    {
        if (registration != 0) UnregisterPowerSettingNotification(registration);
        source.RemoveHook(Hook);
    }
    [DllImport("user32.dll", SetLastError = true)]
    private static extern nint RegisterPowerSettingNotification(nint recipient, ref Guid setting, int flags);
    [DllImport("user32.dll")]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static extern bool UnregisterPowerSettingNotification(nint handle);
    [DllImport("user32.dll")]
    private static extern nint SendMessage(nint hwnd, int message, nint wParam, nint lParam);
}
