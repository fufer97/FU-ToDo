import SwiftUI
import UniformTypeIdentifiers
import Core

/// 某一天的一整页：今日主线、今日支线、今日完成，全部画在主题日页上。
public struct DayPageView: View {
    @EnvironmentObject var store: TaskStore

    public let day: String
    @State private var mainDraft = ""
    @State private var branchDraft = ""
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

    private var listAnimation: Animation? { reduceMotion ? nil : Motion.spring }

    public init(day: String) {
        self.day = day
    }

    private var isToday: Bool { day == store.currentDay }
    private var isFuture: Bool { day > store.currentDay }
    private var roots: [Task] { store.roots(of: day) }
    private var mainGoal: Task? { store.mainGoal(on: day) }
    private var branches: [Task] { store.branches(on: day) }
    private var finished: [Task] { store.doneTasks(on: day) }
    private var doneCount: Int { store.doneCount(on: day) }

    private var weekdayName: String {
        guard let date = DayKey.date(from: day) else { return "" }
        let w = Calendar(identifier: .gregorian).component(.weekday, from: date)
        return ["日", "一", "二", "三", "四", "五", "六"][max(0, min(6, w - 1))]
    }

    private var monthNumber: Int {
        guard let date = DayKey.date(from: day) else { return 1 }
        return Calendar(identifier: .gregorian).component(.month, from: date)
    }

    private var dayNumber: String {
        guard let date = DayKey.date(from: day) else { return "" }
        return String(Calendar(identifier: .gregorian).component(.day, from: date))
    }

    private var weekdayEN: String {
        ["SUNDAY", "MONDAY", "TUESDAY", "WEDNESDAY", "THURSDAY", "FRIDAY", "SATURDAY"][
            max(0, min(6, Calendar(identifier: .gregorian).component(.weekday, from: DayKey.date(from: day) ?? Date()) - 1))
        ]
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Rectangle().fill(Theme.dayRule).frame(height: 0.8).padding(.horizontal, 22)
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    mainSection
                    sectionDivider
                    branchSection
                    if !finished.isEmpty {
                        sectionDivider
                        doneSection
                    }
                }
                .padding(.horizontal, 22)
                .padding(.bottom, 22)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
                .onTapGesture {
                    if drag.draggingId == nil { session.finishByClickingAway(store: store) }
                }
                .animation(listAnimation, value: store.tasks)
                .animation(listAnimation, value: store.selectedDay)
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
        .overlay(alignment: .leading) {
            if Theme.choice == .blueprint {
                Rectangle().fill(Theme.rule).frame(width: 0.8)
            }
        }
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

    private var sectionDivider: some View {
        Rectangle().fill(Theme.dayRule).frame(height: 0.8)
            .padding(.top, 18).padding(.bottom, 14)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text("\(weekdayEN)  /  \(monthNumber).\(dayNumber)")
                    .font(Theme.mono(8.5)).tracking(2.2)
                    .foregroundStyle(Theme.dayInk3)
                Spacer()
                if isToday {
                    Text("●  LIVE").font(Theme.mono(8)).tracking(1.6)
                        .foregroundStyle(Theme.dayInk)
                } else {
                    Button {
                        store.selectDay(store.currentDay)
                    } label: {
                        Text("回到今天").font(Theme.mono(8.5)).tracking(1).foregroundStyle(Theme.dayInk2)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 22).padding(.top, 22)

            Text(dayNumber)
                .font(Theme.display(Theme.dateDisplaySize))
                .tracking(Theme.displayTracking(Theme.dateDisplaySize))
                .foregroundStyle(isFuture ? Theme.dayInk3 : Theme.dayInk)
                .padding(.horizontal, 18)
                .padding(.top, -2)

            HStack(spacing: 10) {
                Text("\(monthNumber) 月 · 星期\(weekdayName)")
                    .font(Theme.mono(9.5)).tracking(2)
                    .foregroundStyle(Theme.dayInk2)
                Rectangle().fill(Theme.dayRule).frame(width: 18, height: 0.7)
                Text(countText)
                    .font(Theme.mono(8.5)).tracking(0.6)
                    .foregroundStyle(Theme.dayInk3)
            }
            .padding(.horizontal, 22)
            .padding(.top, 2)
            .padding(.bottom, 14)
        }
    }

