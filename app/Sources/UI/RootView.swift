import SwiftUI
import Core

/// 主界面：左边月历（一天一格，格子里是那天的内容），右边当天的一页。
public struct RootView: View {
    @EnvironmentObject var store: TaskStore
    @Environment(\.openSettings) private var openSettings
    @Environment(\.openWindow) private var openWindow

    @State private var anchor: Date = Date()
    @StateObject private var session = InputSession()
    @StateObject private var drag = DragController()
    @State private var showWelcome = false
    @State private var showPool = false
    @State private var showDone = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    private var motion: Animation? { reduceMotion ? nil : Motion.spring }

    public init() {}

    public var body: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                header
                Rectangle().fill(Theme.hairline).frame(height: 1)
                HStack(spacing: 0) {
                    MonthGridView(anchor: anchor, drag: drag) { day in
                        store.selectDay(day)
                        if let date = DayKey.date(from: day),
                           !Calendar(identifier: .gregorian).isDate(date, equalTo: anchor, toGranularity: .month) {
                            anchor = date
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 14)
                    .padding(.bottom, 16)
                    .frame(maxWidth: .infinity)
                    .background(
                        Theme.paper
                            .contentShape(Rectangle())
                            .onTapGesture { session.finishByClickingAway(store: store) }
                    )
                    .animation(motion, value: store.selectedDay)

                    Rectangle().fill(Theme.hairline).frame(width: 1)

                    DayPageView(day: store.selectedDay)
                        .id(store.selectedDay)
                        .frame(width: 402)
                        .transition(.opacity)
                }
            }
            .background(Theme.paper)

            if let toast = store.toast {
                ToastBar(text: toast, hasUndo: store.toastHasUndo) {
                    store.undo()
                }
                .padding(.bottom, 24)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .onChange(of: store.selectedDay) { _, day in
            // 从清单跳转过来时，月历也要翻到那一天所在的月份
            if let date = DayKey.date(from: day),
               !Calendar(identifier: .gregorian).isDate(date, equalTo: anchor, toGranularity: .month) {
                anchor = date
            }
        }
        .onChange(of: scenePhase) { _, phase in
            // 合盖过夜、或切回应用时，自动开启新的一天
            if phase == .active { store.checkRollover() }
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
            // 第一次打开才弹，之后不再打扰
            if !store.welcomeSeen { showWelcome = true }
        }
        // 让系统画的那些"不是我们画的部分"也属于这套配色：
        // 文本选中、插入符、焦点环、控件强调色都跟着走。
        .tint(Theme.accent)
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

    private var header: some View {
        HStack(spacing: 10) {
            Text(MonthFormat.label(for: anchor))
                .font(Theme.serif(16, .semibold))
                .foregroundStyle(Theme.ink2)
            IconButton(systemName: "chevron.left", help: "上个月") { shiftMonth(-1) }
            IconButton(systemName: "chevron.right", help: "下个月") { shiftMonth(1) }
            TextButton("今天") { goToday() }

            Spacer()

            TextButton("未完成项目清单", badge: store.poolCount) { showPool = true }
            TextButton("已结束项目清单") { showDone = true }
            TextButton("使用说明") { openWindow(id: "help") }
            TextButton("设置") { openSettings() }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 11)
        .background(
            Theme.paper
                .contentShape(Rectangle())
                .onTapGesture { session.finishByClickingAway(store: store) }
        )
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
