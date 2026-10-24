import SwiftUI
import Core

/// 主界面（4.0 排印日课）：左边一条刊眉栏（年、月、密度月历、导航），
/// 右边是中轴上的一页日课。
public struct RootView: View {
    @EnvironmentObject var store: TaskStore
    @EnvironmentObject var updater: Updater
    @Environment(\.openSettings) private var openSettings
    @Environment(\.openWindow) private var openWindow

    @State private var anchor: Date = Date()
    @StateObject private var session = InputSession()
    @StateObject private var drag = DragController()
    @State private var showWelcome = false
    @State private var showPool = false
    @State private var showDone = false
    @State private var showYear = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    private var motion: Animation? { reduceMotion ? nil : Motion.spring }

    public init() {}

    private var monthName: String {
        let m = Calendar(identifier: .gregorian).component(.month, from: anchor)
        let names = ["一月", "二月", "三月", "四月", "五月", "六月", "七月", "八月", "九月", "十月", "十一月", "十二月"]
        return names[max(0, min(11, m - 1))]
    }

    private var yearName: String {
        String(Calendar(identifier: .gregorian).component(.year, from: anchor))
    }

    public var body: some View {
        ZStack(alignment: .bottom) {
            if Theme.isNight {
                nightFrame
            } else {
                HStack(spacing: 0) {
                    rail
                    DayPageView(day: store.selectedDay)
                        .id("\(store.selectedDay)-\(Theme.choice)")
                        .frame(maxWidth: 660)
                        .frame(maxHeight: .infinity)
                        .background(
                            Theme.canvas
                                .contentShape(Rectangle())
                                .onTapGesture { session.finishByClickingAway(store: store) }
                        )
                        .transition(.asymmetric(
                            insertion: .offset(x: 26).combined(with: .opacity),
                            removal: .offset(x: -26).combined(with: .opacity)
                        ))
                        .frame(maxWidth: .infinity)
                }
                .background(Theme.canvas)
            }

            if showYear {
                YearView(onClose: { showYear = false })
                    .environmentObject(store)
                    .transition(.opacity)
                    .zIndex(15)
            }

            if let toast = store.toast {
                ToastBar(text: toast, hasUndo: store.toastHasUndo) {
                    store.undo()
                }
                .padding(.bottom, 24)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .overlay {
            if Theme.isNight { Scanlines() }
        }
        .onChange(of: store.selectedDay) { _, day in
            if let date = DayKey.date(from: day),
               !Calendar(identifier: .gregorian).isDate(date, equalTo: anchor, toGranularity: .month) {
                anchor = date
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { store.checkRollover() }
        }
        .onChange(of: store.selectedDay) { _, _ in
            Feedback.page()
        }
        .environmentObject(session)
        .environmentObject(drag)
        .sheet(isPresented: $showWelcome) {
            WelcomeSheet(
                onOpenHelp: { openWindow(id: "help") },
                onClose: {
                    showWelcome = false
                    store.markWelcomeSeen()
                }
            )
            .environmentObject(store)
        }
        .onAppear {
            if !store.welcomeSeen { showWelcome = true }
            updater.checkIfNeeded(auto: store.settings.autoCheckUpdates)
        }
        .tint(Theme.accent)
        .background(
            Group {
                Button("年视图") { showYear.toggle() }
                    .keyboardShortcut("y", modifiers: [.command])
                Button("说明") { openWindow(id: "help") }
                    .keyboardShortcut("/", modifiers: [.command])
            }
            .opacity(0)
            .frame(width: 0, height: 0)
            .accessibilityHidden(true)
        )
        .animation(reduceMotion ? nil : Motion.soft, value: showYear)
        .animation(reduceMotion ? nil : Motion.spring, value: store.toast)
        .animation(reduceMotion ? nil : Motion.soft, value: store.selectedDay)
        .themeSynced()
        .sheet(isPresented: $showPool) {
            PoolSheetView { showPool = false }
                .environmentObject(store)
        }
        .sheet(isPresented: $showDone) {
            DoneSheetView { showDone = false }
                .environmentObject(store)
        }
    }

    // MARK: 夜之城（HUD 顶栏 + 终端左栏 + 任务日志）

    /// HUD 日期读出：2026.10.24 SAT · DAY 297
    private var hudDate: String {
        let d = DayKey.date(from: store.currentDay) ?? Date()
        let cal = Calendar(identifier: .gregorian)
        let m = cal.component(.month, from: d), day = cal.component(.day, from: d)
        let w = ["SUN", "MON", "TUE", "WED", "THU", "FRI", "SAT"][max(0, min(6, cal.component(.weekday, from: d) - 1))]
        let yStart = cal.dateInterval(of: .year, for: d)?.start ?? d
        let dayOfYear = (cal.dateComponents([.day], from: yStart, to: cal.startOfDay(for: d)).day ?? 0) + 1
        return "\(cal.component(.year, from: d)).\(String(format: "%02d", m)).\(String(format: "%02d", day)) \(w) · DAY \(dayOfYear)"
    }

    private var nightFrame: some View {
        VStack(spacing: 0) {
            // HUD 顶栏
            HStack(spacing: 18) {
                Text("FU//TODO")
                    .font(Theme.display(14))
                    .tracking(3)
                    .foregroundStyle(Theme.accent)
                Text("NIGHT CITY TERMINAL · \(hudDate)")
                    .font(Theme.mono(10))
                    .tracking(1.5)
                    .foregroundStyle(Theme.ink2)
                Spacer(minLength: 12)
                HudButton("今天", active: store.selectedDay == store.currentDay, action: goToday)
                HudButton("未完成", count: store.poolCount, action: { showPool = true })
                HudButton("已结束", count: store.doneTasks.count, action: { showDone = true })
                HudButton("年视图", action: { showYear = true })
                HudButton("说明", action: { openWindow(id: "help") })
                HudButton("设置", action: { openSettings() })
            }
            .padding(.horizontal, 24)
            .frame(height: 54)
            .overlay(alignment: .bottom) {
                Rectangle().fill(Theme.rule).frame(height: 1)
            }

            HStack(spacing: 0) {
                nightRail
                DayPageView(day: store.selectedDay)
                    .id("\(store.selectedDay)-\(Theme.choice)")
                    .frame(maxWidth: .infinity)
                    .frame(maxHeight: .infinity)
                    .background(
                        Theme.canvas
                            .contentShape(Rectangle())
                            .onTapGesture { session.finishByClickingAway(store: store) }
                    )
                    .transition(.asymmetric(
                        insertion: .offset(x: 26).combined(with: .opacity),
                        removal: .offset(x: -26).combined(with: .opacity)
                    ))
                    .frame(maxWidth: .infinity)
            }
        }
        .background(Theme.canvas)
    }

    private var nightRail: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(monthName)
                    .font(Theme.display(20))
                    .tracking(3)
                    .foregroundStyle(Theme.ink)
                Text("\(yearName) / \(String(Calendar(identifier: .gregorian).component(.month, from: anchor)))")
                    .font(Theme.mono(10))
                    .tracking(2)
                    .foregroundStyle(Theme.ink3)
            }

            HStack(spacing: 14) {
                Button { shiftMonth(-1) } label: { nightNav("‹ 上月") }
                Button { goToday() } label: { nightNav("今天", active: store.selectedDay == store.currentDay) }
                Button { shiftMonth(1) } label: { nightNav("下月 ›") }
            }
            .padding(.top, 14)

            MonthGridView(anchor: anchor, drag: drag) { day in
                store.selectDay(day)
                if let date = DayKey.date(from: day),
                   !Calendar(identifier: .gregorian).isDate(date, equalTo: anchor, toGranularity: .month) {
                    anchor = date
                }
            }
            .padding(.top, 24)

            // 数据雨紧跟月历下方，不沉底；剩余空间留给底部状态行
            DataRain()
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 22)
                .padding(.bottom, 14)

            Spacer(minLength: 16)

            VStack(alignment: .leading, spacing: 4) {
                Text("SYS OK · 数据全部本地")
                Text("NO CLOUD · NO ADS")
            }
            .font(Theme.mono(9))
            .tracking(2)
            .foregroundStyle(Theme.ink3)
        }
        .padding(.leading, 30)
        .padding(.trailing, 24)
        .padding(.top, 30)
        .padding(.bottom, 28)
        .frame(width: 242, alignment: .topLeading)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(Theme.canvas)
        .overlay(alignment: .trailing) {
            Rectangle().fill(Theme.rule).frame(width: 1)
        }
    }

    private func nightNav(_ title: String, active: Bool = false) -> some View {
        Text(title)
            .font(Theme.mono(10))
            .tracking(1)
            .foregroundStyle(active ? Theme.signal : Theme.ink2)
            .overlay(alignment: .bottom) {
                if active {
                    Rectangle().fill(Theme.signal).frame(height: 1).offset(y: 2)
                }
            }
            .contentShape(Rectangle())
    }

    // MARK: 刊眉栏（日课）

    private var rail: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(yearName)
                .font(Theme.mono(11))
                .tracking(6)
                .foregroundStyle(Theme.ink3)
            Text(monthName)
                .font(Theme.display(Theme.monthDisplaySize))
                .tracking(1)
                .foregroundStyle(Theme.ink)
                .padding(.top, 8)

            HStack(spacing: 14) {
                Button { shiftMonth(-1) } label: { railNav("‹ 上月") }
                Button { goToday() } label: {
                    railNav("今天", active: store.selectedDay == store.currentDay)
                }
                Button { shiftMonth(1) } label: { railNav("下月 ›") }
            }
            .padding(.top, 14)

            MonthGridView(anchor: anchor, drag: drag) { day in
                store.selectDay(day)
                if let date = DayKey.date(from: day),
                   !Calendar(identifier: .gregorian).isDate(date, equalTo: anchor, toGranularity: .month) {
                    anchor = date
                }
            }
            .padding(.top, 28)

            Spacer(minLength: 24)

            VStack(alignment: .leading, spacing: 0) {
                railDivider
                railNavLink("未完成", count: store.poolCount) { showPool = true }
                railNavLink("已结束", count: store.doneTasks.count) { showDone = true }
                railNavLink("年视图", key: "⌘Y") { showYear = true }
                railNavLink("说明", key: "⌘/") { openWindow(id: "help") }
                railNavLink("设置", key: "⌘,") { openSettings() }
            }
        }
        .padding(.leading, 48)
        .padding(.trailing, 24)
        .padding(.top, 56)
        .padding(.bottom, 40)
        .frame(width: 252, alignment: .topLeading)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(Theme.canvas)
    }

    private var railDivider: some View {
        Rectangle().fill(Theme.rule).frame(height: 1)
            .padding(.bottom, 12)
    }

    private func railNav(_ title: String, active: Bool = false) -> some View {
        Text(title)
            .font(Theme.mono(10))
            .tracking(1)
            .foregroundStyle(active ? Theme.ink : Theme.ink2)
            .overlay(alignment: .bottom) {
                if active {
                    Rectangle().fill(Theme.ink).frame(height: 1).offset(y: 2)
                }
            }
            .contentShape(Rectangle())
    }

    private func railNavLink(
        _ title: String,
        count: Int? = nil,
        key: String? = nil,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(Theme.sans(12))
                    .foregroundStyle(Theme.ink2)
                Spacer()
                if let count {
                    Text("\(count)")
                        .font(Theme.mono(10))
                        .foregroundStyle(Theme.ink3)
                } else if let key {
                    Text(key)
                        .font(Theme.mono(9))
                        .foregroundStyle(Theme.faint)
                }
            }
            .frame(height: 30)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func shiftMonth(_ delta: Int) {
        let cal = Calendar(identifier: .gregorian)
        if let next = cal.date(byAdding: .month, value: delta, to: anchor) {
            anchor = next
        }
    }

    private func goToday() {
        store.selectDay(store.currentDay)
        anchor = Date()
    }
}
