import Foundation
import Combine

public enum AppView: String, Equatable {
    case today, pool, done
}

public enum PoolRange: String, CaseIterable, Equatable {
    case week, month, all

    public var label: String {
        switch self {
        case .week: return "本周"
        case .month: return "本月"
        case .all: return "所有"
        }
    }

    /// 滚动天数上限；nil 表示不限。
    var maxDays: Int? {
        switch self {
        case .week: return 7
        case .month: return 30
        case .all: return nil
        }
    }
}

public enum DropZone: Equatable {
    case before, after, nest
}

public struct DragState: Equatable {
    public var draggedId: UUID
    public var targetId: UUID
    public var zone: DropZone

    public init(draggedId: UUID, targetId: UUID, zone: DropZone) {
        self.draggedId = draggedId
        self.targetId = targetId
        self.zone = zone
    }
}

/// 全部业务规则的实现：任务树、完成 / 忽略 / 撤销 / 重新执行、跨天、落盘。
public final class TaskStore: ObservableObject {

    // MARK: - 状态

    @Published public private(set) var tasks: [Task] = []
    @Published public private(set) var currentDay: String
    /// 日历中被选中的那一天（右侧日页显示的那天）。
    @Published public var selectedDay: String = ""
    @Published public var view: AppView = .today
    @Published public var range: PoolRange = .all
    @Published public var toast: String?
    @Published public var toastHasUndo: Bool = false
    /// 外观等偏好，随数据一起落盘。
    @Published public var settings: AppSettings = AppSettings()
    /// 从清单跳过来时，短暂高亮的那一条。
    @Published public var focusedTaskId: UUID?

    private var undoBuffer: [Task]?
    private var toastWorkItem: DispatchWorkItem?
    private var saveURL: URL?
    private var rolloverTimer: Timer?

    // MARK: - 初始化

    /// - Parameters:
    ///   - storeURL: 落盘位置；传 nil 表示只在内存中（自测用）。
    ///   - today: 覆盖「今天」的日期键（自测用）。
    public init(storeURL: URL?, today: String = DayKey.key()) {
        self.saveURL = storeURL
        self.currentDay = today
        if let url = storeURL, let data = try? Data(contentsOf: url) {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            if let decoded = try? decoder.decode(AppData.self, from: data) {
                self.tasks = decoded.tasks
                self.currentDay = decoded.currentDay
                self.settings = decoded.settings
            }
        }
        self.selectedDay = self.currentDay
    }

    public func selectDay(_ day: String) {
        selectedDay = day
    }

    public static func defaultStoreURL() -> URL? {
        let fm = FileManager.default
        guard let base = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return nil }
        let dir = base.appendingPathComponent("FU ToDo", isDirectory: true)
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent("data.json")

