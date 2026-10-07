import SwiftUI
import UniformTypeIdentifiers
import Core

/// 某一天的一页：今日主线（写在最上面的那件事）、今日支线、今日完成。
public struct DayPageView: View {
    @EnvironmentObject var store: TaskStore

    public let day: String
    @State private var mainDraft = ""
    @State private var branchDraft = ""
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @EnvironmentObject private var session: InputSession
    @EnvironmentObject private var drag: DragController
    @State private var cardHeights: [UUID: CGFloat] = [:]
    /// 卡片在支线栏坐标系里的位置：实时测量 + 拖动开始时冻结（冻结后落点不再被让位动画影响）
    @State private var liveFrames: [UUID: CGRect] = [:]
    @State private var frozenFrames: [UUID: CGRect] = [:]
    /// 拖动开始后的一小段窗口内允许更新坐标（收起动画结束要重新冻结一次），
    /// 窗口之外不再写状态——否则让位动画每移动一帧都会写一次 @State，直接掉帧。
    @State private var frameCaptureUntil: Date = .distantPast
    @State private var mainTargeted = false
    @State private var branchTargeted = false
    /// 拖动收尾看门狗：拖动会话不一定给我们"结束"回调，
    /// 一旦鼠标松开就强制把拖动状态清干净（否则源卡片会一直透明）。
    @State private var dragWatchdog: Timer?

    private var listAnimation: Animation? { reduceMotion ? nil : Motion.spring }

    public init(day: String) {
        self.day = day
    }

