import SwiftUI
import UniformTypeIdentifiers
import Core

/// 行内拖拽代理：**行的左半边 = 同级，右半边 = 衔接（成为它的子步骤）**。
/// 左半边再看纵向：上半排在它前面，下半排在它后面。
struct RowDropDelegate: DropDelegate {
    let store: TaskStore
    let drag: DragController
    let targetId: UUID
    let rowHeight: CGFloat
    let rowWidth: CGFloat
    let level: Int

    /// 行的右半边＝衔接（成为子级）；
    /// 行的左半边再分上下：**左上半＝同级并排在它前面，左下半＝同级并排在它后面**。
    private func zone(for location: CGPoint) -> DropZone {
        if rowWidth > 0, location.x > rowWidth * 0.5 {
            return .nest
        }
        return location.y < rowHeight / 2 ? .before : .after
    }

    /// 这一次拖的是不是"整张一级卡片"。
    private var isCardDrag: Bool {
        guard let id = drag.draggingId, let dragged = store.task(id) else { return false }
        return dragged.parentId == nil
    }

    private func update(_ info: DropInfo) {
        guard let draggingId = drag.draggingId, draggingId != targetId else { return }
        let next = drag.target
        let zone = zone(for: info.location)
        if next?.targetId != targetId || next?.zone != zone {
            drag.target = DragState(draggedId: draggingId, targetId: targetId, zone: zone)
        }
    }

    func dropEntered(info: DropInfo) {
        if level == 1 { drag.insertIndex = nil }
        update(info)
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        // 指针已经在一级行上时，位置由这一行的左右高亮表达，
        // 不做整栏让位，避免"让位改变落点、落点又改变让位"的抖动。
        if level == 1 { drag.insertIndex = nil }
        update(info)
        return DropProposal(operation: .move)
    }

    func dropExited(info: DropInfo) {
        if drag.target?.targetId == targetId { drag.target = nil }
    }

    func performDrop(info: DropInfo) -> Bool {
        guard let draggingId = drag.draggingId else { return false }

        // 拖的是整张卡片、而这一行是二级及以下：不在这里"接进去"，
        // 而是按位置换位（卡片的下半部分全是子步骤行，否则会以为换位失败）。
        if isCardDrag, level >= 2 {
            let after = zone(for: info.location) == .after
            let index = store.branchInsertIndex(containing: targetId, after: after)
            drag.end()
            store.moveRootToBranchIndex(draggingId, index)
            return true
        }

        if draggingId == targetId {
            // 落在自己这一行上：这一放不改变任何东西，但必须把拖动状态收干净
            drag.end()
            return true
        }
        let target = zone(for: info.location)
        drag.target = nil
        drag.draggingId = nil

        // 落到当天主线那一行的左半边：把它设为主线（主线栏里本来也没有"同级"可言）
        if level == 1, target != .nest,
           let dragged = store.task(draggingId), dragged.parentId == nil,
           store.mainGoal(on: dragged.day)?.id == targetId {
            store.setMain(draggingId)
            return true
        }
        store.performDrop(draggedId: draggingId, targetId: targetId, zone: target)
        return true
    }
}

/// 拖到栏内空白：升级为顶层任务。
struct RootDropDelegate: DropDelegate {
    let store: TaskStore
    let drag: DragController

    func dropUpdated(info: DropInfo) -> DropProposal? { DropProposal(operation: .move) }

    func performDrop(info: DropInfo) -> Bool {
        guard let draggingId = drag.draggingId else { return false }
        drag.draggingId = nil
        drag.target = nil
        store.moveToTopLevel(draggingId)
        return true
    }
}

/// 需要时才挂上投放能力。
struct OptionalDropTarget: ViewModifier {
    let store: TaskStore
    let drag: DragController
    let binding: Binding<Bool>?
    let action: ((UUID) -> Void)?
    var enabled: ((Task) -> Bool)?

