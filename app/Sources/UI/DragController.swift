import SwiftUI
import Core

/// 拖动中的交互状态。**故意不放在 TaskStore 里**：
/// 拖动时这些值会频繁变化，如果和数据放在同一个 ObservableObject，
/// 日历、清单也会跟着重渲染，拖动就会卡顿。
/// 只有日页与任务行观察它；其它视图需要时用普通引用（只在事件里读，不订阅）。
@MainActor
public final class DragController: ObservableObject {
    /// 正在被拖的任务。
    @Published public var draggingId: UUID?
    /// 行级落点：哪一行、落在前/后/接进去。
    @Published public var target: DragState?
    /// 整栏插入位（一级卡片换位用）。
    @Published public var insertIndex: Int?

    public init() {}

    public var isDragging: Bool { draggingId != nil }

    /// 结束这次拖动：清掉所有拖动状态。
    /// 任何"这一放不改变什么"的路径（落在自己身上、落在无效的栏标题上、
    /// 松手时没有任何落点）都必须调用它——否则源卡片会一直保持提起（透明）状态，
    /// 看起来就像卡片凭空消失了。
    public func end() {
        draggingId = nil
        target = nil
        insertIndex = nil
    }

    /// 只有"真的有落点"时才隐藏源卡片（这时让位的卡片正好填进它的空位）。
    public var hasActiveTarget: Bool { insertIndex != nil || target != nil }
}
