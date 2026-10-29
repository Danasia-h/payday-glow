import AppKit
import SwiftUI
import CoreGraphics

let pine = Color(red: 0.10, green: 0.25, blue: 0.20)
let lime = Color(red: 0.79, green: 0.94, blue: 0.48)
let ink = Color(red: 0.15, green: 0.20, blue: 0.18)
let muted = Color(red: 0.49, green: 0.54, blue: 0.50)
let paper = Color(red: 0.96, green: 0.96, blue: 0.93)
let warning = Color(red: 0.69, green: 0.29, blue: 0.16)

final class WageModel: ObservableObject {
    @Published var settings: WageSettings
    @Published var snapshot: WageSnapshot
    @Published var configured: Bool
    var screenAwake = true
    var onTick: (() -> Void)?
    var onCelebrate: ((Double) -> Void)?
    private var timer: Timer?
    private var observers: [NSObjectProtocol] = []
    private var lastNotice: String
    @Published private(set) var preview: String?
    private var clock: WageClock

    init() {
        let args = ProcessInfo.processInfo.arguments
        let previewMode = args.firstIndex(of: "--preview").flatMap { args.indices.contains($0 + 1) ? args[$0 + 1] : nil }
        preview = previewMode
        let previewDate = previewMode.map { mode in
            Calendar.current.date(from: DateComponents(year: 2026, month: 10, day: mode == "rest" ? 25 : 22, hour: mode == "overtime" ? 19 : mode == "rest" ? 11 : 15, minute: 24, second: 38))!
        }
        clock = WageClock(previewStart: previewDate, originUptime: ProcessInfo.processInfo.systemUptime)
        let saved = UserDefaults.standard.data(forKey: "wage.settings.v1").flatMap { try? JSONDecoder().decode(WageSettings.self, from: $0) }
        let valid = saved.flatMap { $0.validationError == nil ? $0 : nil }
        let initial = previewMode == nil ? valid ?? WageSettings() : WageSettings()
        settings = initial
        configured = previewMode != nil || valid != nil
        lastNotice = UserDefaults.standard.string(forKey: "wage.lastNotice") ?? ""
        snapshot = WageEngine().snapshot(at: Date(), settings: initial, screenAwake: true)
        refreshScreenState()
        tick()
        let center = NSWorkspace.shared.notificationCenter
        observers.append(center.addObserver(forName: NSWorkspace.screensDidSleepNotification, object: nil, queue: .main) { [weak self] _ in self?.screenAwake = false; self?.tick() })
        observers.append(center.addObserver(forName: NSWorkspace.screensDidWakeNotification, object: nil, queue: .main) { [weak self] _ in self?.refreshScreenState(); self?.tick() })
        observers.append(center.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in self?.refreshScreenState(); self?.tick() })
        timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in self?.tick() }
        timer?.tolerance = 0.1
        RunLoop.main.add(timer!, forMode: .common)
    }
    func refreshScreenState() {
        var ids = [CGDirectDisplayID](repeating: 0, count: 16)
        var count: UInt32 = 0
        let result = CGGetOnlineDisplayList(16, &ids, &count)
        screenAwake = result != .success || ids.prefix(Int(count)).contains { CGDisplayIsAsleep($0) == 0 }
    }
    func tick() {
        let now = clock.now()
        snapshot = WageEngine().snapshot(at: now, settings: settings, screenAwake: screenAwake)
        if preview == nil, let onCelebrate = onCelebrate {
            var gate = ReminderGate(lastShiftID: lastNotice)
            if gate.consume(snapshot, configured: configured, screenAwake: screenAwake) {
                lastNotice = gate.lastShiftID
                UserDefaults.standard.set(lastNotice, forKey: "wage.lastNotice")
                onCelebrate(snapshot.dayPay)
            }
        }
        onTick?()
    }
    func save(_ value: WageSettings) {
        guard value.validationError == nil else { return }
        settings = value
        configured = true
        preview = nil
        clock.previewStart = nil
        if let data = try? JSONEncoder().encode(value) { UserDefaults.standard.set(data, forKey: "wage.settings.v1") }
        tick()
    }
    var phaseTitle: String {
        switch snapshot.phase {
        case .working: return "正在赚钱"
        case .onBreak: return "午休充电中"
        case .before: return "还没上班，先享受生活"
        case .overtime: return "被白嫖中"
        case .finished: return "今日已下班"
        case .rest: return "今天休息"
        }
    }
}

