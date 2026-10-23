import SwiftUI
import Core

// MARK: - 窗口语言（两个清单、使用说明、首次引导共用）
//
// 所有弹层 / 窗口都长成同一页纸：顶部一行等宽小标签（左「FU TODO / XXX」，
// 右计数或版本），下面 0.8pt 细线，再往下是大字号展示标题。
// 圆角一律收掉，线条一律 0.8pt，阴影一律不用。

/// 0.8pt 细线：本组窗口里所有的分隔线都用它。
struct Hairline: View {
    var body: some View {
        Rectangle()
            .fill(Theme.rule)
            .frame(height: 0.8)
    }
}

/// 窗口顶部那行等宽小标签：右侧是计数（清单）或版本（说明 / 引导）。
struct WindowTagBar: View {
    let label: String
    let trailing: String
    var onClose: (() -> Void)?

    init(_ label: String, trailing: String, onClose: (() -> Void)? = nil) {
        self.label = label
        self.trailing = trailing
        self.onClose = onClose
    }

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            Text(label)
                .font(Theme.mono(9, .semibold))
                .tracking(2)
                .foregroundStyle(Theme.ink3)
            Spacer(minLength: 12)
            Text(trailing)
                .font(Theme.mono(9, .medium))
                .tracking(1.4)
                .foregroundStyle(Theme.ink2)
            if let onClose {
                TagCloseButton(action: onClose)
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 13)
        .padding(.bottom, 9)
    }
}

/// 方角细边框的「关闭」：旁边标着 ESC，让键盘出口可见。
struct TagCloseButton: View {
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Text("关闭")
                    .font(Theme.sans(11, .medium))
                    .foregroundStyle(hovering ? Theme.ink : Theme.ink2)
                Rectangle()
                    .fill(Theme.rule)
                    .frame(width: 0.8, height: 10)
                Text("ESC")
                    .font(Theme.mono(7.5, .medium))
                    .tracking(0.8)
                    .foregroundStyle(Theme.ink3)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(hovering ? Theme.ink.opacity(0.06) : Color.clear)
            .overlay(Rectangle().strokeBorder(Theme.rule, lineWidth: 0.8))
        }
        .buttonStyle(.plain)
        .keyboardShortcut(.escape, modifiers: [])
        .onHover { hovering = $0 }
    }
}

/// 卡片物种的小印章：4.0 已去掉贴纸语言，保留一个安静的小标签。
struct SheetStamp: View {
    let text: String

    var body: some View {
        Text(text)
            .font(Theme.mono(8.5, .semibold))
            .tracking(1.6)
            .foregroundStyle(Theme.ink3)
            .overlay(alignment: .bottom) {
                Rectangle().fill(Theme.rule).frame(height: 1)
            }
            .padding(.bottom, 2)
    }
}

// MARK: - 未完成清单

/// 非重点（未完成池）：按范围查看未完成任务，可结束或重新执行。
public struct PoolSheetView: View {
    @EnvironmentObject var store: TaskStore
    public let onClose: () -> Void

    public init(onClose: @escaping () -> Void) {
        self.onClose = onClose
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            WindowTagBar(
                "FU TODO / POOL",
                trailing: "OPEN \(store.poolCount)",
                onClose: onClose
            )
            Hairline()

            masthead
            Hairline()
            scopeRow
            Hairline()

            list

            Hairline()
            footBar
        }
        .frame(width: 620, height: 560)
        .background(Theme.canvas)
    }

    private var masthead: some View {
        HStack(alignment: .bottom, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text("未完成清单")
                    .font(Theme.display(30))
                    .tracking(2)
                    .foregroundStyle(Theme.ink)
                Text("只收今天之前的一级任务 · 不自动结转")
                    .font(Theme.sans(11))
                    .tracking(1)
                    .foregroundStyle(Theme.ink3)
            }
            Spacer(minLength: 12)
            SheetStamp(text: "登记纸")
                .padding(.bottom, 5)
        }
        .padding(.horizontal, 24)
        .padding(.top, 16)
        .padding(.bottom, 14)
    }

    private var scopeRow: some View {
        HStack(spacing: 22) {
            ForEach(PoolRange.allCases, id: \.self) { range in
                RangeTab(range: range, selected: store.range == range) {
                    store.range = range
                }
            }
            Spacer(minLength: 12)
            Text("按日期倒序")
                .font(Theme.mono(8))
                .tracking(1.4)
                .foregroundStyle(Theme.ink3)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 11)
    }

    /// 按天分组：同一天的事排在同一个日期组头下，先看上下文再决定。
    private var groupedPool: [(day: String, items: [Task])] {
        let items = store.poolTasks()
        var order: [String] = []
        var groups: [String: [Task]] = [:]
        for item in items {
            if groups[item.day] == nil { order.append(item.day) }
            groups[item.day, default: []].append(item)
        }
        return order.map { ($0, groups[$0] ?? []) }
    }

    private var list: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                let groups = groupedPool
                if groups.isEmpty {
                    emptyState
                } else {
                    ForEach(Array(groups.enumerated()), id: \.element.day) { groupIndex, group in
                        PoolDayGroup(day: group.day, items: group.items, baseIndex: folioBase(before: groupIndex), onClose: onClose)
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 6)
            .padding(.bottom, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .animation(Motion.spring, value: store.tasks)
        }
    }

    /// 每组的 A-01 编号从 1 连续编到当前组为止。
    private func folioBase(before groupIndex: Int) -> Int {
        groupedPool.prefix(groupIndex).reduce(0) { $0 + $1.items.count }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("这个范围里没有未完成的事")
                .font(Theme.display(22))
                .tracking(Theme.displayTracking(22))
                .foregroundStyle(Theme.ink2)
            Text("EMPTY · 结束或完成的事都在「已结束」里，随时可以找回。")
                .font(Theme.mono(9))
                .tracking(1.2)
                .foregroundStyle(Theme.ink3)
        }
        .padding(.vertical, 40)
    }

    private var footBar: some View {
        HStack(spacing: 12) {
            Text("按日期倒序")
                .font(Theme.mono(8))
                .tracking(1.2)
                .foregroundStyle(Theme.ink3)
            Spacer(minLength: 12)
            Text("行内：跳转 / 结束 / 重新执行")
                .font(Theme.mono(8))
                .tracking(1.2)
                .foregroundStyle(Theme.ink3)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 9)
    }
}

