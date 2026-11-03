using System;
using System.Collections.Generic;
using System.IO;
using System.Text.Json;
using System.Threading.Tasks;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Media;
using System.Windows.Media.Imaging;
using PaydayGlow.Core;

namespace PaydayGlow.Windows;

// Opt-in CI mode with an isolated profile and an advancing example clock.
// It is never used on a normal double-click launch.
internal static class SmokeTest
{
    public static async Task Run(GlowApplication app, string directory)
    {
        Directory.CreateDirectory(directory);
        var checks = new Dictionary<string, bool>();
        void Check(string key, bool value) { checks[key] = value; if (!value) throw new InvalidOperationException(key); }
        try
        {
            await Task.Delay(500);
            Check("first_run_opens_settings", !app.State.Configured && app.SettingsDialog?.IsVisible == true);
            Capture(app.SettingsDialog!, Path.Combine(directory, "settings.png"));
            app.SettingsDialog!.SaveButton.RaiseEvent(new RoutedEventArgs(Button.ClickEvent));
            Check("save_button_persists_and_closes", app.State.Configured && app.SettingsSaved && app.SettingsDialog is null);
            Check("settings_reload", app.Store.Load().Configured && app.Store.Load().Settings.MonthlySalary == 12000);
            double firstRemaining = app.Snapshot.Remaining;
            double firstEarned = app.Snapshot.Earned;
            string firstText = app.Card.Countdown.Text;
            await Task.Delay(3300);
            double secondRemaining = app.Snapshot.Remaining;
            double secondEarned = app.Snapshot.Earned;
            Check("dispatcher_updates_countdown", firstRemaining - secondRemaining >= 2 && firstText != app.Card.Countdown.Text);
            Check("dispatcher_updates_earnings", secondEarned > firstEarned);
            Check("rate_matches_elapsed_time", Math.Abs((secondEarned - firstEarned) - (firstRemaining - secondRemaining) * app.Snapshot.SecondPay) < 0.0001);
            Check("transparent_window", app.Card.AllowsTransparency && app.Card.Background == Brushes.Transparent);
            Check("bottom_right_placement", Math.Abs(app.Card.Left + app.Card.Width + 24 - SystemParameters.WorkArea.Right) < 2 && Math.Abs(app.Card.Top + app.Card.Height + 24 - SystemParameters.WorkArea.Bottom) < 2);
            Check("topmost_without_taskbar", app.Card.Topmost && !app.Card.ShowInTaskbar);
            Capture(app.Card, Path.Combine(directory, "card.png"));
            app.Card.Gear.RaiseEvent(new RoutedEventArgs(Button.ClickEvent));
            Check("gear_opens_settings", app.SettingsDialog?.IsVisible == true);
            app.SettingsDialog!.Close();
            app.Power.SendTestDisplayState(false);
            Check("power_message_off", !app.Power.ScreenAwake);
            app.Power.SendTestDisplayState(true);
            Check("power_message_on", app.Power.ScreenAwake);
            app.Card.Hide(); Check("can_hide_card", !app.Card.IsVisible);
            app.Card.Show(); Check("can_show_card", app.Card.IsVisible);

            var settings = app.State.Settings;
            var zone = TimeZoneInfo.CreateCustomTimeZone("Smoke", TimeSpan.FromHours(8), "Smoke", "Smoke");
            var overtime = WageEngine.Snapshot(new DateTimeOffset(2026, 11, 3, 19, 24, 38, TimeSpan.FromHours(8)), settings, true, zone);
            app.Card.Update(overtime, true); Capture(app.Card, Path.Combine(directory, "overtime.png"));
            Check("overtime_display", app.Card.Countdown.Text.StartsWith('+') && Math.Abs(overtime.Earned - overtime.DayPay) < 0.00001);
            app.Celebrate(overtime.DayPay);
            await Task.Delay(200);
            Check("celebration_window", app.Celebration?.IsVisible == true);
            Capture(app.Celebration!, Path.Combine(directory, "celebration.png"));
            var report = new
            {
                passed = true, checks, count = checks.Count, os = Environment.OSVersion.ToString(),
                architecture = System.Runtime.InteropServices.RuntimeInformation.ProcessArchitecture.ToString(),
                firstEarned, secondEarned, firstRemaining, secondRemaining,
                displayNotificationRegistered = app.Power.Registered,
                boundary = "Display power messages were injected into the actual HWND; hardware sleep/wake was not performed. The test uses an advancing sample clock and an isolated temporary profile."
            };
            File.WriteAllText(Path.Combine(directory, "smoke-report.json"), JsonSerializer.Serialize(report, new JsonSerializerOptions { WriteIndented = true }));
            app.Quit();
        }
        catch (Exception error)
        {
            File.WriteAllText(Path.Combine(directory, "smoke-report.json"), JsonSerializer.Serialize(new { passed = false, checks, error = error.ToString() }, new JsonSerializerOptions { WriteIndented = true }));
            app.Shutdown(1);
        }
    }
    private static void Capture(Window window, string path)
    {
        window.UpdateLayout();
        var content = (FrameworkElement)window.Content;
        double width = Math.Max(content.ActualWidth, 1), height = Math.Max(content.ActualHeight, 1);
        var bitmap = new RenderTargetBitmap((int)Math.Ceiling(width * 2), (int)Math.Ceiling(height * 2), 192, 192, PixelFormats.Pbgra32);
        bitmap.Render(content);
        var encoder = new PngBitmapEncoder(); encoder.Frames.Add(BitmapFrame.Create(bitmap));
        using var stream = File.Create(path); encoder.Save(stream);
    }
}