    private var isToday: Bool { day == store.currentDay }
    /// 还没到的日子：标题也压淡，和过去的日子区分开。
    private var isFuture: Bool { day > store.currentDay }
    private var roots: [Task] { store.roots(of: day) }
    private var mainGoal: Task? { store.mainGoal(on: day) }
    private var branches: [Task] { store.branches(on: day) }
    private var finished: [Task] { store.doneTasks(on: day) }
    private var doneCount: Int { store.doneCount(on: day) }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            hairline
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    mainSection
                    sectionDivider
                    branchSection
                    // 完成栏为空时不画分隔线：否则会出现一条"通向空处"的线
                    if !finished.isEmpty {
                        sectionDivider
                        doneSection
                    }
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 18)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
                .onTapGesture {
                    // 拖动过程中不处理"点空白结束输入"
                    if drag.draggingId == nil { session.finishByClickingAway(store: store) }
                }
                .animation(listAnimation, value: store.tasks)
                .animation(listAnimation, value: store.selectedDay)
            }
        }
        .onChange(of: collapseCards) { _, collapsed in
            if collapsed {
                // 等收起动画结束再冻结坐标：落点判定用的是收起后的布局
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
                // 拖动结束：清掉冻结坐标、落点提示与看门狗
                frozenFrames = [:]
                drag.end()
                dragWatchdog?.invalidate()
                dragWatchdog = nil
            } else {
                startDragWatchdog()
            }
        }
        .background(
            Theme.paper
                .contentShape(Rectangle())
                .onTapGesture {
                    // 拖动过程中不处理"点空白结束输入"
                    if drag.draggingId == nil { session.finishByClickingAway(store: store) }
                }
        )
    }

    /// 拖动期间每 0.2 秒看一眼鼠标：一旦松开，说明这次拖动已经结束
    /// （不管有没有落到地方），立刻收尾。
    private func startDragWatchdog() {
        dragWatchdog?.invalidate()
        dragWatchdog = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { timer in
            // 计时器跑在主 run loop 上，所以这里是主 actor 上下文
            MainActor.assumeIsolated {
                guard NSEvent.pressedMouseButtons == 0 else { return }
                timer.invalidate()
                dragWatchdog = nil
                drag.end()
            }
        }
    }

    // MARK: 骨架

    /// 面板里所有横线的左右留白必须一致：都跟卡片对齐（左右各 18pt）。
    private var hairline: some View {
        Rectangle()
            .fill(Theme.hairline)
            .frame(height: 1)
            .padding(.horizontal, 18)
    }

    /// 分隔线：上方留白略大于下方，让"标题更靠近它管的内容"。
    private var sectionDivider: some View {
        Rectangle()
            .fill(Theme.hairline)
            .frame(height: 1)
            .padding(.top, 20)
            .padding(.bottom, 14)
    }

    /// 可投放的栏标题：拖动时变成虚线投放区，并说明会落到哪一层。
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
                .font(Theme.sectionFont)
                .foregroundStyle(targeted ? Theme.accentInk : Theme.ink3)
                .tracking(0.4)
            if let note {
                Text(note)
                    .font(Theme.sans(11))
                    .foregroundStyle(Theme.faint)
            }
            Spacer()
            if dragging, let hint {
                Text(targeted ? "松手就落在这里" : hint)
                    .font(Theme.sans(10.5))
                    .foregroundStyle(targeted ? Theme.accent : Theme.faint)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(targeted ? Theme.accentSoft : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .strokeBorder(
                    targeted ? Theme.accent.opacity(0.7) : Color.clear,
                    style: StrokeStyle(lineWidth: 1, dash: [3, 3])
                )
        )
        .padding(.horizontal, -8)
        .contentShape(Rectangle())
        .modifier(OptionalDropTarget(store: store, drag: drag, binding: binding, action: action, enabled: enabled))
    }



    private var header: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(DayKey.label(for: day))
                    .font(Theme.serif(Theme.dateSize, .semibold))
                    .foregroundStyle(isFuture ? Theme.ink3 : Theme.ink)
                if isToday {
                    Text("今天")
                        .font(Theme.sans(10.5, .semibold))
                        .foregroundStyle(Theme.accentInk)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Theme.accentSoft.opacity(0.6)))
                }
                Spacer()
                if !isToday {
                    Button {
                        store.selectDay(store.currentDay)
                    } label: {
                        Text("回到今天")
                            .font(Theme.sans(11.5, .medium))
                            .foregroundStyle(Theme.accent)
                    }
                    .buttonStyle(.plain)
                }
            }
            Text(countText)
                .font(Theme.sans(Theme.metaSize))
                .foregroundStyle(Theme.ink3)
        }
        .padding(.horizontal, 18)
        .padding(.top, 18)
        .padding(.bottom, 12)
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
                // 只有"其它一级任务"拖过来才意味着能更换主线
                enabled: { store.canBecomeMain($0.id, on: day) }
            )
            if let goal = mainGoal {
                draggableCard(goal, at: 0, in: [goal]) {
                    TaskRowView(task: goal, level: 1, isMain: true, showsRoleGlyph: false)
                    if !collapseCards {
                        TaskSubtreeView(parentId: goal.id, level: 2, showsRails: false, showsRoleGlyph: false)
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
                        .font(Theme.sans(Theme.metaSize))
                        .foregroundStyle(Theme.ink3)
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
                // 只有"当前主线"拖过来才意味着可以降为支线
                enabled: { store.canBecomeBranch($0.id, on: day) }
            )
            VStack(spacing: 9) {
                ForEach(Array(branches.enumerated()), id: \.element.id) { index, task in
                    draggableCard(task, at: index, in: branches) {
                        TaskRowView(task: task, level: 1, showsRoleGlyph: false)
                        if !collapseCards {
                            TaskSubtreeView(parentId: task.id, level: 2, showsRails: false, showsRoleGlyph: false)
                        }
                    }
                }
            }
            .coordinateSpace(name: "branchList")
            .onPreferenceChange(CardFramePreference.self) { frames in
                guard drag.draggingId == nil || Date() < frameCaptureUntil else { return }
                // 只在真的变了才写状态
                if frames != liveFrames { liveFrames = frames }
            }
            .overlay(alignment: .topLeading) {
                // 拖动时的落点提示：在插入位置画一条横贯整栏的线
                if let insertAt = drag.insertIndex, !branches.isEmpty {
                    BranchInsertionLine(
                        index: insertAt,
                        frames: frozenFrames,
                        ids: branches.map(\.id),
                        spacing: 9
                    )
                }
            }
            .onDrop(of: [UTType.text], delegate: BranchListDropDelegate(
                store: store,
                drag: drag,
                ids: { branches.map(\.id) },
                frames: { frozenFrames.isEmpty ? liveFrames : frozenFrames }
            ))
            // 支线的输入行也是一张（空白）卡片：形状与其它卡片一致，填进去就是新卡片
            taskCard {
                writingLine(
                    text: $branchDraft,
                    placeholder: "添加一件次要的事",
                    prominent: false,
                    icon: "plus"
                ) {
                    store.addTopLevel(branchDraft, on: day)
                    branchDraft = ""
                }
                .padding(.horizontal, -12)
                .padding(.vertical, -8)
            }
            .padding(.top, 9)
        }
    }

    @ViewBuilder
    private var doneSection: some View {
        // 完成栏只在真的有一棵完成树时出现：
        // 挂在别人下面的已完成子步骤已经显示在各自主线 / 支线卡片里，不算进这一栏。
        if !finished.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                sectionHeader(
                    "今日完成",
                    hint: "拖到这里 = 直接完成",
                    targeted: false,
                    binding: nil,
                    action: { store.complete($0) }
                )
                VStack(spacing: 9) {
                    ForEach(finished) { task in
                        taskCard {
                            TaskRowView(task: task, level: 1, readOnly: true, showsRevert: true, showsRoleGlyph: false)
                            if !collapseCards {
                                TaskSubtreeView(parentId: task.id, level: 2, readOnly: true, showsRevert: true, showsRails: false, showsRoleGlyph: false)
                            }
                        }
                    }
                }
            }
            .padding(.bottom, 8)
        }
    }

    /// 收集卡片在支线栏坐标系里的位置。
