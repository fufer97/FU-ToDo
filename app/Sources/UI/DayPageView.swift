import SwiftUI
import UniformTypeIdentifiers
import Core

/// 某一天的一整页（4.0 排印日课）：刊头线、大日期、主线即标题、页边编号、hairline 分栏。
/// 拖拽机械与 2.0 完全一致（落点、让位、看门狗），换的只是排版。
public struct DayPageView: View {
    @EnvironmentObject var store: TaskStore

    public let day: String
    @State private var mainDraft = ""
    @State private var branchDraft = ""

    private enum InputField: Hashable { case main, branch }
    @FocusState private var inputFocused: InputField?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @EnvironmentObject private var session: InputSession
    @EnvironmentObject private var drag: DragController
    @State private var cardHeights: [UUID: CGFloat] = [:]
    @State private var liveFrames: [UUID: CGRect] = [:]
    @State private var frozenFrames: [UUID: CGRect] = [:]
    @State private var frameCaptureUntil: Date = .distantPast
    @State private var mainTargeted = false
    @State private var branchTargeted = false
    @State private var dragWatchdog: Timer?
    /// 夜之城下方的两栏宽度（按 1.35 : 1 分配，需要读到实际宽度）。
    @State private var logRowWidth: CGFloat = 0
    /// 「今日一件」完成庆典正在展示的主线标题。
    @State private var ceremonyTitle: String?

    private var listAnimation: Animation? { reduceMotion ? nil : Motion.spring }

    /// 卡片（拖拽单元）之间的垂直空隙：日课在纸上留白更大。
    private var cardGap: CGFloat { Theme.panelEnabled ? 18 : 26 }

    public init(day: String) {
        self.day = day
    }

    private var isToday: Bool { day == store.currentDay }
    private var isFuture: Bool { day > store.currentDay }
    private var roots: [Task] { store.roots(of: day) }
    private var mainGoal: Task? { store.mainGoal(on: day) }
    private var branches: [Task] { store.branches(on: day) }
    private var finished: [Task] { store.doneTasks(on: day) }

    private var weekdayName: String {
        guard let date = DayKey.date(from: day) else { return "" }
        let w = Calendar(identifier: .gregorian).component(.weekday, from: date)
        return ["日", "一", "二", "三", "四", "五", "六"][max(0, min(6, w - 1))]
    }

    private var dayOfYear: Int {
        guard let date = DayKey.date(from: day) else { return 0 }
        let cal = Calendar(identifier: .gregorian)
        let start = cal.dateInterval(of: .year, for: date)?.start ?? date
        return (cal.dateComponents([.day], from: start, to: cal.startOfDay(for: date)).day ?? 0) + 1
    }

    /// 「十月二十四日」
    private var cnDate: String { DayKey.cnLabel(for: day) }