/// 清单里的日期戳：2026.10.08（等宽字体下更像登记本）。
@MainActor
func dateStamp(_ day: String) -> String {
    day.replacingOccurrences(of: "-", with: ".")
}

@MainActor
func relativeText(_ task: Task) -> String {
    let days = DayKey.daysBetween(task.day, DayKey.key())
    if days <= 0 { return "今天" }
    if days == 1 { return "昨天" }
    return "\(days) 天前"
}

/// 未完成清单的日期组：衬线日期头 + 「N 天前 · M 件」，条目带 A-01 编号。
private struct PoolDayGroup: View {
    @EnvironmentObject var store: TaskStore
    let day: String
    let items: [Task]
    let baseIndex: Int
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: 14) {
                Text(DayKey.cnLabel(for: day))
                    .font(Theme.display(16))
                    .tracking(1)
                    .foregroundStyle(Theme.ink)
                Text("\(poolAgeText) · \(items.count) 件")
                    .font(Theme.mono(9.5))
                    .tracking(1)
                    .foregroundStyle(Theme.ink3)
                Spacer(minLength: 0)
            }
            .padding(.top, 24)
            .padding(.bottom, 4)
            Rectangle().fill(Theme.rule).frame(height: 1)

            ForEach(Array(items.enumerated()), id: \.element.id) { index, task in
                PoolRowView(task: task, folio: String(format: "A-%02d", baseIndex + index + 1), onClose: onClose)
            }
        }
    }

    private var poolAgeText: String {
        let days = DayKey.daysBetween(day, DayKey.key())
        if days == 1 { return "1 天前" }
        return "\(days) 天前"
    }
}

/// 未完成清单里的一行：登记纸语法——编号、事名、动作，没有逾期与红色警告。
private struct PoolRowView: View {
    @EnvironmentObject var store: TaskStore
    let task: Task
    let folio: String
    let onClose: () -> Void
    @State private var hovering = false

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 14) {
            Text(folio)
                .font(Theme.mono(Theme.folioSize))
                .foregroundStyle(Theme.ink3)
                .frame(width: 36, alignment: .leading)
            Text(task.title)
                .font(Theme.sans(Theme.mainSize))
                .foregroundStyle(Theme.ink)
                .lineLimit(1)
            let steps = store.subtree(task.id).count - 1
            if steps > 0 {
                Text("\(steps) 步")
                    .font(Theme.mono(9.5))
                    .foregroundStyle(Theme.ink3)
                    .frame(minWidth: 40, alignment: .leading)
            }
            Spacer(minLength: 12)
            HStack(spacing: 2) {
                QuietAction(title: "跳转", tone: .plain) {
                    store.jumpTo(task.id)
                    onClose()
                }
                QuietAction(title: "结束", tone: .plain) { store.ignore(task.id) }
                QuietAction(title: "重新执行", tone: .accent) { store.reexecute(task.id) }
            }
            .opacity(hovering ? 1 : 0.72)
        }
        .padding(.vertical, 8)
        .background(hovering ? Theme.ink.opacity(0.035) : Color.clear)
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
    }
}

// MARK: - 已结束清单

/// 已结束：完成和结束都算终点，可撤销或恢复。
public struct DoneSheetView: View {
    @EnvironmentObject var store: TaskStore
    public let onClose: () -> Void

