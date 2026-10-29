import Foundation

// Live mode follows wall time; preview mode advances from its example date
// using elapsed uptime, so a preview never leaves the UI frozen.
struct WageClock {
    var previewStart: Date?
    var originUptime: TimeInterval
    func now(wallTime: Date = Date(), uptime: TimeInterval = ProcessInfo.processInfo.systemUptime) -> Date {
        guard let previewStart = previewStart else { return wallTime }
        return previewStart.addingTimeInterval(max(0, uptime - originUptime))
    }
}

struct WageSettings: Codable, Equatable {
    var monthlySalary: Double = 12000
    var startMinute = 9 * 60
    var endMinute = 18 * 60
    var weekdays: Set<Int> = [2, 3, 4, 5, 6]
    var hasBreak = true
    var breakStartMinute = 12 * 60
    var breakEndMinute = 13 * 60

    var shiftMinutes: Int { (endMinute - startMinute + 1440) % 1440 }
    func offset(_ minute: Int) -> Int { (minute - startMinute + 1440) % 1440 }
    var breakRange: Range<Int>? {
        guard hasBreak else { return nil }
        return offset(breakStartMinute)..<max(offset(breakStartMinute), offset(breakEndMinute))
    }
    var paidMinutes: Int { shiftMinutes - (breakRange?.count ?? 0) }
    var validationError: String? {
        guard monthlySalary.isFinite, monthlySalary > 0, monthlySalary <= 1_000_000_000 else { return "请输入大于 0、不超过 10 亿元的月薪。" }
        guard !weekdays.isEmpty else { return "请至少选择一个工作日。" }
        guard shiftMinutes > 0 else { return "上下班时间不能相同；跨夜班次可直接设置。" }
        if hasBreak {
            guard let range = breakRange, !range.isEmpty, range.lowerBound < shiftMinutes, range.upperBound <= shiftMinutes, paidMinutes > 0 else { return "午休须在班次内，结束晚于开始，且不能占满整个班次。" }
        }
        return nil
    }
}

enum WorkPhase: String { case before, working, onBreak, overtime, finished, rest }

struct ReminderGate {
    var lastShiftID: String
    mutating func consume(_ snapshot: WageSnapshot, configured: Bool, screenAwake: Bool) -> Bool {
        guard configured, screenAwake, snapshot.isWorkingDay,
              snapshot.now >= snapshot.end, lastShiftID != snapshot.shiftID else { return false }
        lastShiftID = snapshot.shiftID
        return true
    }
}

struct WageSnapshot {
    var phase: WorkPhase
    var now: Date
    var start: Date
    var end: Date
    var shiftID: String
    var averageDays: Double
    var monthDays: Int
    var dayPay: Double
    var secondPay: Double
    var earned: Double
    var progress: Double
    var remaining: TimeInterval
    var overtime: TimeInterval
    var paidSeconds: TimeInterval
    var isWorkingDay: Bool
}

struct WageEngine {
    var calendar: Calendar = .current

    func workdays(in interval: DateInterval, settings: WageSettings) -> Int {
        var date = calendar.startOfDay(for: interval.start)
        var count = 0
        while date < interval.end {
            if settings.weekdays.contains(calendar.component(.weekday, from: date)) { count += 1 }
            guard let next = calendar.date(byAdding: .day, value: 1, to: date) else { break }
            date = next
        }
        return count
    }

    func shift(on day: Date, settings: WageSettings) -> (Date, Date, Date?, Date?) {
        let base = calendar.startOfDay(for: day)
        func time(_ minute: Int, dayOffset: Int = 0) -> Date {
            let date = calendar.date(byAdding: .day, value: dayOffset, to: base)!
            return calendar.date(bySettingHour: minute / 60, minute: minute % 60, second: 0, of: date)!
        }
        let start = time(settings.startMinute)
        let end = time(settings.endMinute, dayOffset: settings.endMinute <= settings.startMinute ? 1 : 0)
        guard settings.hasBreak else { return (start, end, nil, nil) }
        return (start, end,
                time(settings.breakStartMinute, dayOffset: settings.breakStartMinute < settings.startMinute ? 1 : 0),
                time(settings.breakEndMinute, dayOffset: settings.breakEndMinute < settings.startMinute ? 1 : 0))
    }

    func snapshot(at now: Date, settings: WageSettings, screenAwake: Bool) -> WageSnapshot {
        var day = calendar.startOfDay(for: now)
        // An overnight shift belongs to the date on which it starts. Keep yesterday's
        // shift until the next scheduled start, including its overtime period.
        if settings.endMinute < settings.startMinute,
           calendar.component(.hour, from: now) * 60 + calendar.component(.minute, from: now) < settings.startMinute {
            day = calendar.date(byAdding: .day, value: -1, to: day)!
        }
        let (start, end, breakStart, breakEnd) = shift(on: day, settings: settings)
        let month = calendar.dateInterval(of: .month, for: day)!
        let average = 21.5
        let dayPay = settings.monthlySalary / max(average, 1)
        let paidSeconds = max(1, end.timeIntervalSince(start) - (breakEnd?.timeIntervalSince(breakStart ?? end) ?? 0))
        let rate = dayPay / paidSeconds
        let workingDay = settings.weekdays.contains(calendar.component(.weekday, from: day))
        var elapsed = max(0, min(now, end).timeIntervalSince(start))
        if let bs = breakStart, let be = breakEnd {
            elapsed -= max(0, min(now, be, end).timeIntervalSince(max(start, bs)))
        }
        elapsed = max(0, min(paidSeconds, elapsed))
        let phase: WorkPhase
        if !workingDay { phase = .rest }
        else if now < start { phase = .before }
        else if now >= end { phase = screenAwake ? .overtime : .finished }
        else if let bs = breakStart, let be = breakEnd, now >= bs && now < be { phase = .onBreak }
        else { phase = .working }
        let c = calendar.dateComponents([.year, .month, .day], from: day)
        return WageSnapshot(phase: phase, now: now, start: start, end: end,
                            shiftID: "\(c.year!)-\(c.month!)-\(c.day!)-\(settings.startMinute)-\(settings.endMinute)",
                            averageDays: average, monthDays: workdays(in: month, settings: settings),
                            dayPay: dayPay, secondPay: rate, earned: workingDay ? elapsed * rate : 0,
                            progress: workingDay ? elapsed / paidSeconds : 0,
                            remaining: max(0, end.timeIntervalSince(now)),
                            overtime: workingDay ? max(0, now.timeIntervalSince(end)) : 0,
                            paidSeconds: paidSeconds, isWorkingDay: workingDay)
    }
}

func money(_ value: Double) -> String { String(format: "%.2f", value) }
func duration(_ seconds: TimeInterval) -> String {
    let total = Int(max(0, seconds).rounded(.up))
    return String(format: "%02d:%02d:%02d", total / 3600, total / 60 % 60, total % 60)
}
func clockTime(_ minute: Int) -> String { String(format: "%02d:%02d", minute / 60, minute % 60) }
