namespace PaydayGlow.Core;

public sealed record WageSettings
{
    public double MonthlySalary { get; init; } = 12000;
    public int StartMinute { get; init; } = 540;
    public int EndMinute { get; init; } = 1080;
    // Same numbering as the existing Mac app: Sunday = 1, Monday = 2.
    public int[] Weekdays { get; init; } = [2, 3, 4, 5, 6];
    public bool HasBreak { get; init; } = true;
    public int BreakStartMinute { get; init; } = 720;
    public int BreakEndMinute { get; init; } = 780;
    public int ShiftMinutes => (EndMinute - StartMinute + 1440) % 1440;
    public int Offset(int minute) => (minute - StartMinute + 1440) % 1440;

    public string? Validate()
    {
        if (!double.IsFinite(MonthlySalary) || MonthlySalary <= 0 || MonthlySalary > 1_000_000_000)
            return "请输入大于 0、不超过 10 亿元的月薪。";
        if (new[] { StartMinute, EndMinute, BreakStartMinute, BreakEndMinute }.Any(m => m < 0 || m >= 1440))
            return "请输入有效时间（00:00 至 23:59）。";
        if (Weekdays is null || Weekdays.Length == 0 || Weekdays.Any(d => d < 1 || d > 7))
            return "请至少选择一个有效工作日。";
        if (ShiftMinutes == 0) return "上下班时间不能相同；下班早于上班时视为跨夜班次。";
        if (HasBreak)
        {
            int start = Offset(BreakStartMinute), end = Offset(BreakEndMinute);
            if (end <= start || start >= ShiftMinutes || end > ShiftMinutes || end - start >= ShiftMinutes)
                return "午休须在班次内，结束晚于开始，且不能占满整个班次。";
        }
        return null;
    }
}

public enum WorkPhase { Before, Working, OnBreak, Overtime, Finished, Rest }

public sealed record WageSnapshot(
    WorkPhase Phase, DateTimeOffset Now, DateTimeOffset Start, DateTimeOffset End,
    string ShiftId, double DayPay, double SecondPay, double Earned, double Progress,
    double Remaining, double Overtime, double PaidSeconds, bool IsWorkingDay)
{
    public double AverageDays => 21.5;
}

public static class WageEngine
{
    public static WageSnapshot Snapshot(DateTimeOffset now, WageSettings settings, bool screenAwake, TimeZoneInfo? zone = null)
    {
        if (settings.Validate() is string error) throw new ArgumentException(error, nameof(settings));
        zone ??= TimeZoneInfo.Local;
        DateTime local = TimeZoneInfo.ConvertTime(now, zone).DateTime;
        DateTime day = local.Date;
        if (settings.EndMinute < settings.StartMinute && local.Hour * 60 + local.Minute < settings.StartMinute)
            day = day.AddDays(-1);

        DateTimeOffset At(int minute, bool nextDay = false)
        {
            DateTime time = DateTime.SpecifyKind(day.AddDays(nextDay ? 1 : 0).AddMinutes(minute), DateTimeKind.Unspecified);
            // Follow the first valid wall time if a DST jump skips a scheduled minute.
            while (zone.IsInvalidTime(time)) time = time.AddMinutes(1);
            return new DateTimeOffset(time, zone.GetUtcOffset(time));
        }
        DateTimeOffset start = At(settings.StartMinute);
        DateTimeOffset end = At(settings.EndMinute, settings.EndMinute <= settings.StartMinute);
        DateTimeOffset? bs = settings.HasBreak ? At(settings.BreakStartMinute, settings.BreakStartMinute < settings.StartMinute) : null;
        DateTimeOffset? be = settings.HasBreak ? At(settings.BreakEndMinute, settings.BreakEndMinute < settings.StartMinute) : null;
        double paidSeconds = Math.Max(1, (end - start).TotalSeconds - (bs.HasValue ? (be!.Value - bs.Value).TotalSeconds : 0));
        double dayPay = settings.MonthlySalary / 21.5;
        double rate = dayPay / paidSeconds;
        bool workingDay = settings.Weekdays.Contains((int)day.DayOfWeek + 1);
        DateTimeOffset boundedNow = now < end ? now : end;
        double elapsed = Math.Max(0, (boundedNow - start).TotalSeconds);
        if (bs.HasValue)
        {
            DateTimeOffset breakBound = boundedNow < be!.Value ? boundedNow : be.Value;
            elapsed -= Math.Max(0, (breakBound - bs.Value).TotalSeconds);
        }
        elapsed = Math.Clamp(elapsed, 0, paidSeconds);
        WorkPhase phase = !workingDay ? WorkPhase.Rest : now < start ? WorkPhase.Before : now >= end
            ? (screenAwake ? WorkPhase.Overtime : WorkPhase.Finished)
            : bs.HasValue && now >= bs.Value && now < be!.Value ? WorkPhase.OnBreak : WorkPhase.Working;
        return new(phase, now, start, end, $"{day:yyyy-MM-dd}-{settings.StartMinute}-{settings.EndMinute}",
            dayPay, rate, workingDay ? elapsed * rate : 0, workingDay ? elapsed / paidSeconds : 0,
            Math.Max(0, (end - now).TotalSeconds), workingDay ? Math.Max(0, (now - end).TotalSeconds) : 0,
            paidSeconds, workingDay);
    }

    public static bool ShouldRemind(WageSnapshot value, bool configured, bool screenAwake, string? lastShiftId) =>
        configured && screenAwake && value.IsWorkingDay && value.Now >= value.End && value.ShiftId != lastShiftId;

    public static string Duration(double seconds)
    {
        long total = (long)Math.Ceiling(Math.Max(0, seconds));
        return $"{total / 3600:00}:{total / 60 % 60:00}:{total % 60:00}";
    }
}