    func body(content: Content) -> some View {
        if let binding, let action {
            content.onDrop(
                of: [UTType.text],
                delegate: HighlightDropDelegate(
                    store: store,
                    drag: drag,
                    isTargeted: binding,
                    action: action,
                    enabled: enabled ?? { _ in true }
                )
            )
        } else {
            content
        }
    }
}

/// 把拖进来的任务执行一个动作，并支持投放区高亮。
struct HighlightDropDelegate: DropDelegate {
    let store: TaskStore
    let drag: DragController
    @Binding var isTargeted: Bool
    let action: (UUID) -> Void
    /// 只有"这一次拖动真的会改变什么"时才算有效落点：否则不亮、也不响应。
    var enabled: (Task) -> Bool = { _ in true }

    private func validDrag() -> UUID? {
        guard let id = drag.draggingId, let task = store.task(id), enabled(task) else { return nil }
        return id
    }

    func dropEntered(info: DropInfo) { isTargeted = validDrag() != nil }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        let ok = validDrag() != nil
        isTargeted = ok
        return DropProposal(operation: ok ? .move : .cancel)
    }

    func dropExited(info: DropInfo) { isTargeted = false }

    func performDrop(info: DropInfo) -> Bool {
        isTargeted = false
        guard let draggingId = validDrag() else {
            drag.end()
            return false
        }
        drag.draggingId = nil
        drag.target = nil
        action(draggingId)
        return true
    }
}

/// 任务行：`[缩进树线][角色图标][完成圆环] 标题 [拖动把手][＋同级][＋下级][删除]`。
/// 编辑文字与新建任务共用同一个输入会话，外观与按键行为完全一致。
public struct TaskRowView: View {
    @EnvironmentObject var store: TaskStore
    @EnvironmentObject var drag: DragController
    @EnvironmentObject private var session: InputSession

    public let task: Task
    public let level: Int
    public let showsPath: Bool
    public let isMain: Bool
    public let readOnly: Bool
    public let showsRevert: Bool
    /// 卡片内部不画左侧树线（整体性由卡片表达）。
    public let showsRails: Bool
    /// 角色小图标（◆ 主线 / ● 支线 / □ ▪ 层级）只在日历里用，日页不需要。
    public let showsRoleGlyph: Bool
    /// 是否画在主题卡片上：卡片上的行要用卡片墨色，而不是页面墨色。
    public let onCard: Bool
    /// 页边编号：任务树的地址（01 / 01.1 / B-01），排在行首的固定列里。
    public let showsFolio: Bool
    /// 是否画完成勾选框（夜之城的主线是标题，不配勾选框）。
    public let showsRing: Bool
    /// 主线的完成动作（夜之城：不配勾选框，用行尾按钮完成）。
    public let mainCompleteAction: (() -> Void)?

    @State private var hovering = false
    @State private var rowWidth: CGFloat = 0
    @State private var showStamp = false
    @FocusState private var inputFocused: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(
        task: Task,
        level: Int,
        showsPath: Bool = false,
        isMain: Bool = false,
        readOnly: Bool = false,
        showsRevert: Bool = false,
        showsRails: Bool = true,
        showsRoleGlyph: Bool = true,
        onCard: Bool = false,
        showsFolio: Bool = false,
        showsRing: Bool = true,
        mainCompleteAction: (() -> Void)? = nil
    ) {
        self.task = task
        self.level = level
        self.showsPath = showsPath
        self.isMain = isMain
        self.readOnly = readOnly
        self.showsRevert = showsRevert
        self.showsRails = showsRails
        self.showsRoleGlyph = showsRoleGlyph
        self.onCard = onCard
        self.showsFolio = showsFolio
        self.showsRing = showsRing
        self.mainCompleteAction = mainCompleteAction
    }