struct SettingsView: View {
    @ObservedObject var model: WageModel
    @State private var draft: WageSettings
    @State private var salary: String
    let onClose: () -> Void
    init(model: WageModel, onClose: @escaping () -> Void) { self.model = model; self.onClose = onClose; _draft = State(initialValue: model.settings); _salary = State(initialValue: String(format: "%.2f", model.settings.monthlySalary)) }
    var candidate: WageSettings { var result = draft; result.monthlySalary = Double(salary.replacingOccurrences(of: ",", with: "")) ?? 0; return result }
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack { VStack(alignment: .leading, spacing: 5) { Text("设置你的赚钱时钟").font(.system(size: 24, weight: .semibold)); Text("月均工作日固定为 21.5 天").font(.system(size: 12)).foregroundStyle(muted) }; Spacer(); Button(action: onClose) { Image(systemName: "xmark.circle.fill").foregroundStyle(muted).font(.system(size: 22)) }.buttonStyle(.plain) }
            VStack(alignment: .leading, spacing: 9) { Text("每月工资（元）").font(.system(size: 12, weight: .medium)); TextField("例如 12000", text: $salary).textFieldStyle(.plain).font(.system(size: 30, weight: .medium, design: .rounded)).padding(14).background(.white, in: RoundedRectangle(cornerRadius: 12)).accessibilityIdentifier("salaryInput") }
            HStack { timePicker("上班时间", minute: $draft.startMinute); Spacer(); timePicker("下班时间", minute: $draft.endMinute) }
            if draft.endMinute < draft.startMinute { Text("这是一个跨夜班次，下班时间在次日。").font(.system(size: 11)).foregroundStyle(pine) }
            Divider()
            HStack { Toggle("扣除不计薪午休", isOn: $draft.hasBreak).toggleStyle(.switch).font(.system(size: 12)); Spacer() }
            if draft.hasBreak { HStack { timePicker("午休开始", minute: $draft.breakStartMinute); Spacer(); timePicker("午休结束", minute: $draft.breakEndMinute) } }
            VStack(alignment: .leading, spacing: 12) {
                Text("每周工作日").font(.system(size: 12, weight: .medium))
                HStack(spacing: 8) {
                    ForEach(Array(zip([2,3,4,5,6,7,1], ["一","二","三","四","五","六","日"])), id: \.0) { day, label in
                        let selected = draft.weekdays.contains(day)
                        Button { if selected { draft.weekdays.remove(day) } else { draft.weekdays.insert(day) } } label: { Text("周\(label)").font(.system(size: 11, weight: .medium)).frame(maxWidth: .infinity).padding(.vertical, 11).background(selected ? pine : Color.white, in: RoundedRectangle(cornerRadius: 9)).foregroundStyle(selected ? .white : ink) }.buttonStyle(.plain)
                    }
                }
            }
            if let error = candidate.validationError { Label(error, systemImage: "exclamationmark.circle").font(.system(size: 11)).foregroundStyle(warning).fixedSize(horizontal: false, vertical: true) }
            else { let rate = WageEngine().snapshot(at: Date(), settings: candidate, screenAwake: true); Label("每秒 ¥\(String(format: "%.5f", rate.secondPay)) · 每天 ¥\(money(rate.dayPay))", systemImage: "checkmark.circle").font(.system(size: 12)).foregroundStyle(pine) }
            Text("按固定班次估算，不含节假日调休、奖金、请假及加班费。屏幕亮起只用于状态提示，不代表实际在工作。数据仅保存在本机。").font(.system(size: 10)).foregroundStyle(muted).lineSpacing(4)
            HStack { Button("预览下班弹窗") { model.onCelebrate?(candidate.validationError == nil ? candidate.monthlySalary / 21.5 : model.snapshot.dayPay) }.buttonStyle(.plain).font(.system(size: 12)).foregroundStyle(pine); Spacer(); Button("保存并开始") { model.save(candidate); onClose() }.buttonStyle(.plain).font(.system(size: 13, weight: .semibold)).padding(.horizontal, 25).padding(.vertical, 12).background(pine, in: Capsule()).foregroundStyle(.white).disabled(candidate.validationError != nil).opacity(candidate.validationError == nil ? 1 : 0.4).keyboardShortcut(.defaultAction).accessibilityIdentifier("saveSettings") }
        }.padding(30).frame(width: 540).background(paper).foregroundStyle(ink)
    }
    func timePicker(_ title: String, minute: Binding<Int>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.system(size: 11)).foregroundStyle(muted)
            DatePicker(title, selection: Binding(get: { Calendar.current.date(from: DateComponents(year: 2026, month: 1, day: 1, hour: minute.wrappedValue / 60, minute: minute.wrappedValue % 60))! }, set: { minute.wrappedValue = Calendar.current.component(.hour, from: $0) * 60 + Calendar.current.component(.minute, from: $0) }), displayedComponents: .hourAndMinute).labelsHidden().datePickerStyle(.field).environment(\.locale, Locale(identifier: "en_GB")).frame(width: 190, alignment: .leading)
        }
    }
}

