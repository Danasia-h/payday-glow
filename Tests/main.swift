import Foundation

var calendar = Calendar(identifier: .gregorian)
calendar.timeZone = TimeZone(identifier: "Asia/Shanghai")!
let engine = WageEngine(calendar: calendar)
func date(_ day: Int = 22, _ hour: Int, _ minute: Int = 0, _ second: Int = 0) -> Date {
    calendar.date(from: DateComponents(year: 2026, month: 10, day: day, hour: hour, minute: minute, second: second))!
}
var count = 0
func check(_ condition: @autoclosure () -> Bool, _ name: String) {
    guard condition() else { fatalError("FAILED: \(name)") }
    count += 1
    print("PASS \(name)")
}
func close(_ lhs: Double, _ rhs: Double) -> Bool { abs(lhs - rhs) < 0.000001 }
var settings = WageSettings()
settings.monthlySalary = 21500
func snap(_ day: Int = 22, _ hour: Int, _ minute: Int = 0, _ second: Int = 0, awake: Bool = true) -> WageSnapshot {
    engine.snapshot(at: date(day, hour, minute, second), settings: settings, screenAwake: awake)
}
check(settings.validationError == nil, "default settings valid")
check(close(snap(22, 10).averageDays, 21.5), "fixed monthly average 21.5")
check(close(snap(22, 10).dayPay, 1000), "daily earnings use 21.5")
check(close(snap(22, 10).secondPay, 1000 / 28800), "per second deducts one hour break")
check(snap(22, 8).phase == .before && snap(22, 8).earned == 0, "before work earns zero")
check(snap(22, 9).phase == .working && snap(22, 9).earned == 0, "shift starts exactly")
check(close(snap(22, 10).earned, 125), "one paid hour")
check(snap(22, 12).phase == .onBreak, "lunch starts exactly")
check(close(snap(22, 12, 30).earned, 375), "lunch does not increase earnings")
check(snap(22, 13).phase == .working && close(snap(22, 13).earned, 375), "lunch ends exactly")
check(snap(22, 17, 59, 59).remaining == 1, "one second before finish")
check(snap(22, 18).phase == .overtime && close(snap(22, 18).earned, 1000), "end time celebrates full daily wage")
check(snap(22, 20).phase == .overtime && snap(22, 20).overtime == 7200, "lit screen shows overtime")
check(close(snap(22, 20).earned, 1000), "overtime never increases income")
check(snap(22, 20, awake: false).phase == .finished, "sleeping screen is not overtime")
check(snap(25, 20).phase == .rest && snap(25, 20).earned == 0, "Sunday rest does not earn or trigger overtime")
check(snap(22, 10).monthDays == 22, "calendar counts October workdays")
check(close(snap(22, 10, awake: false).earned, 125), "screen sleep does not reduce scheduled salary")
settings.hasBreak = false
check(close(snap(22, 10).secondPay, 1000 / 32400), "no break includes all nine hours")
settings.startMinute = 22 * 60
settings.endMinute = 6 * 60
check(settings.validationError == nil, "overnight valid")
check(snap(23, 2).phase == .working && close(snap(23, 2).earned, 500), "overnight uses yesterday shift")
check(snap(23, 6).phase == .overtime && close(snap(23, 6).earned, 1000), "overnight ends next morning")
check(snap(24, 2).phase == .working, "Friday overnight continues on Saturday")
check(snap(25, 2).phase == .rest, "Saturday overnight is a rest shift")
settings.hasBreak = true
settings.breakStartMinute = 2 * 60
settings.breakEndMinute = 3 * 60
check(settings.validationError == nil && snap(23, 2, 30).phase == .onBreak, "overnight lunch supported")
settings.breakEndMinute = 21 * 60
check(settings.validationError != nil, "out of shift lunch rejected")
settings = WageSettings(); settings.monthlySalary = 0
check(settings.validationError != nil, "zero salary rejected")
settings.monthlySalary = .nan
check(settings.validationError != nil, "non finite salary rejected")
settings = WageSettings(); settings.weekdays = []
check(settings.validationError != nil, "empty workweek rejected")
settings = WageSettings(); settings.endMinute = settings.startMinute
check(settings.validationError != nil, "zero length shift rejected")
settings = WageSettings(); settings.breakEndMinute = settings.breakStartMinute
check(settings.validationError != nil, "zero break rejected")
check(duration(3599.1) == "01:00:00" && duration(-1) == "00:00:00", "countdown rounds and never goes negative")
settings = WageSettings()
var gate = ReminderGate(lastShiftID: "")
check(!gate.consume(snap(22, 17, 59, 59), configured: true, screenAwake: true), "no reminder before finish")
check(!gate.consume(snap(22, 18), configured: false, screenAwake: true), "example salary never triggers reminder")
check(!gate.consume(snap(22, 18, awake: false), configured: true, screenAwake: false), "sleeping screen defers reminder")
check(gate.consume(snap(22, 18), configured: true, screenAwake: true), "finish while awake triggers reminder")
check(!gate.consume(snap(22, 20), configured: true, screenAwake: true), "repeat ticks do not duplicate reminder")
var reopened = ReminderGate(lastShiftID: gate.lastShiftID)
check(!reopened.consume(snap(22, 21), configured: true, screenAwake: true), "saved marker prevents reminder after restart")
check(reopened.consume(snap(23, 18), configured: true, screenAwake: true), "next workday triggers new reminder")
check(!reopened.consume(snap(25, 18), configured: true, screenAwake: true), "rest day never triggers reminder")
let realClock = WageClock(previewStart: nil, originUptime: 100)
check(realClock.now(wallTime: date(22, 10), uptime: 110) == date(22, 10), "live clock follows actual wall time")
check(realClock.now(wallTime: date(22, 10, 0, 5), uptime: 115) == date(22, 10, 0, 5), "live clock keeps advancing")
var previewClock = WageClock(previewStart: date(22, 15), originUptime: 100)
let previewFirst = previewClock.now(wallTime: date(22, 10), uptime: 100)
let previewLater = previewClock.now(wallTime: date(22, 10, 0, 5), uptime: 105)
let firstWage = engine.snapshot(at: previewFirst, settings: settings, screenAwake: true)
let laterWage = engine.snapshot(at: previewLater, settings: settings, screenAwake: true)
check(previewLater.timeIntervalSince(previewFirst) == 5, "preview clock advances five seconds")
check(firstWage.remaining - laterWage.remaining == 5, "preview countdown decreases five seconds")
check(close(laterWage.earned - firstWage.earned, firstWage.secondPay * 5), "preview earnings increase at per second rate")
previewClock.previewStart = nil
check(previewClock.now(wallTime: date(22, 10), uptime: 110) == date(22, 10), "leaving preview resumes wall clock")
print("\(count) checks passed.")
