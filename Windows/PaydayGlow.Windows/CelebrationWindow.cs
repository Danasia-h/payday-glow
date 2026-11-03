using System;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Media;
using System.Windows.Threading;

namespace PaydayGlow.Windows;

internal sealed class CelebrationWindow : Window
{
    private readonly DispatcherTimer timer = new() { Interval = TimeSpan.FromSeconds(14) };
    public CelebrationWindow(double amount)
    {
        Title = "下班快乐！"; Width = 360; Height = 245;
        WindowStyle = WindowStyle.None; AllowsTransparency = true; Background = Brushes.Transparent;
        ResizeMode = ResizeMode.NoResize; ShowInTaskbar = false; Topmost = true; ShowActivated = false;
        var body = new StackPanel { Margin = new Thickness(23), HorizontalAlignment = HorizontalAlignment.Center };
        var title = Theme.Text("下班快乐！", 25, Theme.Pine, true); title.HorizontalAlignment = HorizontalAlignment.Center; body.Children.Add(title);
        var pay = Theme.Text("恭喜，今天赚了 ¥" + Theme.Money(amount), 16, Theme.Pine, true); pay.Margin = new Thickness(0, 18, 0, 12); pay.HorizontalAlignment = HorizontalAlignment.Center; body.Children.Add(pay);
        var copy = Theme.Text("今天的努力，值得一个准点下班。", 12, Theme.Muted); copy.HorizontalAlignment = HorizontalAlignment.Center; body.Children.Add(copy);
        var done = Theme.Button("收工！", Close, true); done.Margin = new Thickness(0, 23, 0, 0); done.HorizontalAlignment = HorizontalAlignment.Center; done.MinWidth = 125; body.Children.Add(done);
        Content = new Border { CornerRadius = new CornerRadius(20), Background = Theme.Paper, Child = body, BorderBrush = Theme.Brush("#CDD8CB"), BorderThickness = new Thickness(1) };
        Loaded += (_, _) => { var area = SystemParameters.WorkArea; Left = area.Right - Width - 24; Top = area.Top + 24; timer.Start(); };
        timer.Tick += (_, _) => Close(); Closed += (_, _) => timer.Stop();
    }
}
