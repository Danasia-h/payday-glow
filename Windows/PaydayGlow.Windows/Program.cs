using System;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Reflection;
using System.Threading;
using System.Windows;
using System.Windows.Threading;
using PaydayGlow.Core;
using Forms = System.Windows.Forms;

namespace PaydayGlow.Windows;

internal static class Program
{
    [STAThread]
    public static int Main(string[] args)
    {
        int smokeIndex = Array.IndexOf(args, "--smoke-test");
        string? smokeDirectory = smokeIndex >= 0 && smokeIndex + 1 < args.Length ? Path.GetFullPath(args[smokeIndex + 1]) : null;
        using var mutex = new Mutex(true, smokeDirectory is null ? @"Local\PaydayGlow.Windows" : @"Local\PaydayGlow.Test." + Guid.NewGuid(), out bool created);
        if (!created) { MessageBox.Show("PaydayGlow 已在运行，请在任务栏右下角托盘中打开。", "PaydayGlow"); return 0; }
        try
        {
            var app = new GlowApplication(smokeDirectory);
            return app.Run();
        }
        catch (Exception error)
        {
            string folder = smokeDirectory ?? Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "PaydayGlow");
            Directory.CreateDirectory(folder); File.WriteAllText(Path.Combine(folder, "startup-error.txt"), error.ToString());
            if (smokeDirectory is null) MessageBox.Show("启动遇到问题。错误记录保存在：\n" + folder + "\n\n" + error.Message, "PaydayGlow");
            return 1;
        }
        finally { mutex.ReleaseMutex(); }
    }
}

internal sealed class GlowApplication : Application
{
    internal readonly SettingsStore Store;
    internal SavedState State;
    internal CardWindow Card = null!;
    internal SettingsWindow? SettingsDialog;
    internal DisplayPowerMonitor Power = null!;
    internal WageSnapshot Snapshot = null!;
    private readonly string? smokeDirectory;
    private readonly Stopwatch previewClock = Stopwatch.StartNew();
    private readonly DateTimeOffset previewStart = new(2026, 11, 3, 15, 24, 38, TimeSpan.FromHours(8));
    private readonly DispatcherTimer timer = new(DispatcherPriority.Normal) { Interval = TimeSpan.FromSeconds(1) };
    private Forms.NotifyIcon? tray;
    private CelebrationWindow? celebration;
    private int failedReminderWrites;
    internal bool SettingsSaved;

