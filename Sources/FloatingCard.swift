import AppKit
import SwiftUI

struct FloatingCard: View {
    @ObservedObject var model: WageModel
    let openSettings: () -> Void
    let resetPosition: () -> Void
    let quit: () -> Void
    private let mint = Color(red: 0.38, green: 0.97, blue: 0.76)
    private var s: WageSnapshot { model.snapshot }
    private var statusText: String {
        guard model.configured else { return "待设置" }
        switch s.phase {
        case .working: return "上班中"
        case .onBreak: return "午休中"
        case .before: return "待上班"
        case .overtime: return "被白嫖中"
        case .finished: return "已下班"
        case .rest: return "休息中"
        }
    }
    private var clockLabel: String {
        switch s.phase {
        case .before: return "上班倒计时"
        case .overtime: return "下班已超时"
        case .rest: return "今天休息"
        case .finished: return "今日已下班"
        default: return "下班倒计时"
        }
    }
    private var clockValue: String {
        switch s.phase {
        case .before: return duration(s.start.timeIntervalSince(s.now))
        case .overtime: return "+" + duration(s.overtime)
        case .rest: return "--:--:--"
        case .finished: return "00:00:00"
        default: return duration(s.remaining)
        }
    }
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 11) {
                Text("上班鼓励器").font(.system(size: 16, weight: .bold)).foregroundStyle(.white.opacity(0.96))
                HStack(spacing: 7) {
                    Circle().fill(s.phase == .overtime ? Color.orange : mint).frame(width: 7, height: 7)
                    Text(statusText).font(.system(size: 13, weight: .medium)).foregroundStyle(.white.opacity(0.83))
                }
                Spacer(minLength: 8)
                Button(action: openSettings) {
                    Image(systemName: "gearshape").font(.system(size: 17, weight: .regular))
                        .foregroundStyle(.white.opacity(0.75)).frame(width: 24, height: 24)
                        .contentShape(Rectangle())
                }.buttonStyle(.plain).help("工资设置").accessibilityLabel("工资设置").accessibilityIdentifier("openSettings")
            }.frame(height: 24)

            HStack(spacing: 19) {
                ZStack {
                    Circle().stroke(mint.opacity(0.12), lineWidth: 10)
                    Circle().trim(from: 0, to: max(0, min(1, s.progress)))
                        .stroke(mint, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .shadow(color: mint.opacity(0.28), radius: 5)
                    Text("\(Int(s.progress * 100))%")
                        .font(.system(size: 23, weight: .bold, design: .rounded)).monospacedDigit()
                        .foregroundStyle(.white.opacity(0.97))
                }.padding(5).frame(width: 120, height: 120)
                    .accessibilityElement(children: .ignore).accessibilityLabel("今日计薪进度 \(Int(s.progress * 100))%")
                VStack(alignment: .leading, spacing: 9) {
                    Text("今天已赚").font(.system(size: 13, weight: .medium)).foregroundStyle(.white.opacity(0.67))
                    Text(model.configured ? String(format: "¥%.4f", s.earned) : "¥ --.----")
                        .font(.system(size: 30, weight: .bold, design: .rounded)).monospacedDigit()
                        .foregroundStyle(.white.opacity(0.97)).lineLimit(1).minimumScaleFactor(0.5)
                        .accessibilityIdentifier("liveEarnings")
                }.frame(maxWidth: .infinity, alignment: .leading)
            }.padding(.top, 18)

            HStack(alignment: .firstTextBaseline) {
                Text(clockLabel).font(.system(size: 12, weight: .medium)).foregroundStyle(.white.opacity(0.56))
                Spacer()
                Text(clockValue).font(.system(size: 21, weight: .bold, design: .monospaced)).monospacedDigit()
                    .tracking(0.6).foregroundStyle(.white.opacity(0.94))
                    .accessibilityIdentifier("liveCountdown")
            }.padding(.top, 21)
        }
        .padding(.horizontal, 24).padding(.vertical, 21)
        .frame(width: 388, height: 252)
        .background(RoundedRectangle(cornerRadius: 22).fill(Color(red: 0.035, green: 0.055, blue: 0.08).opacity(0.60)))
        .overlay(RoundedRectangle(cornerRadius: 22).fill(LinearGradient(colors: [.white.opacity(0.055), .clear], startPoint: .topLeading, endPoint: .bottomTrailing)).allowsHitTesting(false))
        .overlay(RoundedRectangle(cornerRadius: 22).strokeBorder(.white.opacity(0.13), lineWidth: 0.75).allowsHitTesting(false))
        .contextMenu {
            Button("工资设置…", action: openSettings)
            Button("归位右下角", action: resetPosition)
            Divider()
            Button("退出薪动", action: quit)
        }
    }
}

final class TransparentHostingView<Content: View>: NSHostingView<Content> {
    override var isOpaque: Bool { false }
}