    private var ci: Color { onCard ? Theme.cardInk : Theme.ink }
    private var ci2: Color { onCard ? Theme.cardInk.opacity(0.68) : Theme.ink2 }
    private var ci3: Color { onCard ? Theme.cardInk.opacity(0.46) : Theme.ink3 }
    private var cdone: Color { onCard ? Theme.cardInk.opacity(0.45) : Theme.doneInk }
    private var crule: Color { onCard ? Theme.cardInk.opacity(0.20) : Theme.hairline }
    /// 投放区与焦点底色：一律用主题强调色的浅底（日课＝朱砂淡、夜城＝黄淡）。
    private var csoft: Color { Theme.accentSoft }
    private var caccent: Color { onCard ? Theme.cardInk : Theme.accent }

    private var spring: Animation? { reduceMotion ? nil : Motion.spring }
    private var quick: Animation? { reduceMotion ? nil : Motion.quick }
    private var rowHeight: CGFloat { Theme.rowHeight(level, isMain: isMain) }
    /// 页边编号的固定列宽：空编号也占位，整树的编号才对得齐。
    private var folioColumn: CGFloat { 40 * Theme.fontScale }

    /// 一级任务就是一张卡片，"再加一条同级"＝在「今日支线」里加一张卡片，
    /// 所以一级行不给「＋同级」按钮；但键盘连续创建仍支持同级（回车）与下级（Tab）。
    private var showsSiblingButton: Bool { level != 1 }

    /// 连续创建的默认续写模式：回车＝同级（一级的同级就是新支线），Tab 改下级。
    private var continueMode: InputSession.Mode { .sibling }

    private var isEditingThis: Bool { session.isEditing && session.targetId == task.id }
    private var isCreatingUnderThis: Bool { session.isCreating && session.targetId == task.id }
    /// glitch 套印只给夜之城的主线标题，且未完成时才亮。
    private var glitch: Bool { Theme.isNight && isMain && level == 1 && !task.done }
    /// 夜之城：支线一级行的勾选框是菱形（Side Job 的角色语言），其余照旧。
    private var useDiamondRing: Bool { Theme.isNight && level == 1 && !isMain }

    private var dropZone: DropZone? {
        guard let state = drag.target, state.targetId == task.id, state.draggedId != task.id else { return nil }
        return state.zone
    }

    public var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                if showsRails {
                    TreeRails(level: level, color: onCard ? Theme.cardInk.opacity(0.18) : nil)
                } else {
                    Spacer().frame(width: CGFloat(Theme.railCount(level)) * Theme.indentStep)
                }
                HStack(alignment: .center, spacing: 8) {
                    if showsFolio {
                        // 编号是行内元素（跟缩进走，原型语义）：编号 → 勾选框 → 文字
                        Text(store.folio(of: task))
                            .font(Theme.mono(Theme.folioSize))
                            .foregroundStyle(ci3)
                            .frame(width: folioColumn, alignment: .trailing)
                            .help("页边编号：任务的地址")
                    }
                    if showsRoleGlyph {
                        RoleGlyph(isMain: task.isMain, level: level)
                    }

                    if showsRing {
                        RingView(level: level, done: task.done, diamond: useDiamondRing, tint: onCard ? Theme.cardInk : nil) {
                            if task.done {
                                store.revert(task.id)
                            } else if readOnly || reduceMotion {
                                store.complete(task.id)
                                Feedback.complete()
                            } else {
                                showCompletionStamp()
                                Feedback.complete()
                                // 先看到章，再让这一行移走
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.32) {
                                    store.complete(task.id)
                                }
                            }
                        }
                        .scaleEffect(task.done ? 1.08 : 1)
                        .animation(reduceMotion ? nil : Motion.ring, value: task.done)
                    }

                    titleArea

                    Spacer(minLength: 6)

