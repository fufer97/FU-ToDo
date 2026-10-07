import SwiftUI
import Core

/// 唯一的输入会话：同一时刻只可能有一个输入框（新建或编辑），
/// 于是「点空白结束」「回车继续」「Tab 往下一级」这些规则只有一套。
@MainActor
public final class InputSession: ObservableObject {

    public enum Mode: Equatable {
        case sibling
        case child

        public var switching: Mode { self == .child ? .sibling : .child }
    }

    public enum Kind: Equatable {
        /// 正在新建：新建同级或下级
        case create(Mode)
        /// 正在改这一条的文字
        case edit
    }

    @Published public var targetId: UUID?
    @Published public var kind: Kind = .create(.sibling)
    @Published public var text: String = ""

    public init() {}

    public var isActive: Bool { targetId != nil }
    public var isEditing: Bool { if case .edit = kind { return true }; return false }
    public var isCreating: Bool { if case .create = kind { return true }; return false }

    public var createMode: Mode {
        if case .create(let mode) = kind { return mode }
        return .sibling
    }

    // MARK: 打开 / 关闭

    /// 开始新建。若正有另一个输入在进行，先把它落下去，避免内容丢失。
    public func startCreate(store: TaskStore, at id: UUID, mode: Mode) {
        flushIfMovingAway(store: store, to: id)
        targetId = id
        kind = .create(mode)
        text = ""
    }

    /// 开始编辑这一条。若正有另一个输入在进行，先把它落下去。
    public func startEdit(store: TaskStore, at id: UUID, currentTitle: String) {
        flushIfMovingAway(store: store, to: id)
        targetId = id
        kind = .edit
        text = currentTitle
    }

    /// 点到/切到别的行时，把正在写的那一条先提交。
    private func flushIfMovingAway(store: TaskStore, to id: UUID) {
        guard isActive, targetId != id else { return }
        finishByClickingAway(store: store)
    }

    public func close() {
        targetId = nil
        text = ""
    }

    public func toggleMode() {
        guard isCreating else { return }
        kind = .create(createMode.switching)
    }

    /// 点击任意空白处：把正在写的东西落下去，然后结束（不再继续新建）。
    public func finishByClickingAway(store: TaskStore) {
        guard isActive else { return }
        commit(store: store, editContinue: nil)
        close()
    }

    // MARK: 提交

    /// 回车 / Tab 调用的提交。
    /// - Parameters:
    ///   - editContinue: 编辑提交后是否接着往下写（nil 表示就此结束；.sibling/.child 决定下一条落哪）。
    public func commit(store: TaskStore, editContinue: Mode? = .sibling) {
        guard let targetId else { return }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)

        switch kind {
        case .edit:
            if !trimmed.isEmpty { store.rename(targetId, to: trimmed) }
            text = ""
            if let editContinue {
                // 改完继续在这条下面往下写（和大纲编辑器一致）
                kind = .create(editContinue)
            } else {
                close()
            }

        case .create(let mode):
            guard !trimmed.isEmpty else { close(); return }
            let created: Task?
            switch mode {
            case .sibling:
                created = store.addSibling(after: targetId, title: trimmed)
            case .child:
                created = store.addChild(of: targetId, title: trimmed)
            }
            text = ""
            if let created {
                // 锚点移到刚创建的那一条：下一次回车就是它的同级
                self.targetId = created.id
                kind = .create(.sibling)
            } else {
                close()
            }
        }
    }
}
