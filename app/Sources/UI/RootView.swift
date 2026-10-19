import SwiftUI
import Core

/// 主界面：左边报头 + 色块月历，右边是当天的一整页。
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
    @State private var focusMode = false
    @State private var showYear = false
    @State private var showPalette = false
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
            HStack(spacing: 0) {
                VStack(spacing: 0) {
                    masthead
                    MonthGridView(anchor: anchor, drag: drag) { day in
                        store.selectDay(day)
                        if let date = DayKey.date(from: day),
                           !Calendar(identifier: .gregorian).isDate(date, equalTo: anchor, toGranularity: .month) {
                            anchor = date
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 18)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(
                        Theme.canvas
                            .contentShape(Rectangle())
                            .onTapGesture { session.finishByClickingAway(store: store) }
                    )
                    .animation(motion, value: store.selectedDay)
                }
                .frame(maxWidth: .infinity)
                .background(Theme.canvas)

                DayPageView(day: store.selectedDay)
                    .id(store.selectedDay)
                    .frame(width: 460)
                    .frame(maxHeight: .infinity)
                    .transition(.asymmetric(
                        insertion: .offset(x: 26).combined(with: .opacity),
                        removal: .offset(x: -26).combined(with: .opacity)
                    ))
            }
            .background(Theme.canvas)

            if focusMode {
                FocusModeView(onClose: { focusMode = false })
                    .environmentObject(store)
                    .transition(.opacity)
                    .zIndex(10)
            }

            if showYear {
                YearView(onClose: { showYear = false })
                    .environmentObject(store)
                    .transition(.opacity)
                    .zIndex(15)
            }

            if showPalette {
                CommandPaletteView(actions: paletteActions, onClose: { showPalette = false })
                    .transition(.opacity)
                    .zIndex(20)
            }

            if let toast = store.toast {
                ToastBar(text: toast, hasUndo: store.toastHasUndo) {
                    store.undo()
                }
                .padding(.bottom, 24)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
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
            ZStack {
                Button("专注") { focusMode.toggle() }
                    .keyboardShortcut("f", modifiers: [.command, .shift])
                Button("年视图") { showYear.toggle() }
                    .keyboardShortcut("y", modifiers: [.command])
                Button("命令面板") { showPalette.toggle() }
                    .keyboardShortcut("k", modifiers: [.command])
            }
            .opacity(0)
            .frame(width: 0, height: 0)
            .accessibilityHidden(true)
        )
        .animation(reduceMotion ? nil : Motion.soft, value: focusMode)
        .animation(reduceMotion ? nil : Motion.soft, value: showYear)
        .animation(reduceMotion ? nil : Motion.soft, value: showPalette)
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

    private var masthead: some View {
        HStack(alignment: .bottom, spacing: 14) {
            VStack(alignment: .leading, spacing: 0) {
                Text(yearName).font(Theme.mono(9)).tracking(2.6).foregroundStyle(Theme.ink3)
                Text(monthName)
                    .font(Theme.display(Theme.monthDisplaySize))
                    .tracking(Theme.displayTracking(Theme.monthDisplaySize))
                    .foregroundStyle(Theme.ink)
            }
            HStack(spacing: 4) {
                IconButton(systemName: "chevron.left", help: "上个月") { shiftMonth(-1) }
                IconButton(systemName: "chevron.right", help: "下个月") { shiftMonth(1) }
            }
            .padding(.bottom, 10)
            TextButton("今天") { goToday() }
                .padding(.bottom, 6)
            rangeSwitch
                .padding(.bottom, 6)

            Spacer()

            VStack(alignment: .trailing, spacing: 6) {
                HStack(spacing: 14) {
                    Button { showPool = true } label: {
                        HStack(spacing: 5) {
                            Text("未完成").font(Theme.mono(9)).tracking(1).foregroundStyle(Theme.ink3)
                            Text("\(store.poolCount)").font(Theme.mono(9, .semibold)).foregroundStyle(Theme.ink)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    Button { showDone = true } label: {
                        Text("已结束").font(Theme.mono(9)).tracking(1)
                            .foregroundStyle(Theme.ink3)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                HStack(spacing: 8) {
                    TextButton("⌘K") { showPalette = true }
                    TextButton("年") { showYear = true }
                    TextButton("专注") { focusMode = true }
                    TextButton("说明") { openWindow(id: "help") }
                    TextButton("设置") { openSettings() }
                }
            }
            .padding(.bottom, 4)
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 10)
    }

    private var rangeSwitch: some View {
        HStack(spacing: 0) {
            ForEach(CalendarRange.allCases, id: \.self) { range in
                let current = store.settings.calendarRange == range
                Button {
                    store.updateSettings { $0.calendarRange = range }
                } label: {
                    Text(range.label)
                        .font(Theme.mono(9, .semibold))
                        .tracking(0.6)
                        .foregroundStyle(current ? Theme.canvas : Theme.ink2)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .frame(minHeight: 28)
                        .background(Rectangle().fill(current ? Theme.ink : Color.clear))
                        .overlay(Rectangle().strokeBorder(Theme.rule, lineWidth: 0.8))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help(range == .month ? "整月" : (range == .biweek ? "双周：卡片更大" : "单周：一屏一周"))
            }
        }
    }

    private var paletteActions: [PaletteAction] {
        var list: [PaletteAction] = [
            PaletteAction(title: "专注模式", hint: "⌘⇧F · 整窗只留今天的主线") { focusMode = true },
            PaletteAction(title: "年视图", hint: "⌘Y · 12 个小月历") { showYear = true },
            PaletteAction(title: "月历：整月", hint: "M") { store.updateSettings { $0.calendarRange = .month } },
            PaletteAction(title: "月历：双周", hint: "两周并排，卡片更大") { store.updateSettings { $0.calendarRange = .biweek } },
            PaletteAction(title: "月历：单周", hint: "一屏一周") { store.updateSettings { $0.calendarRange = .week } },
            PaletteAction(title: "跳到今天", hint: "回到今天并选中") {
                store.selectDay(store.currentDay)
                anchor = Date()
            },
            PaletteAction(title: "未完成清单", hint: "只列一级任务") { showPool = true },
            PaletteAction(title: "已结束清单", hint: "完成与结束都在这里") { showDone = true },
            PaletteAction(title: "使用说明", hint: "独立窗口") { openWindow(id: "help") },
            PaletteAction(title: "设置", hint: "主题 / 字号 / 数据") { openSettings() },
            PaletteAction(title: "导出本月海报", hint: "PNG · 可打印") { PosterExporter.export(store: store) }
        ]
        for theme in ThemeChoice.allCases {
            list.append(PaletteAction(title: "主题：\(theme.label)", hint: theme.en) {
                store.updateSettings { $0.theme = theme }
            })
        }
        return list
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