                    if let complete = mainCompleteAction, !task.done {
                        Button(action: complete) {
                            HStack(spacing: 5) {
                                Image(systemName: "checkmark").font(.system(size: 9, weight: .bold))
                                Text("完成").font(Theme.sans(11, .semibold)).tracking(1)
                            }
                            .foregroundStyle(hovering ? Theme.fillInk : Theme.accent)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(hovering ? Theme.accent : Color.clear)
                            .clipShape(CutCornerShape(radius: 4))
                            .overlay(CutCornerShape(radius: 4).stroke(Theme.accent.opacity(0.7), lineWidth: 1))
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .help("完成今天的主线")
                    }

                    if !readOnly {
                        rowActions
                    }
                }
            }
            .frame(height: rowHeight)
            .overlay(alignment: .trailing) {
                if showStamp {
                    CompletionStamp(style: Theme.cardStyle, date: task.day.replacingOccurrences(of: "-", with: "."))
                        .padding(.trailing, onCard ? 34 : 18)
                        .transition(.scale(scale: 1.25).combined(with: .opacity))
                        .allowsHitTesting(false)
                }
            }
            .animation(reduceMotion ? nil : Motion.ring, value: showStamp)
            .contentShape(Rectangle())
            .contextMenu {
                if showsRevert {
                    Button("恢复这条及其子步骤") { store.revertSubtree(task.id) }
                }
            }
            .onTapGesture { beginEdit() }
            .help(readOnly ? "" : "点击这一行的任意位置可以改文字")
            .onHover { hovering = $0 }
            .animation(quick, value: hovering)
            .background(
                GeometryReader { geo in
                    Color.clear
                        .onAppear { rowWidth = geo.size.width }
                        .onChange(of: geo.size.width) { _, newWidth in rowWidth = newWidth }
                }
            )
            .background(rowBackground)
            .animation(quick, value: dropZone)
            .onDrag {
                // 编辑（高亮）与拖动互斥：一开始拖，就先把正在写的内容落下并结束
                session.finishByClickingAway(store: store)
                drag.draggingId = task.id
                return NSItemProvider(object: task.id.uuidString as NSString)
            }
            .onDrop(of: [UTType.text], delegate: RowDropDelegate(store: store, drag: drag, targetId: task.id, rowHeight: rowHeight, rowWidth: rowWidth, level: level))

            if isCreatingUnderThis {
                addInput(session.createMode)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(spring, value: session.targetId)
        .animation(spring, value: session.isEditing)
    }

    // MARK: 视觉

    /// 卡片之间的顺序提示：整行一条细线（一级任务用）。
    private var insertionLine: some View {
        Rectangle().fill(caccent).frame(height: 2)
    }

    /// 拖动经过时把投放区画出来：竖线分左右（左＝同级，右＝衔接），
    /// 横线再把左边分成上下（上＝排在它前面，下＝排在它后面）。
    @ViewBuilder
    private var rowBackground: some View {
        if let zone = dropZone {
            GeometryReader { geo in
                let w = geo.size.width
                let h = geo.size.height
                ZStack(alignment: .topLeading) {
                    Color.clear
                    switch zone {
                    case .nest:
                        Rectangle()
                            .fill(csoft)
                            .frame(width: w * 0.5, height: h)
                            .offset(x: w * 0.5)
                    case .before:
                        // 左上半＝同级，排在它前面
                        Rectangle()
                            .fill(csoft)
                            .frame(width: w * 0.5, height: h * 0.5)
                    case .after:
                        // 左下半＝同级，排在它后面
                        Rectangle()
                            .fill(csoft)
                            .frame(width: w * 0.5, height: h * 0.5)
                            .offset(y: h * 0.5)
                    }
                }
                .overlay(alignment: .center) {
                    Rectangle().fill(crule).frame(width: 1)
                }
                .overlay(alignment: .leading) {
                    // 横线把左半边分成上下：一级卡片与子步骤用同一套
                    Rectangle()
                        .fill(crule)
                        .frame(width: w * 0.5, height: 1)
                        .offset(y: h * 0.5 - 0.5)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .strokeBorder(caccent.opacity(0.6), lineWidth: 1.2)
            )
            .allowsHitTesting(false)
        } else if store.focusedTaskId == task.id {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(csoft)
                .overlay(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .strokeBorder(caccent.opacity(0.7), lineWidth: 1.2)
                )
        } else {
            Color.clear
        }
    }

    // MARK: 标题区（点击进入编辑；编辑与新建同款高亮、同款按键）

    @ViewBuilder
    private var titleArea: some View {
        VStack(alignment: .leading, spacing: 1) {
            if isEditingThis {
                HStack(spacing: 8) {
                    TextField("", text: $session.text)
                        .textFieldStyle(.plain)
                        .font(Theme.titleFont(level, isMain: isMain))
                        .foregroundStyle(ci)
                        .focused($inputFocused)
                        .onAppear { focusSoon() }
                        .onSubmit { session.commit(store: store, editContinue: continueMode) }
                        .onExitCommand { session.close() }
                        .onKeyPress(.tab) {
                            session.commit(store: store, editContinue: .child)
                            return .handled
                        }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous).fill(csoft)
                )
            } else {
                Text(task.title)
                    .font(Theme.titleFont(level, isMain: isMain))
                    .foregroundStyle(task.done ? cdone : (onCard ? ci : Theme.titleColor(level, isMain: isMain)))
                    .strikethrough(task.done, color: cdone)
                    .lineLimit(1)
                    .animation(spring, value: task.done)
                    // 夜之城：只有主线标题带 1px 青/洋红套印（glitch）
                    .shadow(color: glitch ? Theme.signal.opacity(0.55) : .clear, radius: 0.9, x: 0.9, y: 0)
                    .shadow(color: glitch ? Theme.warn.opacity(0.5) : .clear, radius: 0.9, x: -0.9, y: 0)
                    .overlay(alignment: .bottom) {
                        if hovering && !readOnly {
                            Rectangle().fill(Theme.faint.opacity(0.6)).frame(height: 1)
                        }
                    }
                    .help(readOnly ? "" : "点击这一行可以改文字；回车继续往下写")
            }

            if showsPath {
                Text(store.pathText(of: task))
                    .font(Theme.sans(10.5))
                    .foregroundStyle(Theme.faint)
                    .lineLimit(1)
            }
        }
    }

    /// 整行点击进入编辑（按钮、圆环、把手的点击优先于这里）。
    private func beginEdit() {
        guard !readOnly, !isEditingThis else { return }
        // 拖动进行中不会收到点击；能收到点击说明上一次拖动已经结束（含被取消的情况），
        // 这里把可能残留的状态清掉，避免"拖过一次以后点不开编辑"。
        if drag.draggingId != nil {
            drag.draggingId = nil
            drag.target = nil
        }
        session.startEdit(store: store, at: task.id, currentTitle: task.title)
    }

    private func focusSoon() {
        DispatchQueue.main.async { inputFocused = true }
    }

    /// 完成时盖一枚当前主题的章，短暂停留后消失。
    private func showCompletionStamp() {
        showStamp = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
            showStamp = false
        }
    }

    // MARK: 行内动作

    private var rowActions: some View {
        HStack(spacing: 2) {
            Image(systemName: "line.3.horizontal")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(hovering ? ci3 : Theme.faint.opacity(0.5))
                .frame(width: 18, height: 18)
                .help("按住拖动：拖到行的上下缘调整顺序，拖到行中间变成子步骤，拖到日历某天则移到那天")

            Group {
                if hovering {
                    if showsSiblingButton {
                        addButton("同级", mode: .sibling)
                    }
                    addButton("下级", mode: .child)
                    IconButton(systemName: "trash", help: "删除这件事") {
                        store.delete(task.id)
                    }
                } else {
                    Button {
                        session.startCreate(store: store, at: task.id, mode: .child)
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(Theme.faint)
                            .frame(width: 20, height: 18)
                    }
                    .buttonStyle(.plain)
                    .help("新建任务：回车继续同级，Tab 改成下级")
                }
            }
            .transition(.opacity)
        }
        .animation(quick, value: hovering)
    }

    private func addButton(_ title: String, mode: InputSession.Mode) -> some View {
        Button {
            session.startCreate(store: store, at: task.id, mode: mode)
        } label: {
            HStack(spacing: 2) {
                Image(systemName: "plus").font(.system(size: 9, weight: .semibold))
                Text(title).font(Theme.sans(10.5, .medium))
            }
            .foregroundStyle(ci2)
            .padding(.horizontal, 5)
            .padding(.vertical, 3)
            .background(
                RoundedRectangle(cornerRadius: 5).fill(Theme.surfaceAlt)
            )
        }
        .buttonStyle(.plain)
        .help(mode == .sibling ? "新建一个和它同级的任务" : "新建一个它的子任务")
    }

    /// 新建行：与编辑同款高亮；回车继续同级，Tab 改成下级（按键说明放在设置的「使用说明」里）。
    private func addInput(_ mode: InputSession.Mode) -> some View {
        let extra = mode == .child ? Theme.indentStep : 0
        let markerWidth: CGFloat = 14 + 8 + Theme.ringSize(level) + 8
        return HStack(spacing: 8) {
            Spacer().frame(width: CGFloat(Theme.railCount(level)) * Theme.indentStep + extra)
            Image(systemName: "arrow.turn.down.right")
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(caccent)
                .frame(width: markerWidth)
            TextField(placeholder(mode), text: $session.text)
                .textFieldStyle(.plain)
                .font(Theme.sans(13))
                .focused($inputFocused)
                .onAppear { focusSoon() }
                .onSubmit { session.commit(store: store, editContinue: continueMode) }
                .onExitCommand { session.close() }
                .onKeyPress(.tab) {
                    session.toggleMode()
                    return .handled
                }
        }
        .padding(.vertical, 6)
        .padding(.trailing, 8)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(csoft)
        )
        .padding(.vertical, 2)
    }

    private func placeholder(_ mode: InputSession.Mode) -> String {
        mode == .sibling ? "新任务" : "新任务（下级）"
    }

}