    public var body: some View {
        Group {
            if Theme.isNight {
                // 夜之城：整页固定视口（不滚动），滚动只发生在三个面板内部
                nightLayout
                    .frame(maxHeight: .infinity, alignment: .top)
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    header
                    ScrollView {
                        rikeLayout
                            .padding(.bottom, 26)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                if drag.draggingId == nil { session.finishByClickingAway(store: store) }
                            }
                            .animation(listAnimation, value: store.tasks)
                            .animation(listAnimation, value: store.selectedDay)
                    }
                }
            }
        }
        .onChange(of: collapseCards) { _, collapsed in
            if collapsed {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.28) {
                    if drag.draggingId != nil { frozenFrames = liveFrames }
                }
            } else {
                frozenFrames = [:]
            }
        }
        .animation(listAnimation, value: collapseCards)
        .onChange(of: drag.draggingId) { _, dragging in
            if dragging == nil {
                frozenFrames = [:]
                drag.end()
                dragWatchdog?.invalidate()
                dragWatchdog = nil
            } else {
                startDragWatchdog()
            }
        }
        .background(
            Theme.dayBackground
                .contentShape(Rectangle())
                .onTapGesture {
                    if drag.draggingId == nil { session.finishByClickingAway(store: store) }
                }
        )
        .onChange(of: store.celebratedMainId) { _, newId in
            guard let id = newId, let task = store.task(id) else {
                store.celebratedMainId = nil
                return
            }
            guard !reduceMotion else {
                store.celebratedMainId = nil
                return
            }
            ceremonyTitle = task.title
            let title = task.title
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
                if ceremonyTitle == title { ceremonyTitle = nil }
                store.celebratedMainId = nil
            }
        }
        .overlay {
            if let title = ceremonyTitle {
                MainCeremonyOverlay(title: title) {
                    ceremonyTitle = nil
                    store.celebratedMainId = nil
                }
                .zIndex(30)
            }
        }
        .background(
            Button("新建支线") { inputFocused = .branch }
                .keyboardShortcut("n", modifiers: [.command])
                .opacity(0)
                .frame(width: 0, height: 0)
                .accessibilityHidden(true)
        )
    }

    /// 夜之城：页面底部的终端状态行。
    private var nightStatus: some View {
        HStack(spacing: 16) {
            Text("未结 \(store.poolCount) · 归档 \(store.doneTasks.count) · ALL LOCAL")
                .font(Theme.mono(9.5))
                .tracking(2)
                .foregroundStyle(Theme.ink3)
            Spacer()
            HazardStripe()
            Text("REV \(AppVersion.current) // NC")
                .font(Theme.mono(9.5))
                .tracking(2)
                .foregroundStyle(Theme.ink3)
        }
        .padding(.top, 30)
    }

    private func startDragWatchdog() {
        dragWatchdog?.invalidate()
        dragWatchdog = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { timer in
            MainActor.assumeIsolated {
                guard NSEvent.pressedMouseButtons == 0 else { return }
                timer.invalidate()
                dragWatchdog = nil
                drag.end()
            }
        }
    }

    // MARK: 骨架

    /// 日课：单列排印页，分栏之间整行呼吸。
    private var rikeLayout: some View {
        VStack(alignment: .leading, spacing: 0) {
            mainSection
            sectionGap
            // 主线子树较长时，支线区容易贴上来：主线之后再多给一口气
            Spacer().frame(height: 16)
            branchSection
            if !finished.isEmpty {
                sectionGap
                doneSection
            }
        }
        .padding(.horizontal, 26)
        .padding(.top, 34)
    }

    /// 夜之城：任务日志三面板——主线小面板在上（高度小于下面一行），
    /// 支线与已完成左右并排（1.35 : 1，支线长于完成），底部状态行。
    /// 整页不滚动；面板内部各自滚动。
    private var nightLayout: some View {
        VStack(alignment: .leading, spacing: 20) {
            nightMainPanel
                .frame(height: 280)
            HStack(alignment: .top, spacing: 22) {
                nightSidePanel
                    .frame(maxHeight: .infinity)
                    .frame(maxWidth: .infinity)
                if !nightFinished.isEmpty {
                    nightDonePanel
                        .frame(maxHeight: .infinity)
                        .frame(width: logRowWidth >= 100 ? max(0, logRowWidth - 22) * 0.425 : 320)
                }
            }
            .frame(maxHeight: .infinity, alignment: .top)
            .background(
                GeometryReader { geo in
                    Color.clear
                        .onAppear { logRowWidth = geo.size.width }
                        .onChange(of: geo.size.width) { _, w in logRowWidth = w }
                }
            )
            nightStatus
        }
        .padding(.horizontal, 34)
        .padding(.top, 28)
        .padding(.bottom, 20)
    }

    /// 当天的主线（含已完成）：优先进行中的那条；只有全部完成时才显示完成态主线。
    /// 一天只有一个主线——完成后留在主线面板，不产生第二条。
    private var mainAny: Task? {
        let mains = store.tasks.filter { $0.day == day && $0.isMain && $0.parentId == nil }
        return mains.first { !$0.done } ?? mains.first
    }

    /// 夜之城的已完成面板：只收支线（主线留在主线面板）。
    private var nightFinished: [Task] {
        finished.filter { !$0.isMain }
    }

    /// 分栏之间的空隙：一整行 breathing（日课用）。
    private var sectionGap: some View {
        Spacer().frame(height: 42)
    }

    /// 刊头：日课＝3pt 墨线 + 宋体日期；夜之城＝终端读出行。
    @ViewBuilder
    private var header: some View {
        if Theme.isNight {
            HStack(alignment: .firstTextBaseline, spacing: 16) {
                Text("JOB_\(dayOfYear) · \(compactDate)")
                    .font(Theme.mono(10.5, .semibold))
                    .tracking(2.5)
                    .foregroundStyle(Theme.signal)
                if !isToday {
                    Button {
                        store.selectDay(store.currentDay)
                    } label: {
                        Text("回到今天")
                            .font(Theme.mono(9.5))
                            .tracking(1)
                            .foregroundStyle(Theme.ink2)
                            .overlay(alignment: .bottom) {
                                Rectangle().fill(Theme.rule).frame(height: 1).offset(y: 2)
                            }
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
                Text(isToday ? "今日一件" : "查看那一天")
                    .font(Theme.mono(9))
                    .tracking(2)
                    .foregroundStyle(Theme.ink3)
            }
            .padding(.horizontal, 26)
            .padding(.top, 36)
            .overlay(alignment: .bottom) {
                Rectangle().fill(Theme.rule).frame(height: 1).padding(.horizontal, 26)
            }
            .padding(.bottom, 10)
        } else {
            VStack(alignment: .leading, spacing: 0) {
                Rectangle().fill(Theme.ink).frame(height: 3)
                HStack(alignment: .firstTextBaseline) {
                    Text(cnDate)
                        .font(Theme.display(Theme.dateDisplaySize))
                        .tracking(2)
                        .foregroundStyle(isFuture ? Theme.ink3 : Theme.ink)
                    Spacer()
                    VStack(alignment: .trailing, spacing: 6) {
                        Text("星期\(weekdayName) · 第 \(dayOfYear) 日")
                            .font(Theme.mono(Theme.metaSize))
                            .tracking(1.5)
                            .foregroundStyle(Theme.ink3)
                        if !isToday {
                            Button {
                                store.selectDay(store.currentDay)
                            } label: {
                                Text("回到今天")
                                    .font(Theme.mono(9.5))
                                    .tracking(1)
                                    .foregroundStyle(Theme.ink2)
                                    .overlay(alignment: .bottom) {
                                        Rectangle().fill(Theme.hairline).frame(height: 1).offset(y: 2)
                                    }
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.top, 20)
                Rectangle().fill(Theme.dayRule).frame(height: 1).padding(.top, 20)
            }
            .padding(.horizontal, 26)
            .padding(.top, 44)
        }
    }

    /// 10.24
    private var compactDate: String {
        guard let date = DayKey.date(from: day) else { return day }
        let cal = Calendar(identifier: .gregorian)
        return String(format: "%02d.%02d", cal.component(.month, from: date), cal.component(.day, from: date))
    }

    // MARK: 三栏

    private var mainSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHeader(
                "今日主线",
                hint: "把任务拖到这里 = 设为主线",
                targeted: mainTargeted,
                binding: $mainTargeted,
                action: { store.setMain($0) },
                enabled: { store.canBecomeMain($0.id, on: day) }
            )
            if let goal = mainGoal {
                draggableCard(goal, at: 0, in: [goal]) {
                    TaskCardChrome(task: goal, style: Theme.cardStyle, completed: goal.done) {
                        TaskRowView(task: goal, level: 1, isMain: true, showsRoleGlyph: false, onCard: true, showsFolio: false)
                            .padding(.top, 16)
                        if !collapseCards {
                            TaskSubtreeView(parentId: goal.id, level: 2, showsRails: false, showsRoleGlyph: false, onCard: true, showsFolio: true)
                                .padding(.top, 10)
                        }
                    }
                }
                rootDropZone
            } else {
                writingLine(
                    text: $mainDraft,
                    placeholder: isToday ? "写下今天最重要的一件事" : "写下这一天最重要的事",
                    prominent: true,
                    commit: { let m = store.addMain(mainDraft, on: day); mainDraft = "" },
                    onTab: commitMainContinue
                )
                .padding(.top, 18)
                if !roots.isEmpty {
                    Text("今天还没有主线")
                        .font(Theme.sans(10.5))
                        .tracking(1)
                        .foregroundStyle(Theme.ink3)
                        .padding(.top, 10)
                }
            }
        }
    }

    // MARK: 夜之城三面板

    /// 主线任务面板（22pt 大切角）：黄标签 + JOB 码 + DIN 标题 + 目标列表。
    /// 主线不配勾选框——完成用行尾的「完成」按钮；完成后留在面板里标「今日主线已完成」。
    @ViewBuilder
    private var nightMainPanel: some View {
        NightPanel(corner: 22) {
            VStack(alignment: .leading, spacing: 0) {
                if let m = mainAny, m.done {
                    doneQuestHeader
                } else {
                    nightQuestHeader
                }
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        if let goal = mainAny {
                            draggableCard(goal, at: 0, in: [goal]) {
                                VStack(alignment: .leading, spacing: 0) {
                                    TaskRowView(
                                        task: goal,
                                        level: 1,
                                        isMain: true,
                                        showsRoleGlyph: false,
                                        onCard: true,
                                        showsFolio: false,
                                        showsRing: false,
                                        mainCompleteAction: goal.done ? nil : { store.complete(goal.id) },
                                        mainRevertAction: goal.done ? { store.revert(goal.id) } : nil
                                    )
                                    .padding(.top, 10)
                                    if !collapseCards {
                                        // 主线下方的横线：把它衬成「这一天的主题」，而不是一条任务
                                        Rectangle().fill(Theme.rule).frame(height: 1).padding(.top, 14)
                                        objectivesLabel
                                            .padding(.top, 12)
                                        TaskSubtreeView(parentId: goal.id, level: 2, showsRails: false, showsRoleGlyph: false, onCard: true, showsFolio: true)
                                    }
                                }
                            }
                            rootDropZone
                        } else {
                            writingLine(
                                text: $mainDraft,
                                placeholder: isToday ? "写下今天最重要的一件事" : "写下这一天最重要的事",
                                prominent: true,
                                commit: { let m = store.addMain(mainDraft, on: day); mainDraft = "" },
                                onTab: commitMainContinue
                            )
                            .padding(.top, 12)
                            if !roots.isEmpty {
                                Text("NO MAIN JOB · 今天还没有主线")
                                    .font(Theme.mono(9))
                                    .tracking(1.5)
                                    .foregroundStyle(Theme.ink3)
                                    .padding(.top, 10)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: .infinity)
            }
        }
    }

    /// 主线完成后的标签行：不进已完成面板，留在主线位。
    private var doneQuestHeader: some View {
        HStack(spacing: 14) {
            Text("今日主线已完成")
                .font(Theme.mono(10, .bold))
                .tracking(2)
                .foregroundStyle(Theme.accent)
                .padding(.horizontal, 10)
                .padding(.vertical, 3)
                .clipShape(CutCornerShape(radius: 5))
                .overlay(CutCornerShape(radius: 5).stroke(Theme.accent, lineWidth: 1.2))
            Text("JOB_\(dayOfYear) // DONE")
                .font(Theme.mono(9.5))
                .tracking(1.5)
                .foregroundStyle(Theme.ink3)
            Spacer(minLength: 0)
        }
        .padding(.bottom, 2)
    }

    /// 支线面板（14pt 切角）：菱形角色标 + 行间 hairline；固定高度，超出内部滚动。
    private var nightSidePanel: some View {
        NightPanel(corner: 14) {
            VStack(alignment: .leading, spacing: 0) {
                nightPanelLabel("SIDE JOBS · 支线任务", targeted: branchTargeted, hint: "拖到这里 = 作为支线")
                    .modifier(OptionalDropTarget(
                        store: store, drag: drag, binding: $branchTargeted,
                        action: { store.unsetMain($0) },
                        enabled: { store.canBecomeBranch($0.id, on: day) }
                    ))

                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(Array(branches.enumerated()), id: \.element.id) { index, task in
                            draggableCard(task, at: index, in: branches) {
                                VStack(alignment: .leading, spacing: 0) {
                                    TaskRowView(task: task, level: 1, showsRoleGlyph: false, onCard: true, showsFolio: true)
                                    if !collapseCards {
                                        TaskSubtreeView(parentId: task.id, level: 2, showsRails: false, showsRoleGlyph: false, onCard: true, showsFolio: true)
                                    }
                                }
                                .padding(.vertical, 6)
                                .overlay(alignment: .bottom) {
                                    if index < branches.count - 1 {
                                        Rectangle().fill(Theme.rule).frame(height: 1)
                                    }
                                }
                            }
                        }
                    }
                    .padding(.top, 2)
                    .coordinateSpace(name: "branchList")
                    .onPreferenceChange(CardFramePreference.self) { frames in
                        guard drag.draggingId == nil || Date() < frameCaptureUntil else { return }
                        if frames != liveFrames { liveFrames = frames }
                    }
                    .overlay(alignment: .topLeading) {
                        if let insertAt = drag.insertIndex, !branches.isEmpty {
                            BranchInsertionLine(
                                index: insertAt,
                                frames: frozenFrames,
                                ids: branches.map(\.id),
                                spacing: 0
                            )
                        }
                    }
                    .onDrop(of: [UTType.text], delegate: BranchListDropDelegate(
                        store: store,
                        drag: drag,
                        ids: { branches.map(\.id) },
                        frames: { frozenFrames.isEmpty ? liveFrames : frozenFrames }
                    ))
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: .infinity)

                writingLine(
                    text: $branchDraft,
                    placeholder: "写一件支线",
                    prominent: false,
                    commit: commitBranchEnter,
                    onTab: commitBranchContinue
                )
                .padding(.top, 8)
            }
        }
    }

    /// 已完成面板（窄列）：灰化 + 划线 + ✓；固定高度，超出内部滚动。
    private var nightDonePanel: some View {
        NightPanel(corner: 14) {
            VStack(alignment: .leading, spacing: 0) {
                nightPanelLabel("COMPLETED · 已完成 · \(nightFinished.count)")
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(Array(nightFinished.enumerated()), id: \.element.id) { index, task in
                            VStack(alignment: .leading, spacing: 0) {
                                TaskRowView(task: task, level: 1, readOnly: true, showsRevert: true, showsRoleGlyph: false, onCard: true, showsFolio: true)
                                if !collapseCards {
                                    TaskSubtreeView(parentId: task.id, level: 2, readOnly: true, showsRevert: true, showsRails: false, showsRoleGlyph: false, onCard: true)
                                }
                            }
                            .padding(.vertical, 8)
                            .overlay(alignment: .bottom) {
                                if index < nightFinished.count - 1 {
                                    Rectangle().fill(Theme.rule).frame(height: 1)
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: .infinity)
            }
        }
    }

    /// 面板顶部的等宽小标（夜之城），拖动时给出投放提示。
    private func nightPanelLabel(_ text: String, targeted: Bool = false, hint: String? = nil) -> some View {
        HStack(spacing: 12) {
            Text(text)
                .font(Theme.mono(9.5, .semibold))
                .tracking(3)
                .foregroundStyle(targeted ? Theme.accent : Theme.signal)
            if drag.draggingId != nil, let hint {
                Text(targeted ? "松手就落在这里" : hint)
                    .font(Theme.mono(8.5))
                    .tracking(1)
                    .foregroundStyle(targeted ? Theme.accent : Theme.ink3)
            }
            Spacer(minLength: 0)
        }
        .padding(.bottom, 6)
        .contentShape(Rectangle())
    }

    /// 主线面板的标签行：黄色 MAIN JOB 切角标签 + 任务代码；本身是「设为主线」的投放目标。
    private var nightQuestHeader: some View {
        let dragging = drag.draggingId != nil
        let relevant = drag.draggingId.flatMap { store.task($0) }.map { store.canBecomeMain($0.id, on: day) } ?? true
        return HStack(spacing: 14) {
            Text("主线任务 MAIN JOB")
                .font(Theme.mono(10, .bold))
                .tracking(2)
                .foregroundStyle(mainTargeted ? Theme.accent : Theme.fillInk)
                .padding(.horizontal, 10)
                .padding(.vertical, 3)
                .background(mainTargeted ? Color.clear : Theme.accent)
                .clipShape(CutCornerShape(radius: 5))
                .overlay(
                    CutCornerShape(radius: 5)
                        .stroke(mainTargeted ? Theme.accent : Color.clear, lineWidth: 1.2)
                )
            Text("JOB_\(dayOfYear) // 今日一件")
                .font(Theme.mono(9.5))
                .tracking(1.5)
                .foregroundStyle(mainTargeted ? Theme.accent : Theme.ink3)
            if dragging && relevant {
                Text(mainTargeted ? "松手设为主线" : "拖到这里 = 设为主线")
                    .font(Theme.mono(9))
                    .tracking(1)
                    .foregroundStyle(mainTargeted ? Theme.accent : Theme.ink3)
            }
            Spacer(minLength: 0)
        }
        .padding(.bottom, 2)
        .contentShape(Rectangle())
        .modifier(OptionalDropTarget(
            store: store, drag: drag, binding: $mainTargeted,
            action: { store.setMain($0) },
            enabled: { store.canBecomeMain($0.id, on: day) }
        ))
    }

    /// 夜之城：目标区的青色小标。
    private var objectivesLabel: some View {
        Text("目标 OBJECTIVES")
            .font(Theme.mono(9.5, .semibold))
            .tracking(3)
            .foregroundStyle(Theme.signal)
            .padding(.bottom, 6)
    }

    private var branchSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHeader(
                "今日支线",
                hint: "拖到这里 = 作为支线",
                targeted: branchTargeted,
                binding: $branchTargeted,
                action: { store.unsetMain($0) },
                enabled: { store.canBecomeBranch($0.id, on: day) }
            )
            VStack(spacing: cardGap) {
                ForEach(Array(branches.enumerated()), id: \.element.id) { index, task in
                    draggableCard(task, at: index, in: branches) {
                        TaskCardChrome(task: task, style: Theme.cardStyle, completed: task.done) {
                            TaskRowView(task: task, level: 1, showsRoleGlyph: false, onCard: true, showsFolio: true)
                            if !collapseCards {
                                TaskSubtreeView(parentId: task.id, level: 2, showsRails: false, showsRoleGlyph: false, onCard: true, showsFolio: true)
                            }
                        }
                    }
                }
            }
            .padding(.top, 22)
            .coordinateSpace(name: "branchList")
            .onPreferenceChange(CardFramePreference.self) { frames in
                guard drag.draggingId == nil || Date() < frameCaptureUntil else { return }
                if frames != liveFrames { liveFrames = frames }
            }
            .overlay(alignment: .topLeading) {
                if let insertAt = drag.insertIndex, !branches.isEmpty {
                    BranchInsertionLine(
                        index: insertAt,
                        frames: frozenFrames,
                        ids: branches.map(\.id),
                        spacing: cardGap
                    )
                }
            }
            .onDrop(of: [UTType.text], delegate: BranchListDropDelegate(
                store: store,
                drag: drag,
                ids: { branches.map(\.id) },
                frames: { frozenFrames.isEmpty ? liveFrames : frozenFrames }
            ))

            writingLine(
                text: $branchDraft,
                placeholder: "写一件支线",
                prominent: false,
                commit: commitBranchEnter,
                onTab: commitBranchContinue
            )
            .padding(.top, Theme.panelEnabled ? 14 : 6)
        }
    }

    @ViewBuilder
    private var doneSection: some View {
        if !finished.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                sectionHeader(
                    "今日完成",
                    hint: "拖到这里 = 直接完成",
                    targeted: false,
                    binding: nil,
                    action: { store.complete($0) }
                )
                VStack(spacing: cardGap) {
                    ForEach(finished) { task in
                        TaskCardChrome(task: task, style: Theme.cardStyle, completed: true) {
                            TaskRowView(task: task, level: 1, readOnly: true, showsRevert: true, showsRoleGlyph: false, onCard: true, showsFolio: true)
                            if !collapseCards {
                                TaskSubtreeView(parentId: task.id, level: 2, readOnly: true, showsRevert: true, showsRails: false, showsRoleGlyph: false, onCard: true, showsFolio: true)
                            }
                        }
                    }
                }
                .padding(.top, 14)
            }
        }
    }

    private func sectionHeader(
        _ title: String,
        note: String? = nil,
        hint: String? = nil,
        targeted: Bool = false,
        binding: Binding<Bool>? = nil,
        action: ((UUID) -> Void)? = nil,
        enabled: ((Task) -> Bool)? = nil
    ) -> some View {
        let dragged = drag.draggingId.flatMap { store.task($0) }
        let relevant = dragged.map { enabled?($0) ?? true } ?? true
        let dragging = drag.draggingId != nil && relevant
        return HStack(alignment: .firstTextBaseline, spacing: 16) {
            Text(title)
                .font(Theme.sans(Theme.sectionSize, .medium))
                .tracking(8)
                .foregroundStyle(targeted ? Theme.ink : Theme.ink2)
            if let note {
                Text(note).font(Theme.sans(10)).foregroundStyle(Theme.ink3)
            }
            Rectangle().fill(Theme.dayRule).frame(height: 1)
            if dragging, let hint {
                Text(targeted ? "松手就落在这里" : hint)
                    .font(Theme.sans(10))
                    .foregroundStyle(targeted ? Theme.ink : Theme.ink3)
            }
        }
        .padding(.vertical, 6)
        .background(targeted ? Theme.accentSoft.opacity(0.6) : Color.clear)
        .overlay(
            Rectangle().strokeBorder(
                targeted ? Theme.accent.opacity(0.5) : Color.clear,
                style: StrokeStyle(lineWidth: 1, dash: [3, 3])
            )
        )
        .contentShape(Rectangle())
        .modifier(OptionalDropTarget(store: store, drag: drag, binding: binding, action: action, enabled: enabled))
    }

    /// 收集卡片在支线栏坐标系里的位置。
    struct CardFramePreference: PreferenceKey {
        static let defaultValue: [UUID: CGRect] = [:]
        static func reduce(value: inout [UUID: CGRect], nextValue: () -> [UUID: CGRect]) {
            value.merge(nextValue()) { _, new in new }
        }
    }

    /// 整栏投放：用冻结的卡片坐标算插入位置。
    struct BranchListDropDelegate: DropDelegate {
        let store: TaskStore
        let drag: DragController
        let ids: () -> [UUID]
        let frames: () -> [UUID: CGRect]

        private func insertIndex(for y: CGFloat) -> Int {
            let snapshot = frames()
            let list = ids()
            for (index, id) in list.enumerated() {
                if let rect = snapshot[id], y < rect.midY { return index }
            }
            return list.count
        }

        private func draggedRoot() -> UUID? {
            guard let id = drag.draggingId, let task = store.task(id), task.parentId == nil else { return nil }
            return id
        }

        func dropUpdated(info: DropInfo) -> DropProposal? {
            guard draggedRoot() != nil else {
                drag.insertIndex = nil
                return DropProposal(operation: .cancel)
            }
            let next = insertIndex(for: info.location.y)
            if drag.insertIndex != next { drag.insertIndex = next }
            return DropProposal(operation: .move)
        }

        func dropExited(info: DropInfo) { drag.insertIndex = nil }

        func performDrop(info: DropInfo) -> Bool {
            guard let draggingId = draggedRoot() else {
                drag.end()
                return false
            }
            let target = insertIndex(for: info.location.y)
            drag.draggingId = nil
            drag.target = nil
            store.moveRootToBranchIndex(draggingId, target)
            return true
        }
    }

    /// 拖动时在插入位置画的一条落点线。
    struct BranchInsertionLine: View {
        let index: Int
        let frames: [UUID: CGRect]
        let ids: [UUID]
        let spacing: CGFloat

        var body: some View {
            let y: CGFloat = {
                if index < ids.count, let rect = frames[ids[index]] {
                    return rect.minY - spacing / 2
                }
                if let last = ids.last, let rect = frames[last] {
                    return rect.maxY + spacing / 2
                }
                return 0
            }()
            return Rectangle()
                .fill(Theme.accent)
                .frame(height: 1.6)
                .offset(y: y)
                .allowsHitTesting(false)
        }
    }

    private var rootDropZone: some View {
        Color.clear
            .frame(height: 14)
            .contentShape(Rectangle())
            .onDrop(of: [UTType.text], delegate: RootDropDelegate(store: store, drag: drag))
    }

    private func draggableCard<Content: View>(
        _ root: Task,
        at index: Int,
        in list: [Task],
        @ViewBuilder content: () -> Content
    ) -> some View {
        let wrapped = content()
        return wrapped
            .background(
                GeometryReader { geo in
                    let height = geo.size.height
                    Color.clear
                        .onAppear { cardHeights[root.id] = height }
                        .onChange(of: height) { _, h in cardHeights[root.id] = h }
                        .preference(
                            key: CardFramePreference.self,
                            value: [root.id: geo.frame(in: .named("branchList"))]
                        )
                }
            )
            .offset(y: shift(for: root, at: index, in: list))
            .opacity(drag.draggingId == root.id && hasActiveTarget ? 0 : 1)
            .animation(listAnimation, value: drag.insertIndex)
            .onDrag {
                session.finishByClickingAway(store: store)
                drag.end()
                drag.draggingId = root.id
                frozenFrames = liveFrames
                frameCaptureUntil = Date().addingTimeInterval(0.6)
                return NSItemProvider(object: root.id.uuidString as NSString)
            }
    }

    private var collapseCards: Bool {
        guard let id = drag.draggingId, let dragged = store.task(id) else { return false }
        return dragged.parentId == nil
    }

    private var hasActiveTarget: Bool {
        drag.insertIndex != nil || drag.target != nil
    }

    private func shift(for task: Task, at index: Int, in list: [Task]) -> CGFloat {
        guard let draggedId = drag.draggingId,
              draggedId != task.id,
              let insertAt = drag.insertIndex,
              let draggedIndex = list.firstIndex(where: { $0.id == draggedId })
        else { return 0 }

        let gap = (cardHeights[draggedId] ?? 0) + cardGap
        if draggedIndex < insertAt {
            return (index > draggedIndex && index < insertAt) ? -gap : 0
        }
        return (index >= insertAt && index < draggedIndex) ? gap : 0
    }

    /// 书写线（4.0）：主线用大声部 + 强调色下划线；支线是安静的幽灵行（⌘N 直达）。
    /// 回车＝提交（同级继续写），Tab＝提交并把下一条写成它的下级（大纲编辑器语义）。
    private func writingLine(
        text: Binding<String>,
        placeholder: String,
        prominent: Bool,
        commit: @escaping () -> Void,
        onTab: (() -> Void)? = nil
    ) -> some View {
        let field: InputField = prominent ? .main : .branch
        let active = inputFocused == field
        return HStack(alignment: .center, spacing: 12) {
            Circle()
                .strokeBorder(
                    prominent ? Theme.accent.opacity(0.55) : Theme.control.opacity(0.5),
                    style: StrokeStyle(lineWidth: 1.3, dash: prominent ? [] : [2.5, 2.5])
                )
                .frame(width: prominent ? 16 : 14, height: prominent ? 16 : 14)
            TextField(placeholder, text: text)
                .textFieldStyle(.plain)
                .font(prominent ? Theme.display(19) : Theme.sans(13.5))
                .foregroundStyle(Theme.ink)
                .focused($inputFocused, equals: field)
                .onSubmit(commit)
                .onKeyPress(.tab) {
                    guard !text.wrappedValue.isEmpty, let onTab else { return .ignored }
                    onTab()
                    return .handled
                }
            if prominent && !text.wrappedValue.isEmpty {
                Button(action: commit) {
                    Text("写下来")
                        .font(Theme.sans(10.5, .semibold))
                        .tracking(1)
                        .foregroundStyle(Theme.accent)
                }
                .buttonStyle(.plain)
            }
            if !prominent && text.wrappedValue.isEmpty && !active {
                Text("⌘N")
                    .font(Theme.mono(9))
                    .foregroundStyle(Theme.faint)
            }
        }
        .padding(.vertical, prominent ? 12 : 9)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(active ? Theme.accent : Theme.dayRule)
                .frame(height: 1)
        }
        .animation(reduceMotion ? nil : Motion.quick, value: active)
    }

    /// 提交主线并直接开始写它的第一步（Tab）。
    private var commitMainContinue: () -> Void {
        {
            let m = store.addMain(mainDraft, on: day)
            mainDraft = ""
            if let m { session.startCreate(store: store, at: m.id, mode: .child) }
        }
    }

    /// 回车：提交支线，锚点跟到这条——继续回车＝再写一条支线（同级），Tab＝写它的下级。
    private var commitBranchEnter: () -> Void {
        {
            let b = store.addTopLevel(branchDraft, on: day)
            branchDraft = ""
            if let b { session.startCreate(store: store, at: b.id, mode: .sibling) }
        }
    }

    /// 提交支线并直接开始写它的下级（Tab）。
    private var commitBranchContinue: () -> Void {
        {
            let b = store.addTopLevel(branchDraft, on: day)
            branchDraft = ""
            if let b { session.startCreate(store: store, at: b.id, mode: .child) }
        }
    }
}

