using System;
using System.Globalization;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Media;

namespace PaydayGlow.Windows;

internal static class Theme
{
    public static readonly SolidColorBrush Mint = Brush("#62F8C2");
    public static readonly SolidColorBrush Pine = Brush("#193F33");
    public static readonly SolidColorBrush Ink = Brush("#27362F");
    public static readonly SolidColorBrush Muted = Brush("#7D8982");
    public static readonly SolidColorBrush Paper = Brush("#F6F6F0");
    public static SolidColorBrush Brush(string hex) => new((Color)ColorConverter.ConvertFromString(hex));
    public static string Money(double value, int digits = 2) => value.ToString("F" + digits, CultureInfo.InvariantCulture);
    public static TextBlock Text(string text, double size = 13, Brush? brush = null, bool bold = false) => new()
    {
        Text = text, FontSize = size, Foreground = brush ?? Ink,
        FontFamily = new FontFamily("Microsoft YaHei UI, Segoe UI"),
        FontWeight = bold ? FontWeights.SemiBold : FontWeights.Normal,
        VerticalAlignment = VerticalAlignment.Center
    };
    public static Button Button(string text, Action action, bool primary = false)
    {
        var value = new Button
        {
            Content = text, Padding = new Thickness(17, 9, 17, 9), FontSize = 13,
            Cursor = System.Windows.Input.Cursors.Hand,
            Background = primary ? Pine : Brushes.White,
            Foreground = primary ? Brushes.White : Ink,
            BorderThickness = new Thickness(0), MinHeight = 36
        };
        value.Click += (_, _) => action();
        return value;
    }
}

internal sealed class ProgressRing : FrameworkElement
{
    private double progress;
    public double Progress { get => progress; set { progress = Math.Clamp(value, 0, 1); InvalidateVisual(); } }
    protected override void OnRender(DrawingContext dc)
    {
        base.OnRender(dc);
        var center = new Point(ActualWidth / 2, ActualHeight / 2);
        double radius = Math.Min(ActualWidth, ActualHeight) / 2 - 7;
        dc.DrawEllipse(null, new Pen(Theme.Brush("#304F48"), 10), center, radius, radius);
        var pen = new Pen(Theme.Mint, 10) { StartLineCap = PenLineCap.Round, EndLineCap = PenLineCap.Round };
        if (progress >= 0.999999) dc.DrawEllipse(null, pen, center, radius, radius);
        else if (progress > 0)
        {
            double angle = 2 * Math.PI * progress - Math.PI / 2;
            var arc = new StreamGeometry();
            using (var g = arc.Open())
            {
                g.BeginFigure(new Point(center.X, center.Y - radius), false, false);
                g.ArcTo(new Point(center.X + radius * Math.Cos(angle), center.Y + radius * Math.Sin(angle)),
                    new Size(radius, radius), 0, progress > 0.5, SweepDirection.Clockwise, true, false);
            }
            dc.DrawGeometry(null, pen, arc);
        }
    }
}