/// 递归渲染子树。
public struct TaskSubtreeView: View {
    @EnvironmentObject var store: TaskStore

    public let parentId: UUID
    public let level: Int
    public let readOnly: Bool
    public let showsRevert: Bool
    public let showsRails: Bool
    public let showsRoleGlyph: Bool
    public let onCard: Bool
    public let showsFolio: Bool

    public init(
        parentId: UUID,
        level: Int,
        readOnly: Bool = false,
        showsRevert: Bool = false,
        showsRails: Bool = true,
        showsRoleGlyph: Bool = true,
        onCard: Bool = false,
        showsFolio: Bool = false
    ) {
        self.parentId = parentId
        self.level = level
        self.readOnly = readOnly
        self.showsRevert = showsRevert
        self.showsRails = showsRails
        self.showsRoleGlyph = showsRoleGlyph
        self.onCard = onCard
        self.showsFolio = showsFolio
    }

    public var body: some View {
        ForEach(store.children(of: parentId)) { child in
            TaskRowView(
                task: child,
                level: level,
                readOnly: readOnly,
                showsRevert: showsRevert,
                showsRails: showsRails,
                showsRoleGlyph: showsRoleGlyph,
                onCard: onCard,
                showsFolio: showsFolio
            )
            TaskSubtreeView(
                parentId: child.id,
                level: level + 1,
                readOnly: readOnly,
                showsRevert: showsRevert,
                showsRails: showsRails,
                showsRoleGlyph: showsRoleGlyph,
                onCard: onCard,
                showsFolio: showsFolio
            )
        }
    }
}