        // 从旧名字（一日一件）迁移一次：改名不该让用户丢掉记录
        let legacy = base.appendingPathComponent("一日一件", isDirectory: true)
            .appendingPathComponent("data.json")
        if !fm.fileExists(atPath: url.path), fm.fileExists(atPath: legacy.path) {
            try? fm.moveItem(at: legacy, to: url)
        }
        return url
    }

    // MARK: - 落盘

    public func save() {
        guard let url = saveURL else { return }
        let payload = AppData(currentDay: currentDay, tasks: tasks, settings: settings)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(payload) else { return }
        try? data.write(to: url, options: .atomic)
    }

    // MARK: - 设置

    public func updateSettings(_ transform: (inout AppSettings) -> Void) {
        var next = settings
        transform(&next)
        guard next != settings else { return }
        settings = next
        save()
    }

    // MARK: - 备份与数据位置

    public enum StoreError: LocalizedError {
        case badFile
        case emptyFile

        public var errorDescription: String? {
            switch self {
            case .badFile: return "这个文件不是「FU ToDo」的备份，或者已经损坏。"
            case .emptyFile: return "文件是空的。"
            }
        }
    }

    /// 当前数据文件位置。
    public var dataFileURL: URL? { saveURL }

    /// 导出备份：与内部数据文件同一种格式，方便直接查看。
    public func exportData() throws -> Data {
        let payload = AppData(currentDay: currentDay, tasks: tasks, settings: settings)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(payload)
    }

    /// 从备份导入：整体替换任务与设置。
    public func importData(_ data: Data) throws {
        guard !data.isEmpty else { throw StoreError.emptyFile }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let decoded = try? decoder.decode(AppData.self, from: data) else {
            throw StoreError.badFile
        }
        tasks = decoded.tasks
        currentDay = decoded.currentDay
        settings = decoded.settings
        selectedDay = decoded.currentDay
        undoBuffer = nil
        toast = nil
        save()
    }

    /// 清空所有任务（保留当日与外观设置）。
    public func clearAllTasks() {
        snapshotForUndo()
        tasks = []
        save()
        showToast("已清空所有数据", undoable: true)
    }

    // MARK: - 查询

    public func task(_ id: UUID) -> Task? {
        tasks.first { $0.id == id }
    }

    public func children(of parent: UUID?) -> [Task] {
        tasks.filter { $0.parentId == parent }.sorted { $0.order < $1.order }
    }

    public func roots() -> [Task] {
        children(of: nil)
    }

    public func level(of task: Task) -> Int {
        var level = 1
        var parent = task.parentId
        var guardCount = 0
        while let p = parent, guardCount < 32 {
            level += 1
            parent = self.task(p)?.parentId
            guardCount += 1
        }
        return level
    }

    /// 包含自身在内的整棵子树。
    public func subtree(_ id: UUID) -> [Task] {
        var out: [Task] = []
        var stack: [UUID] = [id]
        while let cur = stack.popLast() {
            guard let t = task(cur) else { continue }
            out.append(t)
            stack.append(contentsOf: children(of: cur).map(\.id))
        }
        return out
    }

    public func ancestors(of task: Task) -> [Task] {
        var out: [Task] = []
        var parent = task.parentId
        var guardCount = 0
        while let p = parent, guardCount < 32 {
            guard let t = self.task(p) else { break }
            out.append(t)
            parent = t.parentId
            guardCount += 1
        }
        return out
    }

    public func isDescendant(_ candidate: UUID, of ancestor: UUID) -> Bool {
        var parent = task(candidate)?.parentId
        var guardCount = 0
        while let p = parent, guardCount < 32 {
            if p == ancestor { return true }
            parent = task(p)?.parentId
            guardCount += 1
        }
        return false
    }

    public func pathText(of task: Task) -> String {
        ancestors(of: task).reversed().map(\.title).joined(separator: " › ")
    }

    /// 今日页：属于今天、未完成的顶层任务，连同整棵子树。
    public var todayRoots: [Task] {
        roots(of: currentDay)
    }

    /// 某一天的顶层任务（含已完成，用于日历格子与历史查看）。
    public func roots(of day: String) -> [Task] {
        roots().filter { $0.day == day && !$0.done }
    }

    /// 某一天的任务总数（含子步骤）。
    public func taskCount(on day: String) -> Int {
        tasks.filter { $0.day == day }.count
    }

    /// 某一天已完成的数量。
    public func doneCount(on day: String) -> Int {
        tasks.filter { $0.day == day && $0.done }.count
    }

    /// 未完成池：只列一级任务（未完成、在今天之前）。二三级跟着它的整棵树走，不单独列出。
    /// 范围一律以系统「今天」为基准往回数：本周 = 7 天内，本月 = 30 天内，所有 = 不限。
    /// 未来的任务不算「没做完」，只在日历上属于它的那一天出现。
    public func poolTasks() -> [Task] {
        tasks
            .filter { !$0.done && $0.parentId == nil }
            .filter { t in
                let age = DayKey.daysBetween(t.day, currentDay)
                guard age > 0 else { return false }
                guard let maxDays = range.maxDays else { return true }
                return age <= maxDays
            }
            .sorted { a, b in
                if a.day != b.day { return a.day > b.day }
                let ka = treeSortKey(a)
                let kb = treeSortKey(b)
                if ka != kb { return ka.lexicographicallyPrecedes(kb) }
                return a.createdAt < b.createdAt
            }
    }

    /// 从根到自身的顺序链，用于把子树排在一起（父任务在前，子步骤紧随其后）。
    private func treeSortKey(_ task: Task) -> [Int] {
        var chain: [Int] = []
        var current: Task? = task
        var guardCount = 0
        while let node = current, guardCount < 32 {
            chain.insert(node.order, at: 0)
            guardCount += 1
            if let parentId = node.parentId {
                current = self.task(parentId)
            } else {
                current = nil
            }
        }
        return chain
    }

    public var poolCount: Int {
        poolTasks().count
    }

    /// 全部已结束任务（不限范围），按任务所属日期降序。
    public var doneTasks: [Task] {
        tasks.filter(\.done).sorted { a, b in
            if a.day != b.day { return a.day > b.day }
            return (a.endedAt ?? .distantPast) > (b.endedAt ?? .distantPast)
        }
    }

    /// 某一天已完成的任务（用于日页的「今日完成」栏）。
    /// 上级还没完成的子步骤不在这里重复列出——它在树里已经能看到。
    /// 今天完成的事：只列**顶层**已完成任务——每条代表一整棵完成树。
    /// 挂在别人下面的已完成子步骤已经在它所属的卡片里显示，不在这里重复出现，
    /// 否则同一棵树会被"裁成"多张卡片（顶层一张 + 各子步骤各一张）。
    public func doneTasks(on day: String) -> [Task] {
        tasks
            .filter { $0.done && $0.day == day && $0.parentId == nil }
            .sorted { ($0.endedAt ?? .distantPast) > ($1.endedAt ?? .distantPast) }
    }

    /// 某一天未完成的顶层任务。
    public func undoneRoots(of day: String) -> [Task] {
        roots(of: day)
    }

    /// 当天的顶层任务，**主线永远排在最前**，其余按顺序。
    /// 日历小格与任何根任务列表都用这个，保证和右栏「今日主线 / 今日支线」的顺序一致。
    public func orderedRoots(of day: String) -> [Task] {
        let list = roots(of: day)
        guard let main = list.first(where: { $0.isMain }) else { return list }
        return [main] + list.filter { !$0.isMain }
    }

    public func ageText(of task: Task) -> String {
        let days = DayKey.daysBetween(task.day, currentDay)
        if days <= 0 { return "今天" }
        if days == 1 { return "昨天" }
        return "\(days) 天前"
    }

    private func nextOrder(parent: UUID?) -> Int {
        (children(of: parent).map(\.order).max() ?? -1) + 1
    }

    // MARK: - 主线与支线

    /// 当天的主线：显式标记、顶层、未完成。
    public func mainGoal(on day: String? = nil) -> Task? {
        let target = day ?? currentDay
        return tasks.first { $0.day == target && $0.isMain && !$0.done && $0.parentId == nil }
    }

    /// 跳到某条任务所在的那一天，并短暂高亮它，方便看清上下文。
    public func jumpTo(_ id: UUID) {
        guard let target = task(id) else { return }
        selectedDay = target.day
        focusedTaskId = id
        let item = DispatchWorkItem { [weak self] in self?.focusedTaskId = nil }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.2, execute: item)
    }

    /// 当天的支线：除主线之外的顶层任务。
    public func branches(on day: String? = nil) -> [Task] {
        let target = day ?? currentDay
        return roots(of: target).filter { !$0.isMain }
    }

    /// 当天是否已经有进行中的主线（已完成的主线不算，需要重新指定）。
    public func hasMain(on day: String) -> Bool {
        tasks.contains { $0.day == day && $0.isMain && !$0.done && $0.parentId == nil }
    }

    /// 把某条任务设为当天主线；同一天只保留一个，且主线必须是顶层。
    public func setMain(_ id: UUID) {
        guard let target = task(id) else { return }
        snapshotForUndo()
        for i in tasks.indices where tasks[i].day == target.day { tasks[i].isMain = false }
        if let idx = tasks.firstIndex(where: { $0.id == id }) {
            tasks[idx].isMain = true
            tasks[idx].parentId = nil
            tasks[idx].order = -1
        }
        normalizeOrders(day: target.day)
        save()
        showToast("已设为当天主线", undoable: true)
    }

    /// 取消主线（一天可以没有主线）。
    public func unsetMain(_ id: UUID) {
        guard let target = task(id), target.isMain else { return }
        snapshotForUndo()
        if let idx = tasks.firstIndex(where: { $0.id == id }) {
            tasks[idx].isMain = false
            tasks[idx].order = nextOrder(parent: nil)
        }
        save()
        showToast("已取消主线", undoable: true)
    }

    /// 同级插入：在锚点任务后面插入一条同层任务。
    @discardableResult
    public func addSibling(after id: UUID, title: String) -> Task? {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let anchor = task(id) else { return nil }
        let parent = anchor.parentId
        var siblings = children(of: parent).filter { $0.id != anchor.id }
        let insertAt = min((children(of: parent).firstIndex(where: { $0.id == anchor.id }) ?? -1) + 1, siblings.count)
        let created = Task(title: trimmed, parentId: parent, order: insertAt, day: anchor.day, isMain: false)
        tasks.append(created)
        siblings.insert(created, at: insertAt)
        applySiblingOrder(siblings, parent: parent)
        save()
        return created
    }

    /// 跨天移动：整棵子树移到目标日期。带父任务的任务会被提到目标日的顶层。
    public func moveToDay(_ id: UUID, day: String, asMain: Bool) {
        guard let source = task(id), source.day != day else { return }
        let affected = Set(subtree(id).map(\.id))
        // 必须在搬之前判断：搬完再算的话，被搬过去的任务自己会被算成「目标日已有主线」
        let targetHasMain = tasks.contains {
            $0.day == day && $0.isMain && !$0.done && $0.parentId == nil && !affected.contains($0.id)
        }
        snapshotForUndo()
        for i in tasks.indices where affected.contains(tasks[i].id) {
            tasks[i].day = day
        }
        if let idx = tasks.firstIndex(where: { $0.id == id }) {
            let becomeMain = asMain && !targetHasMain
            if becomeMain {
                for i in tasks.indices where tasks[i].day == day && !affected.contains(tasks[i].id) {
                    tasks[i].isMain = false
                }
            }
            tasks[idx].parentId = nil
            // 成为那天主线时排到最前，否则排到最后
            tasks[idx].order = becomeMain ? -1 : nextOrder(parent: nil)
            tasks[idx].isMain = becomeMain
        }
        applySiblingOrder(children(of: nil).filter { $0.day == day }, parent: nil)
        save()
        showToast("已移到 \(DayKey.shortLabel(for: day))", undoable: true)
    }

    /// 拖到日历某一天：整棵子树一起搬，不再询问。
    /// 目标日已有主线 → 落为支线；目标日没有主线 → 直接成为那天的主线。
    public func requestMoveToDay(_ id: UUID, day: String) {
        guard let source = task(id), source.day != day else { return }
        moveToDay(id, day: day, asMain: !hasMain(on: day))
    }

    /// 移动之后重新定角色：顶层看当天有没有主线，子级一律不是主线。
    private func assignRoleAfterMove(_ id: UUID, parent: UUID?) {
        guard let idx = tasks.firstIndex(where: { $0.id == id }) else { return }
        // 顶层重排不改角色；一旦降为子级，主线身份解除。
        if parent != nil {
            tasks[idx].isMain = false
        }
    }

    private func normalizeOrders(day: String) {
        applySiblingOrder(children(of: nil).filter { $0.day == day }, parent: nil)
    }

    // MARK: - 动作

    private func snapshotForUndo() {
        undoBuffer = tasks
    }

    private func showToast(_ text: String, undoable: Bool) {
        toast = text
        toastHasUndo = undoable
        toastWorkItem?.cancel()
        let item = DispatchWorkItem { [weak self] in
            self?.toast = nil
            self?.toastHasUndo = false
            self?.undoBuffer = nil
        }
        toastWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 6, execute: item)
    }

    public func undo() {
        guard let buffer = undoBuffer else { return }
        tasks = buffer
        undoBuffer = nil
        toastWorkItem?.cancel()
        toast = "已撤销"
        toastHasUndo = false
        save()
        let item = DispatchWorkItem { [weak self] in self?.toast = nil }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5, execute: item)
    }

    private func setDone(_ id: UUID, kind: DoneKind) {
        guard let target = task(id) else { return }
        snapshotForUndo()
        let affected = Set(subtree(id).map(\.id))
        let now = Date()
        for i in tasks.indices where affected.contains(tasks[i].id) {
            tasks[i].done = true
            tasks[i].doneKind = kind
            tasks[i].endedAt = now
        }
        let extra = affected.count - 1
        let word = kind == .ignored ? "已结束" : "已完成"
        _ = target
        showToast(extra > 0 ? "\(word) · 连带 \(extra) 个子步骤" : word, undoable: true)
        save()
    }

    public func complete(_ id: UUID) { setDone(id, kind: .checked) }
    public func ignore(_ id: UUID) { setDone(id, kind: .ignored) }

    /// 恢复：只恢复这一条，以及它上面的那条「关联链」（上级），
    /// 不恢复它自己的子步骤，也不恢复上级的其他分支。
    public func revert(_ id: UUID) {
        guard let target = task(id) else { return }
        let chain = ancestors(of: target)
        snapshotForUndo()
        var affected = Set([id])
        for node in chain { affected.insert(node.id) }
        for i in tasks.indices where affected.contains(tasks[i].id) {
            tasks[i].done = false
            tasks[i].doneKind = nil
            tasks[i].endedAt = nil
        }
        if chain.isEmpty {
            showToast("已恢复为未完成", undoable: true)
        } else {
            showToast("已恢复这条 · 连带上级 \(chain.count) 级", undoable: true)
        }
        save()
    }

    /// 恢复整棵：这一条 + 它的全部子步骤 + 上级链（用于「整条主线一起退回来」）。
    public func revertSubtree(_ id: UUID) {
        guard let target = task(id) else { return }
        snapshotForUndo()
        var affected = Set(subtree(id).map(\.id))
        for node in ancestors(of: target) { affected.insert(node.id) }
        for i in tasks.indices where affected.contains(tasks[i].id) {
            tasks[i].done = false
            tasks[i].doneKind = nil
            tasks[i].endedAt = nil
        }
        showToast("已恢复这条及其子步骤", undoable: true)
        save()
    }

    /// 重新执行：把这条以及它**整棵树**搬到今天（原日子不再保留），
    /// 已经完成的子步骤保持完成状态。同日重复执行会被去重。
    public func reexecute(_ id: UUID) {
        guard let target = task(id) else { return }
        if target.day == currentDay {
            showToast("今天已经在清单里了", undoable: false)
            return
        }
        snapshotForUndo()

        // 整棵子树 + 未完成的上级链，一起搬到今天
        var affected = Set(subtree(id).map(\.id))
        let chain = ancestors(of: target).filter { !$0.done }
        for node in chain { affected.insert(node.id) }

        let treeSize = affected.count
        let doneInside = tasks.filter { affected.contains($0.id) && $0.done }.count

        for i in tasks.indices where affected.contains(tasks[i].id) {
            tasks[i].day = currentDay
        }

        // 角色：搬到今天的主线位不能顶掉今天已有的主线
        let existingMain = mainGoal(on: currentDay)?.id
        for i in tasks.indices where affected.contains(tasks[i].id) && tasks[i].isMain {
            if let existing = existingMain, existing != tasks[i].id {
                tasks[i].isMain = false
            }
        }
        if let idx = tasks.firstIndex(where: { $0.id == id }), tasks[idx].parentId == nil {
            tasks[idx].order = nextOrder(parent: nil)
        }

        if doneInside > 0 {
            showToast("已把整棵树搬到今天 · 其中 \(doneInside) 步早已完成", undoable: true)
        } else if treeSize > 1 {
            showToast("已把整棵树搬到今天 · 共 \(treeSize) 条", undoable: true)
        } else {
            showToast("已加入今天", undoable: true)
        }
        save()
    }

    @discardableResult
    public func addTopLevel(_ title: String) -> Task? {
        addTopLevel(title, on: currentDay)
    }

    /// 新建顶层任务。默认是支线——主线只能由用户显式指定，绝不自动产生。
    @discardableResult
    public func addTopLevel(_ title: String, on day: String) -> Task? {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let t = Task(title: trimmed, parentId: nil, order: nextOrder(parent: nil), day: day, isMain: false)
        tasks.append(t)
        save()
        return t
    }

    /// 写下当天的主线（主线栏的书写线用这个）。
    @discardableResult
    public func addMain(_ title: String) -> Task? {
        addMain(title, on: currentDay)
    }

    /// 在指定日期写下主线。
    @discardableResult
    public func addMain(_ title: String, on day: String) -> Task? {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        for i in tasks.indices where tasks[i].day == day { tasks[i].isMain = false }
        let t = Task(title: trimmed, parentId: nil, order: -1, day: day, isMain: true)
        tasks.append(t)
        normalizeOrders(day: day)
        save()
        return t
    }

    /// 调整已结束任务所在的日期（重新执行之外的场景保留原日期）。
    public func setDay(_ id: UUID, to day: String) {
        guard let idx = tasks.firstIndex(where: { $0.id == id }) else { return }
        tasks[idx].day = day
        save()
    }

    @discardableResult
    public func addChild(of parent: UUID, title: String) -> Task? {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let parentTask = task(parent) else { return nil }
        let t = Task(title: trimmed, parentId: parent, order: nextOrder(parent: parent), day: parentTask.day)
        tasks.append(t)
        save()
        return t
    }

    public func rename(_ id: UUID, to title: String) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let idx = tasks.firstIndex(where: { $0.id == id }) else { return }
        tasks[idx].title = trimmed
        save()
    }

    public func delete(_ id: UUID) {
        let affected = Set(subtree(id).map(\.id))
        snapshotForUndo()
        tasks.removeAll { affected.contains($0.id) }
        showToast("已删除", undoable: true)
        save()
    }

    /// 拖拽落点：before / after 表示同级重排，nest 表示降为子步骤。
    public func performDrop(draggedId: UUID, targetId: UUID, zone: DropZone) {
        guard draggedId != targetId, let dragged = task(draggedId), let target = task(targetId) else { return }
        if isDescendant(targetId, of: draggedId) {
            showToast("不能把任务拖进它自己的子步骤里", undoable: false)
            return
        }
        if zone == .nest {
            move(dragged.id, toParent: target.id, index: children(of: target.id).filter { $0.id != draggedId }.count)
            showToast("已调整为子步骤", undoable: false)
            return
        }
        let parent = target.parentId
        let parentDay = parent.flatMap { task($0)?.day } ?? target.day
        var siblings = children(of: parent).filter { $0.id != draggedId }
        let targetIndex = siblings.firstIndex(where: { $0.id == target.id }) ?? siblings.count
        let insertAt = zone == .after ? targetIndex + 1 : targetIndex
        siblings.insert(dragged, at: min(insertAt, siblings.count))
        applySiblingOrder(siblings, parent: parent)
        if let idx = tasks.firstIndex(where: { $0.id == draggedId }) {
            // 关键：同级落点也要真的换到目标的那棵树下（以前只改了顺序，爹还是原来那个）
            tasks[idx].parentId = parent
            // 子步骤跟着上级所在的那一天，而不是无条件跳到今天
            if parent != nil { tasks[idx].day = parentDay }
        }
        assignRoleAfterMove(draggedId, parent: parent)
        showToast("已调整顺序", undoable: false)
        save()
    }

    /// 把某个任务所在的「卡片」（顶层祖先）在当天支线列表里的插入位置算出来。
    /// 拖动整张卡片时，落在深层行上也按位置换位——深层行不参与卡片投放。
    public func branchInsertIndex(containing id: UUID, after: Bool) -> Int {
        guard let root = topLevelAncestor(of: id), let rootTask = task(root) else { return 0 }
        let list = branches(on: rootTask.day)
        guard let index = list.firstIndex(where: { $0.id == root }) else {
            return 0   // 目标是主线：插到支线最前
        }
        return after ? index + 1 : index
    }

    /// 这条任务最上面的祖先（自己就是顶层时返回自己）。
    public func topLevelAncestor(of id: UUID) -> UUID? {
        var current = task(id)
        while let node = current {
            if node.parentId == nil { return node.id }
            current = node.parentId.flatMap { task($0) }
        }
        return nil
    }

    /// 这条任务能不能设为某天的主线：必须是那天的一级任务，且现在不是主线。
    /// 界面用它在拖动时决定"今日主线"栏要不要亮、要不要接受这一放。
    public func canBecomeMain(_ id: UUID, on day: String) -> Bool {
        guard let target = task(id), target.parentId == nil, target.day == day else { return false }
        return !target.isMain
    }

    /// 这条任务能不能降为支线：必须是那天的一级任务，且现在是主线。
    public func canBecomeBranch(_ id: UUID, on day: String) -> Bool {
        guard let target = task(id), target.parentId == nil, target.day == day else { return false }
        return target.isMain
    }

    /// 把某个任务挪到某天支线列表的第 index 位（卡片换位）。
    /// 被拖的任务会落为那天的一级支线；原本是主线的会被解除主线身份。
    public func moveRootToBranchIndex(_ id: UUID, _ index: Int) {
        guard let dragged = task(id) else { return }
        let targetDay = dragged.day
        var ids = branches(on: targetDay).map(\.id).filter { $0 != id }
        let clamped = min(max(index, 0), ids.count)
        ids.insert(id, at: clamped)

        if let idx = tasks.firstIndex(where: { $0.id == id }) {
            tasks[idx].parentId = nil
            tasks[idx].isMain = false
        }
        applySiblingOrder(ids.compactMap { task($0) }, parent: nil)
        if let main = mainGoal(on: targetDay), let idx = tasks.firstIndex(where: { $0.id == main.id }) {
            tasks[idx].order = -1
        }
        showToast("已调整顺序", undoable: false)
        save()
    }

    /// 拖到顶层区域。
    public func moveToTopLevel(_ draggedId: UUID) {
        guard let dragged = task(draggedId) else { return }
        var siblings = children(of: nil).filter { $0.day == dragged.day && $0.id != draggedId }
        siblings.append(dragged)
        applySiblingOrder(siblings, parent: nil)
        if let idx = tasks.firstIndex(where: { $0.id == draggedId }) {
            tasks[idx].day = currentDay
        }
        assignRoleAfterMove(draggedId, parent: nil)
        showToast("已移到顶层", undoable: false)
        save()
    }

    private func move(_ id: UUID, toParent parent: UUID?, index: Int) {
        guard let idx = tasks.firstIndex(where: { $0.id == id }) else { return }
        tasks[idx].parentId = parent
        var siblings = children(of: parent).filter { $0.id != id }
        let clamped = min(max(index, 0), siblings.count)
        if let dragged = task(id) {
            siblings.insert(dragged, at: clamped)
        }
        applySiblingOrder(siblings, parent: parent)
        if let i = tasks.firstIndex(where: { $0.id == id }), let parent {
            tasks[i].day = task(parent)?.day ?? currentDay
        }
        assignRoleAfterMove(id, parent: parent)
        save()
    }

    private func applySiblingOrder(_ siblings: [Task], parent: UUID?) {
        for (i, s) in siblings.enumerated() {
            if let idx = tasks.firstIndex(where: { $0.id == s.id }) {
                tasks[idx].order = i
                if parent == nil { tasks[idx].parentId = nil }
            }
        }
    }

    // MARK: - 跨天

    /// 打开应用或计时检查时调用：日期变了就开启新的一天（旧任务不结转）。
    @discardableResult
    public func checkRollover(now: Date = Date()) -> Bool {
        let today = DayKey.key(for: now)
        guard today != currentDay else { return false }
        let wasFollowingToday = (selectedDay == currentDay)
        currentDay = today
        if wasFollowingToday { selectedDay = today }
        save()
        showToast("新的一天 · 未完成的已进入未完成池", undoable: false)
        return true
    }

    public func startRolloverTimer() {
        rolloverTimer?.invalidate()
        rolloverTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            self?.checkRollover()
        }
    }

    public func stopRolloverTimer() {
        rolloverTimer?.invalidate()
        rolloverTimer = nil
    }
}
