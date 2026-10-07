import SwiftUI
import Core

/// 非重点（未完成池）：按范围查看未完成任务，可结束或重新执行。
public struct PoolSheetView: View {
    @EnvironmentObject var store: TaskStore
    public let onClose: () -> Void

    public init(onClose: @escaping () -> Void) {
        self.onClose = onClose
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SheetHeader(
                title: "未完成项目清单",
                subtitle: "按日期倒序",
                onClose: onClose
            )
            Rectangle().fill(Theme.hairline).frame(height: 1)

            HStack(spacing: 6) {
                ForEach(PoolRange.allCases, id: \.self) { range in
                    RangeChip(range: range, selected: store.range == range) {
                        store.range = range
                    }
                }
                Spacer()
                Text("\(store.poolCount) 件")
                    .font(Theme.sans(11.5))
                    .foregroundStyle(Theme.ink3)
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 12)

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    let items = store.poolTasks()
                    if items.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("这个范围里没有未完成的事")
                                .font(Theme.serif(15))
                                .foregroundStyle(Theme.ink2)
                            Text("结束或完成的事都在「已结束」里，随时可以找回。")
                                .font(Theme.sans(12.5))
                                .foregroundStyle(Theme.ink3)
                        }
                        .padding(.vertical, 30)
                    } else {
                        ForEach(items) { task in
                            PoolRowView(task: task, onClose: onClose)
                        }
                    }
                }
                .padding(.horizontal, 22)
                .padding(.bottom, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .animation(Motion.spring, value: store.tasks)
            }

        }
        .frame(width: 620, height: 560)
        .background(Theme.paper)
    }
}

/// 清单里的日期行：任务所属的那一天 + 相对天数。
@MainActor
func dateLine(_ task: Task) -> String {
    let day = DayKey.shortLabel(for: task.day)
    return "\(day) · \(relativeText(task))"
}

@MainActor
func relativeText(_ task: Task) -> String {
    let days = DayKey.daysBetween(task.day, DayKey.key())
    if days <= 0 { return "今天" }
    if days == 1 { return "昨天" }
    return "\(days) 天前"
}

/// 未完成项目清单里的一行：与日页用同一套层级语法（缩进 + 树线 + 字重字色）。
private struct PoolRowView: View {
    @EnvironmentObject var store: TaskStore
    let task: Task
    let onClose: () -> Void
    @State private var hovering = false

    var body: some View {
        let level = min(store.level(of: task), 3)
        HStack(spacing: 0) {
            TreeRails(level: level)
            HStack(alignment: .center, spacing: 8) {
                RoleGlyph(isMain: task.isMain, level: level)
                VStack(alignment: .leading, spacing: 2) {
                    Text(task.title)
                        .font(Theme.titleFont(level))
                        .foregroundStyle(Theme.titleColor(level))
                        .lineLimit(1)
                    Text(dateLine(task))
                        .font(Theme.sans(Theme.metaSize))
                        .foregroundStyle(Theme.ink3)
                }
                Spacer(minLength: 10)
                HStack(spacing: 2) {
                    QuietAction(title: "跳转", tone: .plain) {
                        store.jumpTo(task.id)
                        onClose()
                    }
                    QuietAction(title: "结束", tone: .accent) { store.ignore(task.id) }
                    QuietAction(title: "重新执行", tone: .plain) { store.reexecute(task.id) }
                }
            }
        }
        .frame(height: max(38, Theme.rowHeight(level) + 8))
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
    }
}

/// 已结束：完成和结束都算终点，可撤销或恢复。
public struct DoneSheetView: View {
    @EnvironmentObject var store: TaskStore
    public let onClose: () -> Void

    public init(onClose: @escaping () -> Void) {
        self.onClose = onClose
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SheetHeader(
                title: "已结束项目清单",
                subtitle: "按日期倒序",
                onClose: onClose
            )
            Rectangle().fill(Theme.hairline).frame(height: 1)

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    let items = store.doneTasks
                    if items.isEmpty {
                        Text("还没有结束的事。")
                            .font(Theme.sans(13))
                            .foregroundStyle(Theme.ink3)
                            .padding(.vertical, 30)
                    } else {
                        ForEach(items) { task in
                            DoneRowView(task: task)
                        }
                    }
                }
                .padding(.horizontal, 22)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .animation(Motion.spring, value: store.tasks)
            }

        }
        .frame(width: 620, height: 560)
        .background(Theme.paper)
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
            HStack(alignment: .center, spacing: 8) {
                RoleGlyph(isMain: task.isMain, level: level)
                VStack(alignment: .leading, spacing: 2) {
                    Text(task.title)
                        .font(Theme.titleFont(level))
                        .foregroundStyle(Theme.doneInk)
                        .strikethrough(true, color: Theme.doneInk)
                        .lineLimit(1)
                    Text(dateLine(task) + " · " + (task.doneKind == .ignored ? "结束时选择不做" : "勾选完成"))
                        .font(Theme.sans(Theme.metaSize))
                        .foregroundStyle(Theme.ink3)
                }
                Spacer(minLength: 10)
                QuietAction(title: "恢复", tone: .accent) {
                    store.revert(task.id)
                }
                .contextMenu {
                    Button("恢复这条及其子步骤") { store.revertSubtree(task.id) }
                }
                .help("恢复这条并连带它上面的任务链；右键可以连同子步骤一起恢复")
            }
        }
        .frame(height: max(38, Theme.rowHeight(level) + 8))
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
    }
}

// MARK: - 复用小组件

struct SheetHeader: View {
    let title: String
    let subtitle: String
    let onClose: () -> Void

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(Theme.serif(Theme.dateSize, .semibold))
                    .foregroundStyle(Theme.ink)
                Text(subtitle)
                    .font(Theme.sans(11.5))
                    .foregroundStyle(Theme.ink3)
            }
            Spacer()
            Button(action: onClose) {
                Text("关闭")
                    .font(Theme.sans(12.5, .medium))
                    .foregroundStyle(Theme.ink2)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(RoundedRectangle(cornerRadius: 6).fill(Theme.surfaceAlt))
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.escape, modifiers: [])
        }
        .padding(.horizontal, 22)
        .padding(.top, 20)
        .padding(.bottom, 14)
    }
}

struct RangeChip: View {
    let range: PoolRange
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(range.label)
                .font(Theme.sans(Theme.controlSize, selected ? .semibold : .regular))
                .foregroundStyle(selected ? Theme.ink : Theme.ink3)
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .background(
                    Capsule().fill(selected ? Theme.surfaceAlt : Color.clear)
                )
        }
        .buttonStyle(.plain)
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
                .font(Theme.sans(11.5, .medium))
                .foregroundStyle(hovering ? Theme.ink : color)
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(
                    RoundedRectangle(cornerRadius: 5)
                        .fill(hovering ? Theme.surfaceAlt : Color.clear)
                )
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }

    private var color: Color {
        switch tone {
        case .accent: return Theme.accent
        case .warn: return Theme.ink2
        case .plain: return Theme.ink2
        }
    }
}
