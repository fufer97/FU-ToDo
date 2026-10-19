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

/// 卡片物种的小印章：用 card 令牌当一枚纸质小标签，压在标题右侧。
/// acid 主题里它是黑底荧光黄（一张贴纸），其它主题里是各色纸片。
struct SheetStamp: View {
    let text: String

    var body: some View {
        Text(text)
            .font(Theme.mono(8.5, .semibold))
            .tracking(1.6)
            .foregroundStyle(Theme.cardInk)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Theme.cardBackground)
            .overlay(Rectangle().strokeBorder(Theme.cardBorder, lineWidth: 0.8))
            .rotationEffect(.degrees(-2))
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
            VStack(alignment: .leading, spacing: 5) {
                Text("未完成清单")
                    .font(Theme.display(38))
                    .tracking(Theme.displayTracking(38))
                    .foregroundStyle(Theme.ink)
                Text("POOL · 只收今天以前的一级任务")
                    .font(Theme.mono(9))
                    .tracking(1.5)
                    .foregroundStyle(Theme.ink3)
            }
            Spacer(minLength: 12)
            SheetStamp(text: "POOL")
                .padding(.bottom, 5)
        }
        .padding(.horizontal, 24)
        .padding(.top, 16)
        .padding(.bottom, 14)
    }

    private var scopeRow: some View {
        HStack(spacing: 8) {
            ForEach(PoolRange.allCases, id: \.self) { range in
                RangeChip(range: range, selected: store.range == range) {
                    store.range = range
                }
            }
            Spacer(minLength: 12)
            Text("SORT / DESC")
                .font(Theme.mono(8))
                .tracking(1.4)
                .foregroundStyle(Theme.ink3)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 11)
    }

    private var list: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                let items = store.poolTasks()
                if items.isEmpty {
                    emptyState
                } else {
                    ForEach(Array(items.enumerated()), id: \.element.id) { index, task in
                        PoolRowView(task: task, onClose: onClose)
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

/// 未完成清单里的一行：与日页用同一套层级语法（缩进 + 树线 + 字重字色）。
private struct PoolRowView: View {
    @EnvironmentObject var store: TaskStore
    let task: Task
    let onClose: () -> Void
    @State private var hovering = false

    var body: some View {
        let level = min(store.level(of: task), 3)
        HStack(spacing: 0) {
            TreeRails(level: level)
            HStack(alignment: .center, spacing: 9) {
                RoleGlyph(isMain: task.isMain, level: level)
                VStack(alignment: .leading, spacing: 3) {
                    Text(task.title)
                        .font(Theme.titleFont(level))
                        .foregroundStyle(Theme.titleColor(level))
                        .lineLimit(1)
                    Text("\(dateStamp(task.day))  /  \(relativeText(task))")
                        .font(Theme.mono(Theme.metaSize - 1.5))
                        .tracking(0.8)
                        .foregroundStyle(Theme.ink3)
                }
                Spacer(minLength: 12)
                HStack(spacing: 2) {
                    QuietAction(title: "跳转", tone: .plain) {
                        store.jumpTo(task.id)
                        onClose()
                    }
                    QuietAction(title: "结束", tone: .accent) { store.ignore(task.id) }
                    QuietAction(title: "重新执行", tone: .plain) { store.reexecute(task.id) }
                }
                .opacity(hovering ? 1 : 0.72)
            }
            .padding(.vertical, 8)
        }
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
            VStack(alignment: .leading, spacing: 5) {
                Text("已结束清单")
                    .font(Theme.display(38))
                    .tracking(Theme.displayTracking(38))
                    .foregroundStyle(Theme.ink)
                Text("ARCHIVE · 完成与结束都在这里")
                    .font(Theme.mono(9))
                    .tracking(1.5)
                    .foregroundStyle(Theme.ink3)
            }
            Spacer(minLength: 12)
            SheetStamp(text: "ARCHIVE")
                .padding(.bottom, 5)
        }
        .padding(.horizontal, 24)
        .padding(.top, 16)
        .padding(.bottom, 14)
    }

    private var list: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                let items = store.doneTasks
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

private struct DoneRowView: View {
    @EnvironmentObject var store: TaskStore
    let task: Task
    @State private var hovering = false

    var body: some View {
        let level = min(store.level(of: task), 3)
        HStack(spacing: 0) {
            TreeRails(level: level)
            HStack(alignment: .center, spacing: 9) {
                RoleGlyph(isMain: task.isMain, level: level)
                VStack(alignment: .leading, spacing: 3) {
                    Text(task.title)
                        .font(Theme.titleFont(level))
                        .foregroundStyle(Theme.doneInk)
                        .strikethrough(true, color: Theme.doneInk)
                        .lineLimit(1)
                    Text("\(dateStamp(task.day))  /  \(task.doneKind == .ignored ? "结束时选择不做" : "勾选完成")  /  \(relativeText(task))")
                        .font(Theme.mono(Theme.metaSize - 1.5))
                        .tracking(0.8)
                        .foregroundStyle(Theme.ink3)
                }
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
        }
        .background(hovering ? Theme.ink.opacity(0.035) : Color.clear)
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
    }
}

// MARK: - 复用小组件

/// 范围选择：选中的那枚是一张小卡片（card 令牌），没选中的只有一圈细线。
struct RangeChip: View {
    let range: PoolRange
    let selected: Bool
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if selected {
                    Rectangle()
                        .fill(Theme.cardInk.opacity(0.75))
                        .frame(width: 4, height: 4)
                }
                Text(range.label)
                    .font(Theme.sans(Theme.controlSize, selected ? .semibold : .regular))
                    .tracking(0.4)
                    .foregroundStyle(selected ? Theme.cardInk : (hovering ? Theme.ink : Theme.ink3))
            }
            .padding(.horizontal, 11)
            .padding(.vertical, 5)
            .background(selected ? Theme.cardBackground : Color.clear)
            .overlay(
                Rectangle().strokeBorder(borderColor, lineWidth: selected ? 0.9 : 0.8)
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }

    private var borderColor: Color {
        if selected { return Theme.cardBorder }
        return hovering ? Theme.accent.opacity(0.6) : Theme.rule
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