struct CelebrationView: View {
    let amount: Double
    let close: () -> Void
    var body: some View {
        VStack(spacing: 12) {
            HStack { Text("TODAY, WELL EARNED").font(.system(size: 9, weight: .semibold, design: .monospaced)).tracking(2).foregroundStyle(muted); Spacer(); Button(action: close) { Image(systemName: "xmark").font(.system(size: 12)) }.buttonStyle(.plain).foregroundStyle(muted) }
            Image(systemName: "party.popper.fill").font(.system(size: 30)).foregroundStyle(pine).padding(.top, 3)
            Text("下班快乐！").font(.system(size: 23, weight: .semibold))
            Text("恭喜，今天赚了 ¥\(money(amount))").font(.system(size: 16, weight: .medium)).foregroundStyle(pine)
            Text("今天的努力，值得一个准点下班。").font(.system(size: 11)).foregroundStyle(muted)
            Button("收工！") { close() }.buttonStyle(.plain).font(.system(size: 12, weight: .semibold)).padding(.horizontal, 36).padding(.vertical, 10).background(pine, in: Capsule()).foregroundStyle(lime).padding(.top, 4)
        }.padding(23).frame(width: 350).background(paper).foregroundStyle(ink)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    var window: NSWindow!
    var model: WageModel!
    var status: NSStatusItem!
    var panel: NSPanel?
    var dismissWork: DispatchWorkItem?
    var earningsItem: NSMenuItem!
    var settingsWindow: NSWindow?
    var screenObserver: NSObjectProtocol?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        NSApp.appearance = NSAppearance(named: .aqua)
        model = WageModel()
        let card = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 388, height: 252), styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        card.title = "薪动 · 实时薪资与倒计时"
        card.isFloatingPanel = true
        card.level = .floating
        card.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        card.hidesOnDeactivate = false
        card.isMovableByWindowBackground = true
        card.becomesKeyOnlyIfNeeded = true
        card.isOpaque = false
        card.backgroundColor = .clear
        card.hasShadow = true
        card.contentView = TransparentHostingView(rootView: FloatingCard(model: model,
            openSettings: { [weak self] in self?.settings() },
            resetPosition: { [weak self] in self?.resetPosition() },
            quit: { [weak self] in self?.quit() }))
        window = card
        window.isReleasedWhenClosed = false
        window.delegate = self
        resetPosition()
        screenObserver = NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main) { [weak self] _ in self?.resetPosition() }
        setupMenu()
        model.onCelebrate = { [weak self] value in self?.celebrate(value) }
        model.onTick = { [weak self] in self?.updateStatus() }
        model.tick()
        window.orderFrontRegardless()
        let args = ProcessInfo.processInfo.arguments
        if args.contains("--show-celebration") { celebrate(model.snapshot.dayPay) }
        if args.contains("--show-settings") || !model.configured { settings() }
        if let index = args.firstIndex(of: "--capture"), args.indices.contains(index + 1) {
            let path = args[index + 1]
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
                guard let self = self else { return }
                let view = args.contains("--capture-popup") ? self.panel?.contentView : args.contains("--capture-settings") ? self.settingsWindow?.contentView : self.window.contentView
                if let view = view, let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) {
                    view.cacheDisplay(in: view.bounds, to: rep)
                    try? rep.representation(using: .png, properties: [:])?.write(to: URL(fileURLWithPath: path))
                }
                self.quit()
            }
        }
    }
    func setupMenu() {
        let main = NSMenu()
        let appItem = NSMenuItem()
        main.addItem(appItem)
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "显示薪动", action: #selector(showWindow), keyEquivalent: "0").target = self
        appMenu.addItem(withTitle: "工资设置…", action: #selector(settings), keyEquivalent: ",").target = self
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "退出薪动", action: #selector(quit), keyEquivalent: "q").target = self
        appItem.submenu = appMenu
        let editItem = NSMenuItem(); main.addItem(editItem)
        let edit = NSMenu(title: "编辑")
        edit.addItem(withTitle: "撤销", action: Selector(("undo:")), keyEquivalent: "z")
        edit.addItem(withTitle: "剪切", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        edit.addItem(withTitle: "复制", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        edit.addItem(withTitle: "粘贴", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        edit.addItem(withTitle: "全选", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editItem.submenu = edit
        NSApp.mainMenu = main
        status = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        let menu = NSMenu()
        earningsItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
        menu.addItem(earningsItem)
        menu.addItem(.separator())
        menu.addItem(withTitle: "显示悬浮卡片", action: #selector(showWindow), keyEquivalent: "").target = self
        menu.addItem(withTitle: "归位右下角", action: #selector(resetPosition), keyEquivalent: "").target = self
        menu.addItem(withTitle: "隐藏悬浮卡片", action: #selector(hideWindow), keyEquivalent: "").target = self
        menu.addItem(withTitle: "工资设置…", action: #selector(settings), keyEquivalent: "").target = self
        menu.addItem(withTitle: "预览下班弹窗", action: #selector(testPopup), keyEquivalent: "").target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: "退出薪动", action: #selector(quit), keyEquivalent: "").target = self
        status.menu = menu
    }
    func updateStatus() {
        status.button?.title = !model.configured ? "◷ 薪动 · 待设置" : model.snapshot.phase == .overtime ? "◷ 被白嫖中 \(duration(model.snapshot.overtime))" : "◷ ¥\(money(model.snapshot.earned))"
        status.button?.font = .monospacedDigitSystemFont(ofSize: 12, weight: .regular)
        status.button?.toolTip = "薪动 · \(model.phaseTitle)"
        earningsItem.title = "今日已赚 ¥\(money(model.snapshot.earned)) · \(model.phaseTitle)"
    }
    func celebrate(_ amount: Double) {
        dismissWork?.cancel()
        panel?.orderOut(nil)
        let toast = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 396, height: 290), styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        toast.isFloatingPanel = true
        toast.level = .floating
        toast.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        toast.backgroundColor = .clear
        toast.isOpaque = false
        toast.hasShadow = true
        let host = NSHostingView(rootView: CelebrationView(amount: amount, close: { [weak self] in self?.panel?.orderOut(nil) }).clipShape(RoundedRectangle(cornerRadius: 22)))
        toast.contentView = host
        toast.setContentSize(host.fittingSize)
        let visible = (NSScreen.main ?? NSScreen.screens[0]).visibleFrame
        toast.setFrameOrigin(NSPoint(x: visible.maxX - toast.frame.width - 24, y: visible.maxY - toast.frame.height - 24))
        panel = toast
        toast.orderFrontRegardless()
        let work = DispatchWorkItem { [weak self] in self?.panel?.orderOut(nil) }
        dismissWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 14, execute: work)
    }
    @objc func showWindow() { window.orderFrontRegardless() }
    @objc func hideWindow() { window.orderOut(nil) }
    @objc func resetPosition() {
        let visible = (window.screen ?? NSScreen.main ?? NSScreen.screens[0]).visibleFrame
        window.setFrameOrigin(NSPoint(x: visible.maxX - window.frame.width - 24, y: visible.minY + 24))
    }
    @objc func settings() {
        if let existing = settingsWindow, existing.isVisible {
            existing.makeKeyAndOrderFront(nil)
        } else {
            let editor = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 600, height: 640), styleMask: [.titled, .closable, .fullSizeContentView], backing: .buffered, defer: false)
            editor.title = "薪动 · 工资设置"
            editor.titleVisibility = .hidden
            editor.titlebarAppearsTransparent = true
            editor.backgroundColor = NSColor(red: 0.96, green: 0.96, blue: 0.93, alpha: 1)
            editor.isReleasedWhenClosed = false
            editor.level = .floating
            let host = NSHostingView(rootView: SettingsView(model: model, onClose: { [weak self] in self?.settingsWindow?.close() }).padding(.top, 22).background(paper))
            editor.contentView = host
            editor.setContentSize(host.fittingSize)
            editor.center()
            settingsWindow = editor
            editor.makeKeyAndOrderFront(nil)
        }
        NSApp.activate(ignoringOtherApps: true)
    }
    @objc func testPopup() { celebrate(model.snapshot.dayPay) }
    @objc func quit() {
        settingsWindow?.close()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { NSApp.terminate(nil) }
    }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool { showWindow(); return true }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
