import SwiftUI
import Core

/// 完成印章：同一个完成动作，在四套主题里盖四种章。
struct CompletionStamp: View {
    let style: CardStyle
    let date: String

    var body: some View {
        content
            .rotationEffect(.degrees(-7))
            .shadow(color: Theme.ink.opacity(0.18), radius: 0, x: 3, y: 4)
    }

    @ViewBuilder
    private var content: some View {
        switch style {
        case .atelier:
            Text("已交付")
                .font(Theme.display(13))
                .foregroundStyle(Theme.canvas)
                .padding(.horizontal, 12).padding(.vertical, 6)
                .background(Circle().fill(Theme.stamp))
        case .herbarium:
            Text("DRIED & MOUNTED · \(date)")
                .font(Theme.mono(7)).tracking(0.6)
                .foregroundStyle(Theme.stamp)
                .padding(.horizontal, 10).padding(.vertical, 6)
                .overlay(Rectangle().strokeBorder(Theme.stamp, lineWidth: 1.1))
        case .acid:
            Text("DONE")
                .font(.system(size: 16, weight: .black))
                .foregroundStyle(Theme.canvas)
                .padding(.horizontal, 10).padding(.vertical, 3)
                .background(Rectangle().fill(Theme.stamp))
                .rotationEffect(.degrees(-4))
        case .blueprint:
            Text("REV. A")
                .font(.system(size: 15, weight: .black))
                .foregroundStyle(Theme.stamp)
                .padding(.horizontal, 8).padding(.vertical, 3)
                .overlay(Rectangle().strokeBorder(Theme.stamp, lineWidth: 1.2))
        }
    }
}

/// 专注模式：整窗只留今天的主线。
public struct FocusModeView: View {
    @EnvironmentObject var store: TaskStore
    let onClose: () -> Void

    public init(onClose: @escaping () -> Void) {
        self.onClose = onClose
    }
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var showStamp = false
    private var main: Task? { store.mainGoal(on: store.selectedDay) }
    private var branches: [Task] { store.branches(on: store.selectedDay) }
    private var finishedCount: Int { store.doneCount(on: store.selectedDay) }

    private var dayNumber: String {
        guard let date = DayKey.date(from: store.selectedDay) else { return "" }
        return String(Calendar(identifier: .gregorian).component(.day, from: date))
    }

    private var weekday: String {
        guard let date = DayKey.date(from: store.selectedDay) else { return "" }
        let w = Calendar(identifier: .gregorian).component(.weekday, from: date)
        return ["日", "一", "二", "三", "四", "五", "六"][max(0, min(6, w - 1))]
    }

    public var body: some View {
        ZStack(alignment: .topLeading) {
            Theme.canvas.ignoresSafeArea()
            Text(dayNumber)
                .font(Theme.display(360))
                .tracking(Theme.displayTracking(360))
                .foregroundStyle(Theme.ink.opacity(0.045))
                .offset(x: -10, y: 40)
                .allowsHitTesting(false)

            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .firstTextBaseline) {
                    Text("FU TODO  /  FOCUS").font(Theme.mono(9)).tracking(2.2).foregroundStyle(Theme.ink3)
                    Spacer()
                    Text("\(dayNumber) · \(weekday)").font(Theme.mono(9)).tracking(1.6).foregroundStyle(Theme.ink3)
                }

                Spacer(minLength: 0)

                HStack(alignment: .bottom, spacing: 40) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("今天只做这一件").font(Theme.mono(9.5)).tracking(2).foregroundStyle(Theme.ink3)
                        Text(main?.title ?? "今天还没有主线")
                            .font(Theme.display(64))
                            .tracking(Theme.displayTracking(64))
                            .foregroundStyle(main == nil ? Theme.ink3 : Theme.ink)
                            .lineSpacing(-4)
                            .fixedSize(horizontal: false, vertical: true)
                            .lineLimit(3)
                    }
                    Spacer(minLength: 0)
                    BigRing(done: main?.done ?? false) {
                        guard let main else { return }
                        if main.done {
                            store.revert(main.id)
                        } else {
                            store.complete(main.id)
                            Feedback.complete()
                            if !reduceMotion {
                                showStamp = true
                                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { showStamp = false }
                            }
                        }
                    }
                }

                if !branches.isEmpty {
                    VStack(alignment: .leading, spacing: 0) {
                        Rectangle().fill(Theme.rule).frame(height: 0.8).padding(.top, 30)
                        ForEach(branches.prefix(4)) { task in
                            HStack(spacing: 10) {
                                Rectangle().fill(Theme.ink.opacity(0.35)).frame(width: 14, height: 1)
                                Text(task.title).font(Theme.sans(14)).foregroundStyle(Theme.ink2)
                                Spacer()
                            }
                            .frame(height: 36)
                            .overlay(alignment: .bottom) {
                                Rectangle().fill(Theme.rule.opacity(0.6)).frame(height: 0.6)
                            }
                        }
                        if branches.count > 4 {
                            Text("+\(branches.count - 4) 条支线").font(Theme.mono(8.5)).foregroundStyle(Theme.ink3)
                                .padding(.top, 8)
                        }
                    }
                    .padding(.top, 4)
                }

                Spacer(minLength: 0)

                HStack {
                    Text("按 Esc 退出专注").font(Theme.mono(8.5)).tracking(1).foregroundStyle(Theme.ink3)
                    Spacer()
                    if finishedCount > 0 {
                        Text("今日已完成 \(finishedCount) 件").font(Theme.mono(8.5)).foregroundStyle(Theme.ink3)
                    }
                    Button(action: onClose) {
                        Text("ESC 退出").font(Theme.mono(8.5, .semibold)).tracking(1)
                            .foregroundStyle(Theme.canvas)
                            .padding(.horizontal, 10).padding(.vertical, 5)
                            .background(Rectangle().fill(Theme.ink))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(52)

            if showStamp {
                CompletionStamp(style: Theme.cardStyle, date: store.selectedDay.replacingOccurrences(of: "-", with: "."))
                    .scaleEffect(1.6)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                    .transition(.scale(scale: 1.2).combined(with: .opacity))
                    .allowsHitTesting(false)
            }
        }
        .animation(reduceMotion ? nil : Motion.ring, value: showStamp)
        .onExitCommand(perform: onClose)
        .focusable()
        .transition(.opacity)
    }
}

private struct BigRing: View {
    let done: Bool
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle().strokeBorder(hovering ? Theme.ink : Theme.control, lineWidth: 2)
                    .frame(width: 52, height: 52)
                if done {
                    Circle().fill(Theme.accent).frame(width: 52, height: 52)
                    Image(systemName: "checkmark")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(Theme.canvas)
                }
            }
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .help(done ? "恢复这条主线" : "完成今天的主线")
    }
}