    public init(onClose: @escaping () -> Void) {
        self.onClose = onClose
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            WindowTagBar(
                "FU TODO / DONE",
                trailing: "DONE \(store.doneTasks.count)",
                onClose: onClose
            )
            Hairline()

            masthead
            Hairline()

            list

            Hairline()
            footBar
        }
        .frame(width: 620, height: 560)
        .background(Theme.canvas)
    }

    private var masthead: some View {
        HStack(alignment: .bottom, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text("已结束清单")
                    .font(Theme.display(30))
                    .tracking(2)
                    .foregroundStyle(Theme.ink)
                Text("完成与结束都在这里 · 随时可以恢复")
                    .font(Theme.sans(11))
                    .tracking(1)
                    .foregroundStyle(Theme.ink3)
            }
            Spacer(minLength: 12)
            SheetStamp(text: "归档")
                .padding(.bottom, 5)
        }
        .padding(.horizontal, 24)
        .padding(.top, 16)
        .padding(.bottom, 14)
    }

    private var list: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // 只列顶层完成树（一棵树一行），子步骤不重复——和「今日完成」栏同一规则
                let items = store.doneTasks.filter { $0.parentId == nil }
                if items.isEmpty {
                    emptyState
                } else {
                    ForEach(Array(items.enumerated()), id: \.element.id) { index, task in
                        DoneRowView(task: task)
                        if index < items.count - 1 {
                            Hairline()
                        }
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 6)
            .padding(.bottom, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .animation(Motion.spring, value: store.tasks)
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("还没有结束的事")
                .font(Theme.display(22))
                .tracking(Theme.displayTracking(22))
                .foregroundStyle(Theme.ink2)
            Text("EMPTY · 勾选完成或选择结束，任务都会落到这里。")
                .font(Theme.mono(9))
                .tracking(1.2)
                .foregroundStyle(Theme.ink3)
        }
        .padding(.vertical, 40)
    }

    private var footBar: some View {
        HStack(spacing: 12) {
            Text("按日期倒序")
                .font(Theme.mono(8))
                .tracking(1.2)
                .foregroundStyle(Theme.ink3)
            Spacer(minLength: 12)
            Text("右键一行：连带子步骤一起恢复")
                .font(Theme.mono(8))
                .tracking(1.2)
                .foregroundStyle(Theme.ink3)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 9)
    }
}

/// 已结束清单里的一行：登记纸语法——日期、事名、结束方式、恢复。不再画树线。
private struct DoneRowView: View {
    @EnvironmentObject var store: TaskStore
    let task: Task
    @State private var hovering = false

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 14) {
            Text(dateStamp(task.day))
                .font(Theme.mono(9.5))
                .tracking(0.8)
                .foregroundStyle(Theme.ink3)
                .frame(width: 68, alignment: .leading)
            Text(task.title)
                .font(Theme.sans(Theme.mainSize))
                .foregroundStyle(Theme.doneInk)
                .strikethrough(true, color: Theme.doneInk.opacity(0.7))
                .lineLimit(1)
            Text(task.doneKind == .ignored ? "结束时选择不做" : "勾选完成")
                .font(Theme.mono(9))
                .tracking(0.5)
                .foregroundStyle(Theme.ink3)
            Spacer(minLength: 12)
            QuietAction(title: "恢复", tone: .accent) {
                store.revert(task.id)
            }
            .opacity(hovering ? 1 : 0.72)
            .contextMenu {
                Button("恢复这条及其子步骤") { store.revertSubtree(task.id) }
            }
            .help("恢复这条并连带它上面的任务链；右键可以连同子步骤一起恢复")
        }
        .padding(.vertical, 8)
        .background(hovering ? Theme.ink.opacity(0.035) : Color.clear)
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
    }
}

// MARK: - 复用小组件

/// 范围选择（4.0）：文字标签 + 下划线，选中的那枚落墨。
struct RangeTab: View {
    let range: PoolRange
    let selected: Bool
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Text(range.label)
                .font(Theme.sans(12, selected ? .medium : .regular))
                .tracking(0.6)
                .foregroundStyle(selected ? Theme.ink : (hovering ? Theme.ink : Theme.ink3))
                .overlay(alignment: .bottom) {
                    if selected {
                        Rectangle().fill(Theme.ink).frame(height: 1).offset(y: 3)
                    }
                }
                .padding(.bottom, 3)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }
}

enum ActionTone {
    case accent, warn, plain
}

/// 文字型动作按钮：不靠底色，避免一屏出现十几个同款胶囊。
struct QuietAction: View {
    let title: String
    let tone: ActionTone
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(Theme.sans(10.5, .medium))
                .tracking(0.4)
                .foregroundStyle(hovering ? Theme.ink : color)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(hovering ? Theme.ink.opacity(0.05) : Color.clear)
                .overlay(
                    Rectangle().strokeBorder(hovering ? Theme.rule : Color.clear, lineWidth: 0.8)
                )
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }

    private var color: Color {
        switch tone {
        case .accent: return Theme.accentInk
        case .warn, .plain: return Theme.ink2
        }
    }
}
