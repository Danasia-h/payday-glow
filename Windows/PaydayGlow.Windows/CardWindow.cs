using System;
using System.ComponentModel;
using System.Windows;
using System.Windows.Automation;
using System.Windows.Controls;
using System.Windows.Input;
using System.Windows.Media;
using System.Windows.Shapes;
using PaydayGlow.Core;

namespace PaydayGlow.Windows;

internal sealed class CardWindow : Window
{
    private readonly TextBlock state = Theme.Text("上班中", 13, Brushes.White);
    private readonly Ellipse dot = new() { Width = 7, Height = 7, Fill = Theme.Mint, Margin = new Thickness(0, 0, 7, 0) };
    private readonly TextBlock percent = Theme.Text("0%", 24, Brushes.White, true);
    private readonly ProgressRing ring = new() { Width = 120, Height = 120 };
    internal readonly TextBlock Earnings = Theme.Text("¥ --.----", 30, Brushes.White, true);
    internal readonly TextBlock Countdown = Theme.Text("00:00:00", 21, Brushes.White, true);
    private readonly TextBlock countdownLabel = Theme.Text("下班倒计时", 12, Theme.Brush("#B4B8BD"));
    internal Button Gear { get; }
    public bool AllowClose { get; set; }

    public CardWindow(Action openSettings, Action quit)
    {
        Title = "PaydayGlow · 上班鼓励器";
        Width = 388; Height = 252;
        WindowStyle = WindowStyle.None;
        ResizeMode = ResizeMode.NoResize;
        AllowsTransparency = true;
        Background = Brushes.Transparent;
        ShowInTaskbar = false; Topmost = true; ShowActivated = false;
        FontFamily = new FontFamily("Microsoft YaHei UI, Segoe UI");
        var surface = new Border
        {
            CornerRadius = new CornerRadius(22), Padding = new Thickness(24, 21, 24, 21),
            Background = new SolidColorBrush(Color.FromArgb(158, 9, 14, 20)),
            BorderBrush = Theme.Brush("#516069"), BorderThickness = new Thickness(0.6)
        };
        var canvas = new Grid();
        canvas.RowDefinitions.Add(new RowDefinition { Height = new GridLength(25) });
        canvas.RowDefinitions.Add(new RowDefinition { Height = new GridLength(1, GridUnitType.Star) });
        canvas.RowDefinitions.Add(new RowDefinition { Height = new GridLength(28) });
        var header = new Grid();
        header.ColumnDefinitions.Add(new ColumnDefinition { Width = GridLength.Auto });
        header.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) });
        header.ColumnDefinitions.Add(new ColumnDefinition { Width = GridLength.Auto });
        header.Children.Add(Theme.Text("上班鼓励器", 16, Brushes.White, true));
        var badge = new StackPanel { Orientation = Orientation.Horizontal, Margin = new Thickness(13, 0, 0, 0), VerticalAlignment = VerticalAlignment.Center };
        badge.Children.Add(dot); badge.Children.Add(state); Grid.SetColumn(badge, 1); header.Children.Add(badge);
        Gear = new Button
        {
            Content = "\uE713", FontFamily = new FontFamily("Segoe MDL2 Assets"), FontSize = 18,
            Width = 27, Height = 27, Background = Brushes.Transparent, Foreground = Theme.Brush("#D6DADE"),
            BorderThickness = new Thickness(0), Cursor = Cursors.Hand, ToolTip = "工资设置"
        };
        AutomationProperties.SetName(Gear, "工资设置");
        Gear.Click += (_, _) => openSettings(); Grid.SetColumn(Gear, 2); header.Children.Add(Gear);
        canvas.Children.Add(header);

        var middle = new Grid { Margin = new Thickness(0, 15, 0, 12) };
        middle.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(120) });
        middle.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) });
        var ringGrid = new Grid { Width = 120, Height = 120 };
        ringGrid.Children.Add(ring);
        percent.HorizontalAlignment = HorizontalAlignment.Center; ringGrid.Children.Add(percent);
        middle.Children.Add(ringGrid);
        var amount = new StackPanel { VerticalAlignment = VerticalAlignment.Center, Margin = new Thickness(19, 0, 0, 0) };
        amount.Children.Add(Theme.Text("今天已赚", 13, Theme.Brush("#C8CCD1")));
        Earnings.FontFamily = new FontFamily("Segoe UI");
        var fitAmount = new Viewbox { Stretch = Stretch.Uniform, StretchDirection = StretchDirection.DownOnly, HorizontalAlignment = HorizontalAlignment.Left, Height = 44, Margin = new Thickness(0, 5, 0, 0), Child = Earnings };
        amount.Children.Add(fitAmount); Grid.SetColumn(amount, 1); middle.Children.Add(amount);
        Grid.SetRow(middle, 1); canvas.Children.Add(middle);
        var bottom = new DockPanel { LastChildFill = true };
        Countdown.FontFamily = new FontFamily("Consolas"); Countdown.HorizontalAlignment = HorizontalAlignment.Right;
        DockPanel.SetDock(countdownLabel, Dock.Left); bottom.Children.Add(countdownLabel); bottom.Children.Add(Countdown);
        Grid.SetRow(bottom, 2); canvas.Children.Add(bottom);
        AutomationProperties.SetAutomationId(Earnings, "liveEarnings");
        AutomationProperties.SetAutomationId(Countdown, "liveCountdown");
        surface.Child = canvas; Content = surface;
        surface.MouseLeftButtonDown += (_, e) =>
        {
            if (e.OriginalSource is DependencyObject item && HasButtonParent(item)) return;
            try { if (e.LeftButton == MouseButtonState.Pressed) DragMove(); } catch (InvalidOperationException) { }
        };
        var menu = new ContextMenu();
        Add("工资设置…", openSettings); Add("归位右下角", PositionBottomRight); Add("隐藏卡片", Hide);
        menu.Items.Add(new Separator()); Add("退出 PaydayGlow", quit);
        ContextMenu = menu;
        void Add(string text, Action callback) { var item = new MenuItem { Header = text }; item.Click += (_, _) => callback(); menu.Items.Add(item); }
        Loaded += (_, _) => PositionBottomRight();
        Closing += (_, e) => { if (!AllowClose) { e.Cancel = true; Hide(); } };
    }
    private static bool HasButtonParent(DependencyObject item)
    {
        while (item is not null)
        {
            if (item is System.Windows.Controls.Primitives.ButtonBase) return true;
            item = VisualTreeHelper.GetParent(item);
        }
        return false;
    }
    public void PositionBottomRight()
    {
        Rect area = SystemParameters.WorkArea;
        Left = Math.Max(area.Left, area.Right - Width - 24);
        Top = Math.Max(area.Top, area.Bottom - Height - 24);
    }
    public void Update(WageSnapshot value, bool configured)
    {
        Earnings.Text = configured ? "¥" + Theme.Money(value.Earned, 4) : "¥ --.----";
        ring.Progress = value.Progress; percent.Text = $"{(int)(value.Progress * 100)}%";
        state.Text = !configured ? "待设置" : value.Phase switch
        {
            WorkPhase.Working => "上班中", WorkPhase.OnBreak => "午休中", WorkPhase.Before => "待上班",
            WorkPhase.Overtime => "被白嫖中", WorkPhase.Finished => "已下班", _ => "休息中"
        };
        dot.Fill = value.Phase == WorkPhase.Overtime ? Brushes.Orange : Theme.Mint;
        countdownLabel.Text = value.Phase switch
        {
            WorkPhase.Before => "上班倒计时", WorkPhase.Overtime => "下班已超时", WorkPhase.Rest => "今天休息",
            WorkPhase.Finished => "今日已下班", _ => "下班倒计时"
        };
        Countdown.Text = value.Phase switch
        {
            WorkPhase.Before => WageEngine.Duration((value.Start - value.Now).TotalSeconds),
            WorkPhase.Overtime => "+" + WageEngine.Duration(value.Overtime), WorkPhase.Rest => "--:--:--",
            WorkPhase.Finished => "00:00:00", _ => WageEngine.Duration(value.Remaining)
        };
    }
}