struct CardFramePreference: PreferenceKey {
    static let defaultValue: [UUID: CGRect] = [:]
    static func reduce(value: inout [UUID: CGRect], nextValue: () -> [UUID: CGRect]) {
        value.merge(nextValue()) { _, new in new }
    }
}

/// 整栏投放：用**冻结的卡片坐标**算插入位置，落在卡片之间、卡片下方或卡片上都有效。
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

    /// 只有拖动**一级卡片**时这一栏才参与（拖动二级及以下不在这里做任何事）。
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
        if drag.insertIndex != next { drag.insertIndex = next }   // 值没变就不要发通知
        return DropProposal(operation: .move)
    }

    func dropExited(info: DropInfo) { drag.insertIndex = nil }

    func performDrop(info: DropInfo) -> Bool {
        guard let draggingId = draggedRoot() else {
            // 不是一级卡片：不在这里换位，但这一次拖动同样要收尾
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
            .frame(height: 2)
            .offset(y: y)
            .allowsHitTesting(false)
    }
}

/// 空白投放区：把任务拖到这里，它就变成顶层任务。
    private var rootDropZone: some View {
        Color.clear
            .frame(height: 16)
            .contentShape(Rectangle())
            .onDrop(of: [UTType.text], delegate: RootDropDelegate(store: store, drag: drag))
    }

    /// 可整卡拖动的一级任务：按住卡片的空白处或标题就能提起，
    /// 拖到别的卡片上时，那一侧的卡片会自动让出位置（收集类 App 的换位手感）。
    private func draggableCard<Content: View>(
        _ root: Task,
        at index: Int,
        in list: [Task],
        @ViewBuilder content: () -> Content
    ) -> some View {
        taskCard(content: content)
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
            // 只有"真的有落点"（整栏给了插入位，或某一行被指到）时才把源卡片藏起来，
            // 这时让位的卡片正好填进它的空位；没有落点时它必须还在，否则看起来像消失。
            .opacity(drag.draggingId == root.id && hasActiveTarget ? 0 : 1)
            .animation(listAnimation, value: drag.insertIndex)
            .onDrag {
                // 拖动开始：先落下正在编辑的内容，再冻结所有卡片位置
                session.finishByClickingAway(store: store)
                drag.end()
                drag.draggingId = root.id
                frozenFrames = liveFrames
                frameCaptureUntil = Date().addingTimeInterval(0.6)
                return NSItemProvider(object: root.id.uuidString as NSString)
            }
    }

    /// 拖动一级卡片时：所有卡片收起，只留一级标题，换位变成纯标题列表的操作。
    private var collapseCards: Bool {
        guard let id = drag.draggingId, let dragged = store.task(id) else { return false }
        return dragged.parentId == nil
    }

    /// 当前是否已经指到了某个有效落点。
    private var hasActiveTarget: Bool {
        drag.insertIndex != nil || drag.target != nil
    }

    /// 让位：把被拖卡片该让出的位置空出来（纯视觉，落点用的是冻结坐标，不会来回抖）。
    private func shift(for task: Task, at index: Int, in list: [Task]) -> CGFloat {
        guard let draggedId = drag.draggingId,
              draggedId != task.id,
              let insertAt = drag.insertIndex,
              let draggedIndex = list.firstIndex(where: { $0.id == draggedId })
        else { return 0 }

        let gap = (cardHeights[draggedId] ?? 0) + 9
        if draggedIndex < insertAt {
            return (index > draggedIndex && index < insertAt) ? -gap : 0
        }
        return (index >= insertAt && index < draggedIndex) ? gap : 0
    }

    /// 一个一级任务连同它的整棵子树 = 一张卡片。
    private func taskCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            content()
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Theme.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Theme.hairline, lineWidth: 1)
        )
        
    }

    /// 书写线：主线栏是纸色块 + 虚线；支线栏是一条安静的输入行。
    private func writingLine(
        text: Binding<String>,
        placeholder: String,
        prominent: Bool,
        icon: String,
        commit: @escaping () -> Void
    ) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: prominent ? 13 : 11, weight: .medium))
                .foregroundStyle(prominent ? Theme.accent : Theme.faint)
                .frame(width: 16)
            TextField(placeholder, text: text)
                .textFieldStyle(.plain)
                .font(Theme.sans(prominent ? Theme.inputSize + 1.5 : Theme.inputSize))
                .foregroundStyle(Theme.ink)
                .onSubmit(commit)
            if !text.wrappedValue.isEmpty {
                Button(action: commit) {
                    Text("写下来")
                        .font(Theme.sans(Theme.controlSize, .medium))
                        .foregroundStyle(Theme.accentInk)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, prominent ? 15 : 8)
        .background(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(prominent ? Theme.surfaceAlt : Color.clear)
        )
    }
}