    public GlowApplication(string? smokeDirectory)
    {
        this.smokeDirectory = smokeDirectory;
        string directory = smokeDirectory is null
            ? Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "PaydayGlow")
            : Path.Combine(smokeDirectory, "isolated-profile");
        Store = new SettingsStore(directory); State = Store.Load();
        ShutdownMode = ShutdownMode.OnExplicitShutdown;
    }
    protected override void OnStartup(StartupEventArgs e)
    {
        base.OnStartup(e);
        Card = new CardWindow(OpenSettings, Quit); MainWindow = Card;
        Card.Show();
        Power = new DisplayPowerMonitor(Card); Power.Changed += Tick;
        SystemParameters.StaticPropertyChanged += ScreenParametersChanged;
        MakeTray(); Tick();
        timer.Tick += (_, _) => Tick(); timer.Start();
        if (!State.Configured) OpenSettings();
        if (Store.LoadWarning is string warning && smokeDirectory is null) MessageBox.Show(warning, "PaydayGlow", MessageBoxButton.OK, MessageBoxImage.Information);
        if (smokeDirectory is not null) Dispatcher.BeginInvoke(new Action(async () => await SmokeTest.Run(this, smokeDirectory)));
    }
    internal void Tick()
    {
        DateTimeOffset now = smokeDirectory is null ? DateTimeOffset.Now : previewStart.Add(previewClock.Elapsed);
        TimeZoneInfo? zone = smokeDirectory is null ? null : TimeZoneInfo.CreateCustomTimeZone("Preview +08", TimeSpan.FromHours(8), "Preview", "Preview");
        Snapshot = WageEngine.Snapshot(now, State.Settings, Power.ScreenAwake, zone);
        Card.Update(Snapshot, State.Configured);
        if (tray is not null) tray.Text = "PaydayGlow · 今日 ¥" + Theme.Money(Snapshot.Earned) + (Snapshot.Phase == WorkPhase.Overtime ? " · 被白嫖中" : "");
        if (WageEngine.ShouldRemind(Snapshot, State.Configured, Power.ScreenAwake, State.LastShiftId))
        {
            var updated = State with { LastShiftId = Snapshot.ShiftId };
            try { Store.Save(updated); State = updated; Celebrate(Snapshot.DayPay); }
            catch (Exception error) when (error is IOException or UnauthorizedAccessException)
            {
                // Suppress repeated alerts in memory if the disk is temporarily unavailable.
                State = updated;
                if (++failedReminderWrites == 1) tray?.ShowBalloonTip(5000, "PaydayGlow", "提醒记录未能保存到本机，重启后可能重复提醒。", Forms.ToolTipIcon.Info);
                Celebrate(Snapshot.DayPay);
            }
        }
    }
    private void MakeTray()
    {
        using var stream = GetResourceStream(new Uri("pack://application:,,,/Assets/AppIcon.ico"))!.Stream;
        tray = new Forms.NotifyIcon { Icon = new System.Drawing.Icon(stream), Text = "PaydayGlow", Visible = true };
        var menu = new Forms.ContextMenuStrip();
        Add("显示卡片", () => { Card.Show(); Card.PositionBottomRight(); }); Add("归位右下角", Card.PositionBottomRight);
        Add("隐藏卡片", Card.Hide); menu.Items.Add(new Forms.ToolStripSeparator());
        Add("工资设置…", OpenSettings); Add("预览下班弹窗", () => Celebrate(State.Settings.MonthlySalary / 21.5));
        menu.Items.Add(new Forms.ToolStripSeparator()); Add("退出 PaydayGlow", Quit);
        tray.ContextMenuStrip = menu;
        tray.DoubleClick += (_, _) => Dispatcher.Invoke(() => { Card.Show(); Card.PositionBottomRight(); });
        void Add(string title, Action callback) => menu.Items.Add(title, null, (_, _) => Dispatcher.Invoke(callback));
    }
    internal void OpenSettings()
    {
        if (SettingsDialog is not null) { SettingsDialog.Activate(); return; }
        SettingsDialog = new SettingsWindow(State.Settings, Save, Celebrate);
        SettingsDialog.Closed += (_, _) => SettingsDialog = null;
        SettingsDialog.Show(); SettingsDialog.Activate();
    }
    private string? Save(WageSettings value)
    {
        var updated = State with { Settings = value, Configured = true };
        try { Store.Save(updated); State = updated; SettingsSaved = true; Tick(); return null; }
        catch (Exception error) when (error is IOException or UnauthorizedAccessException)
        { return "无法保存设置，请检查本机用户目录是否可写。详情：" + error.Message; }
    }
    internal void Celebrate(double amount)
    { celebration?.Close(); celebration = new CelebrationWindow(amount); celebration.Show(); }
    internal CelebrationWindow? Celebration => celebration;
    private void ScreenParametersChanged(object? sender, System.ComponentModel.PropertyChangedEventArgs e)
    { if (e.PropertyName == nameof(SystemParameters.WorkArea)) Dispatcher.BeginInvoke(new Action(Card.PositionBottomRight)); }
    internal void Quit() { Card.AllowClose = true; SettingsDialog?.Close(); celebration?.Close(); Shutdown(); }
    protected override void OnExit(ExitEventArgs e)
    {
        timer.Stop(); Power?.Dispose();
        SystemParameters.StaticPropertyChanged -= ScreenParametersChanged;
        if (tray is not null) { tray.Visible = false; tray.Dispose(); }
        base.OnExit(e);
    }
}
