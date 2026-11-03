using System;
using System.Globalization;
using System.Linq;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Media;
using PaydayGlow.Core;

namespace PaydayGlow.Windows;

internal sealed class SettingsWindow : Window
{
    private readonly TextBox salary, start, end, breakStart, breakEnd;
    private readonly CheckBox hasBreak;
    private readonly CheckBox[] weekdays;
    private readonly TextBlock error;
    internal Button SaveButton { get; }

    public SettingsWindow(WageSettings current, Func<WageSettings, string?> save, Action<double> preview)
    {
        Title = "PaydayGlow · 工资设置"; Width = 550; SizeToContent = SizeToContent.Height;
        ResizeMode = ResizeMode.NoResize; WindowStartupLocation = WindowStartupLocation.CenterScreen;
        MaxHeight = Math.Max(350, SystemParameters.WorkArea.Height - 24);
        Background = Theme.Paper; FontFamily = new FontFamily("Microsoft YaHei UI, Segoe UI");
        var body = new StackPanel { Margin = new Thickness(27, 22, 27, 24) };
        body.Children.Add(Theme.Text("设置你的赚钱时钟", 23, bold: true));
        var average = Theme.Text("月均工作日固定为 21.5 天", 12, Theme.Muted); average.Margin = new Thickness(0, 7, 0, 19); body.Children.Add(average);
        salary = Field(Theme.Money(current.MonthlySalary), 25);
        AddField(body, "每月工资（元）", salary);
        start = Field(Time(current.StartMinute)); end = Field(Time(current.EndMinute));
        body.Children.Add(Row("上班时间", start, "下班时间", end));
        hasBreak = new CheckBox { Content = "扣除不计薪午休", IsChecked = current.HasBreak, Margin = new Thickness(0, 18, 0, 5), FontSize = 13, Foreground = Theme.Ink };
        body.Children.Add(hasBreak);
        breakStart = Field(Time(current.BreakStartMinute)); breakEnd = Field(Time(current.BreakEndMinute));
        body.Children.Add(Row("午休开始", breakStart, "午休结束", breakEnd));
        hasBreak.Checked += (_, _) => BreakEnabled(true);
        hasBreak.Unchecked += (_, _) => BreakEnabled(false);
        BreakEnabled(current.HasBreak);
        var daysTitle = Theme.Text("每周工作日", bold: true); daysTitle.Margin = new Thickness(0, 19, 0, 10); body.Children.Add(daysTitle);
        var days = new System.Windows.Controls.Primitives.UniformGrid { Columns = 7 };
        int[] order = [2, 3, 4, 5, 6, 7, 1]; string[] labels = ["一", "二", "三", "四", "五", "六", "日"];
        weekdays = new CheckBox[7];
        for (int i = 0; i < 7; i++)
        {
            weekdays[i] = new CheckBox { Content = "周" + labels[i], Tag = order[i], IsChecked = current.Weekdays.Contains(order[i]), FontSize = 12, Foreground = Theme.Ink, Margin = new Thickness(0, 0, 3, 0) };
            days.Children.Add(weekdays[i]);
        }
        body.Children.Add(days);
        error = Theme.Text("", 12, Theme.Brush("#A13C26")); error.TextWrapping = TextWrapping.Wrap; error.MinHeight = 35; error.Margin = new Thickness(0, 15, 0, 3); body.Children.Add(error);
        var note = Theme.Text("24 小时制，例如 09:30。下班早于上班时视为次日下班。\n仅按班次估算，不含节假日调休、请假、税费及加班费。\n设置仅保存在这台电脑，不上传，不随 EXE 发给别人。", 11, Theme.Muted);
        note.TextWrapping = TextWrapping.Wrap; note.LineHeight = 20; body.Children.Add(note);
        var buttons = new DockPanel { Margin = new Thickness(0, 20, 0, 0) };
        var test = Theme.Button("预览下班弹窗", () => preview(Parse(out _)?.MonthlySalary / 21.5 ?? current.MonthlySalary / 21.5));
        DockPanel.SetDock(test, Dock.Left); buttons.Children.Add(test);
        SaveButton = Theme.Button("保存并开始", () =>
        {
            var value = Parse(out string? issue);
            if (value is null) { error.Text = issue; return; }
            string? result = save(value);
            if (result is not null) { error.Text = result; return; }
            Close();
        }, true);
        SaveButton.IsDefault = true; SaveButton.HorizontalAlignment = HorizontalAlignment.Right; buttons.Children.Add(SaveButton);
        body.Children.Add(buttons);
        Content = new Border
        {
            Background = Theme.Paper,
            Child = new ScrollViewer { Content = body, VerticalScrollBarVisibility = ScrollBarVisibility.Auto, HorizontalScrollBarVisibility = ScrollBarVisibility.Disabled }
        };
    }
    private void BreakEnabled(bool enabled) { breakStart.IsEnabled = enabled; breakEnd.IsEnabled = enabled; }
    private static TextBox Field(string text, double size = 15) => new()
    { Text = text, FontSize = size, Padding = new Thickness(10, 7, 10, 7), Background = Brushes.White, Foreground = Theme.Ink, BorderBrush = Theme.Brush("#DADFD7"), BorderThickness = new Thickness(1) };
    private static void AddField(StackPanel parent, string label, TextBox field)
    { var title = Theme.Text(label, 12, Theme.Muted); title.Margin = new Thickness(0, 0, 0, 7); parent.Children.Add(title); parent.Children.Add(field); }
    private static Grid Row(string leftLabel, TextBox left, string rightLabel, TextBox right)
    {
        var row = new Grid { Margin = new Thickness(0, 16, 0, 0) };
        row.ColumnDefinitions.Add(new ColumnDefinition()); row.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(22) }); row.ColumnDefinitions.Add(new ColumnDefinition());
        var first = new StackPanel(); AddField(first, leftLabel, left); row.Children.Add(first);
        var second = new StackPanel(); AddField(second, rightLabel, right); Grid.SetColumn(second, 2); row.Children.Add(second); return row;
    }
    private static string Time(int minutes) => $"{minutes / 60:00}:{minutes % 60:00}";
    private static int? Minutes(string value) => TimeOnly.TryParseExact(value.Trim(), ["HH:mm", "H:mm"], CultureInfo.InvariantCulture, DateTimeStyles.None, out var time) ? time.Hour * 60 + time.Minute : null;
    private WageSettings? Parse(out string? issue)
    {
        issue = null;
        if (!double.TryParse(salary.Text.Trim().Replace(",", ""), NumberStyles.Float, CultureInfo.InvariantCulture, out var pay)) { issue = "请输入有效的月薪金额。"; return null; }
        int? a = Minutes(start.Text), b = Minutes(end.Text), c = Minutes(breakStart.Text), d = Minutes(breakEnd.Text);
        if (a is null || b is null || hasBreak.IsChecked == true && (c is null || d is null)) { issue = "时间请填写 24 小时制 HH:mm，例如 09:30。"; return null; }
        var value = new WageSettings { MonthlySalary = pay, StartMinute = a.Value, EndMinute = b.Value, HasBreak = hasBreak.IsChecked == true, BreakStartMinute = c ?? 720, BreakEndMinute = d ?? 780, Weekdays = weekdays.Where(w => w.IsChecked == true).Select(w => (int)w.Tag).ToArray() };
        issue = value.Validate(); return issue is null ? value : null;
    }
}