    private var countText: String {
        let total = store.taskCount(on: day)
        if total == 0 { return "还没有写下任何事" }
        if doneCount > 0 { return "\(total) 件事 · \(doneCount) 件已完成" }
        return "\(total) 件事"
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
                        TaskRowView(task: goal, level: 1, isMain: true, showsRoleGlyph: false, onCard: true)
                        if !collapseCards {
                            TaskSubtreeView(parentId: goal.id, level: 2, showsRails: false, showsRoleGlyph: false, onCard: true)
                        }
                    }
                }
                rootDropZone
            } else {
                writingLine(
                    text: $mainDraft,
                    placeholder: isToday ? "写下今天最重要的一件事" : "写下这一天最重要的事",
                    prominent: true,
                    icon: "square.and.pencil"
                ) {
                    store.addMain(mainDraft, on: day)
                    mainDraft = ""
                }
                if !roots.isEmpty {
                    Text("今天还没有主线")
                        .font(Theme.mono(8.5)).tracking(1)
                        .foregroundStyle(Theme.dayInk3)
                        .padding(.top, 8)
                }
            }
        }
        .padding(.top, 16)
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
            VStack(spacing: 10) {
                ForEach(Array(branches.enumerated()), id: \.element.id) { index, task in
                    draggableCard(task, at: index, in: branches) {
                        TaskCardChrome(task: task, style: Theme.cardStyle, completed: task.done) {
                            TaskRowView(task: task, level: 1, showsRoleGlyph: false, onCard: true)
                            if !collapseCards {
                                TaskSubtreeView(parentId: task.id, level: 2, showsRails: false, showsRoleGlyph: false, onCard: true)
                            }
                        }
                    }
                }
            }
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
                        spacing: 10
                    )
                }
            }
            .onDrop(of: [UTType.text], delegate: BranchListDropDelegate(
                store: store,
                drag: drag,
                ids: { branches.map(\.id) },
                frames: { frozenFrames.isEmpty ? liveFrames : frozenFrames }
            ))
            .padding(.top, 2)

            writingLine(
                text: $branchDraft,
                placeholder: "添加一件次要的事",
                prominent: false,
                icon: "plus",
                onCard: false
            ) {
                store.addTopLevel(branchDraft, on: day)
                branchDraft = ""
            }
            .padding(.top, 10)
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
                VStack(spacing: 10) {
                    ForEach(finished) { task in
                        TaskCardChrome(task: task, style: Theme.cardStyle, completed: true) {
                            TaskRowView(task: task, level: 1, readOnly: true, showsRevert: true, showsRoleGlyph: false, onCard: true)
                            if !collapseCards {
                                TaskSubtreeView(parentId: task.id, level: 2, readOnly: true, showsRevert: true, showsRails: false, showsRoleGlyph: false, onCard: true)
                            }
                        }
                    }
                }
            }
            .padding(.bottom, 8)
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
        return HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(title)
                .font(Theme.mono(9, .semibold))
                .tracking(2.0)
                .foregroundStyle(targeted ? Theme.dayInk : Theme.dayInk3)
            if let note {
                Text(note).font(Theme.mono(8)).foregroundStyle(Theme.dayInk3)
            }
            Rectangle().fill(Theme.dayRule).frame(height: 0.7).padding(.top, 2)
            if dragging, let hint {
                Text(targeted ? "松手就落在这里" : hint)
                    .font(Theme.mono(7.5)).tracking(0.6)
                    .foregroundStyle(targeted ? Theme.dayInk : Theme.dayInk3)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(targeted ? Theme.dayInk.opacity(0.08) : Color.clear)
        .overlay(
            Rectangle().strokeBorder(
                targeted ? Theme.dayInk.opacity(0.45) : Color.clear,
                style: StrokeStyle(lineWidth: 0.8, dash: [3, 3])
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
                .fill(Theme.dayInk)
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

        let gap = (cardHeights[draggedId] ?? 0) + 10
        if draggedIndex < insertAt {
            return (index > draggedIndex && index < insertAt) ? -gap : 0
        }
        return (index >= insertAt && index < draggedIndex) ? gap : 0
    }

    /// 书写线：主线是页面上的第一行，支线是一条安静的输入行。
    private func writingLine(
        text: Binding<String>,
        placeholder: String,
        prominent: Bool,
        icon: String,
        onCard: Bool = false,
        commit: @escaping () -> Void
    ) -> some View {
        let ink = onCard ? Theme.cardInk : Theme.dayInk
        return HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: prominent ? 12 : 10, weight: .medium))
                .foregroundStyle(ink.opacity(prominent ? 0.9 : 0.45))
                .frame(width: 16)
            TextField(placeholder, text: text)
                .textFieldStyle(.plain)
                .font(Theme.display(prominent ? 18 : 13))
                .foregroundStyle(ink)
                .onSubmit(commit)
            if !text.wrappedValue.isEmpty {
                Button(action: commit) {
                    Text("写下来")
                        .font(Theme.mono(8.5, .semibold)).tracking(1)
                        .foregroundStyle(ink)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, prominent ? 12 : 9)
        .background(prominent ? ink.opacity(0.05) : Color.clear)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Theme.dayRule).frame(height: 0.8)
        }
    }
}