/// 「今日一件」的完成庆典：主线标题被一道强调色的横线划过，印章砸落。
/// 日课＝朱砂「日」章；夜之城＝黄色切角 COMPLETE。点击任意处可提前关闭。
struct MainCeremonyOverlay: View {
    let title: String
    let onClose: () -> Void

    @State private var struck = false
    @State private var stamped = false

    var body: some View {
        ZStack {
            Rectangle()
                .fill(Theme.canvas)
                .opacity(0.93)
                .contentShape(Rectangle())
                .onTapGesture { onClose() }
            VStack(spacing: 26) {
                Text(title)
                    .font(Theme.display(Theme.isNight ? 28 : 32))
                    .tracking(1)
                    .foregroundStyle(Theme.ink3)
                    .padding(.horizontal, 6)
                    .overlay(alignment: .leading) {
                        GeometryReader { geo in
                            Rectangle()
                                .fill(Theme.accent)
                                .frame(height: 3)
                                .frame(width: struck ? geo.size.width : 0)
                                .offset(y: geo.size.height / 2)
                        }
                    }
                    .rotationEffect(.degrees(-0.5))

                Group {
                    if Theme.isNight {
                        Text("COMPLETE")
                            .font(Theme.display(19))
                            .tracking(5)
                            .foregroundStyle(Theme.fillInk)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 8)
                            .background(Theme.accent)
                            .clipShape(CutCornerShape(radius: 9))
                    } else {
                        ZStack {
                            Circle().strokeBorder(Theme.accent, lineWidth: 2)
                            Text("日")
                                .font(Theme.display(28))
                                .foregroundStyle(Theme.accent)
                        }
                        .frame(width: 68, height: 68)
                    }
                }
                .scaleEffect(stamped ? 1 : 1.7)
                .opacity(stamped ? 1 : 0)
                .rotationEffect(.degrees(stamped ? -4 : 7))

                Text("已完成 · 今日一件")
                    .font(Theme.mono(11, .semibold))
                    .tracking(4)
                    .foregroundStyle(Theme.accent)
                    .opacity(stamped ? 1 : 0)
            }
            .padding(36)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.55)) { struck = true }
            withAnimation(.spring(response: 0.34, dampingFraction: 0.6).delay(0.4)) { stamped = true }
        }
        .transition(.opacity)
    }
}
