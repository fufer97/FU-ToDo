import SwiftUI
import UniformTypeIdentifiers
import Core

/// 月历：一天一个格子，格子里直接显示那天的内容。
public struct MonthGridView: View {
    @EnvironmentObject var store: TaskStore
    /// 普通引用：月历只在事件里读它，不订阅，所以拖动时不会跟着重渲染。
    public let drag: DragController

    public let anchor: Date
    public let onSelect: (String) -> Void

    private let spacing: CGFloat = 6
    private let weekdaySymbols = ["一", "二", "三", "四", "五", "六", "日"]

    private var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.firstWeekday = 2
        return c
    }

    public init(anchor: Date, drag: DragController, onSelect: @escaping (String) -> Void) {
        self.anchor = anchor
        self.drag = drag
        self.onSelect = onSelect
    }

    /// 以周一为首列，固定 6 行（42 格）。
    private var cells: [Date] {
        let cal = calendar
        guard let monthStart = cal.dateInterval(of: .month, for: anchor)?.start else { return [] }
        let weekday = cal.component(.weekday, from: monthStart)
        let offset = (weekday - cal.firstWeekday + 7) % 7
        guard let start = cal.date(byAdding: .day, value: -offset, to: monthStart) else { return [] }
        return (0..<42).compactMap { cal.date(byAdding: .day, value: $0, to: start) }
    }

    public var body: some View {
        let days = cells
        VStack(spacing: spacing) {
            HStack(spacing: spacing) {
                ForEach(weekdaySymbols, id: \.self) { symbol in
                    Text(symbol)
                        .font(Theme.sans(11.5, .medium))
                        .foregroundStyle(Theme.ink3)
                        .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 18)

            ForEach(0..<6, id: \.self) { row in
                HStack(spacing: spacing) {
                    ForEach(0..<7, id: \.self) { col in
                        let index = row * 7 + col
                        if index < days.count {
                            let date = days[index]
                            DayCellView(
                                drag: drag,
                                dayKey: DayKey.key(for: date),
                                dayNumber: calendar.component(.day, from: date),
                                inMonth: calendar.isDate(date, equalTo: anchor, toGranularity: .month),
                                onSelect: onSelect
                            )
                        } else {
                            Color.clear.frame(maxWidth: .infinity)
                        }
                    }
                }
                .frame(maxHeight: .infinity)
            }
        }
    }
}

/// 单个日子格子。
struct DayCellView: View {
    @EnvironmentObject var store: TaskStore
    let drag: DragController

    let dayKey: String
    let dayNumber: Int
    let inMonth: Bool
    let onSelect: (String) -> Void

    @State private var hovering = false
    @State private var dropHovering = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var isToday: Bool { dayKey == store.currentDay }
    /// 还没到的日子：整格用浅灰，和「已经过去」的区分开。
    private var isFuture: Bool { dayKey > store.currentDay }
    private var isSelected: Bool { dayKey == store.selectedDay }

    var body: some View {
        let roots = store.orderedRoots(of: dayKey)
        let all = store.taskCount(on: dayKey)
        let doneCount = store.doneCount(on: dayKey)
        let shown = Array(roots.prefix(4))
        let hasMore = roots.count > shown.count
        let hasContent = !roots.isEmpty || all > 0
        let allDone = all > 0 && doneCount == all

        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Text("\(dayNumber)")
                    .font(Theme.serif(13, isToday ? .bold : .regular))
                    .foregroundStyle(
                        isToday ? Theme.accent
                            : (isFuture ? Theme.faint.opacity(0.85) : (inMonth ? Theme.ink2 : Theme.faint))
                    )
                Spacer(minLength: 0)
                if allDone {
                    Image(systemName: "checkmark")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(Theme.doneInk)
                }
            }
            ForEach(shown) { task in
                HStack(alignment: .top, spacing: 5) {
                    if task.isMain {
                        // 主线：一个正菱形（画出来的形状，不用字符当图标）
                        Rectangle()
                            .fill(isFuture ? Theme.accent.opacity(0.45) : Theme.accent)
                            .frame(width: 6, height: 6)
                            .rotationEffect(.degrees(45))
                            .frame(width: 9, height: 9)
                            .padding(.top, 2)
                    } else {
                        Circle()
                            .fill(task.done ? Theme.doneInk : Theme.faint)
                            .frame(width: 3, height: 3)
                            .padding(.top, 5)
                            .opacity(isFuture ? 0.6 : 1)
                    }
                    Text(task.title)
                        .font(Theme.sans(11, task.done ? .regular : .medium))
                        .foregroundStyle(task.done ? Theme.doneInk : (isFuture ? Theme.faint : Theme.ink2))
                        .strikethrough(task.done, color: Theme.doneInk)
                        .lineLimit(roots.count > 2 ? 1 : 2)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            if hasMore {
                Text("…")
                    .font(Theme.sans(11))
                    .foregroundStyle(Theme.faint)
                    .padding(.leading, 8)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(cellBackground(hasContent: hasContent))
        .overlay(cellBorder(hasContent: hasContent))
        .opacity(inMonth ? 1 : 0.55)
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(Theme.accent, lineWidth: dropHovering ? 2 : 0)
        )
        .animation(reduceMotion ? nil : Motion.quick, value: hovering)
        .animation(reduceMotion ? nil : Motion.quick, value: isSelected)
        .animation(reduceMotion ? nil : Motion.quick, value: dropHovering)
        .animation(reduceMotion ? nil : Motion.spring, value: store.tasks)
        .contentShape(Rectangle())
        .onTapGesture { onSelect(dayKey) }
        .onHover { hovering = $0 }
        .onDrop(of: [UTType.text], delegate: DayCellDropDelegate(
            store: store,
            drag: drag,
            dayKey: dayKey,
            isTargeted: $dropHovering
        ))
    }

    /// 空白日子几乎不占视觉重量；写过的日子才成为一张纸片。
    @ViewBuilder
    private func cellBackground(hasContent: Bool) -> some View {
        if isToday {
            RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Theme.accentSoft)
        } else if isSelected {
            RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Theme.surface)
        } else if hasContent {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(hovering ? Theme.surface : Theme.surface.opacity(isFuture ? 0.6 : 0.85))
        } else if isFuture {
            // 还没到的日子：整格铺一层淡灰（不描边，免得和有内容的纸片混淆）
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Theme.paperDeep.opacity(hovering ? 0.95 : 0.8))
        } else {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(hovering ? Theme.surface.opacity(0.5) : Color.clear)
        }
    }

    @ViewBuilder
    private func cellBorder(hasContent: Bool) -> some View {
        if isToday {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(Theme.accent, lineWidth: 1.6)
        } else if isSelected {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(Theme.ink3, lineWidth: 1.2)
        } else if hasContent {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(Theme.hairline, lineWidth: 1)
                .opacity(isFuture ? 0.6 : 1)
        }
    }
}

/// 日历格子的投放：把任务拖到某天 = 移到那天。
struct DayCellDropDelegate: DropDelegate {
    let store: TaskStore
    let drag: DragController
    let dayKey: String
    @Binding var isTargeted: Bool

    func dropEntered(info: DropInfo) { isTargeted = drag.draggingId != nil }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        isTargeted = drag.draggingId != nil
        return DropProposal(operation: .move)
    }

    func dropExited(info: DropInfo) { isTargeted = false }

    func performDrop(info: DropInfo) -> Bool {
        isTargeted = false
        guard let draggingId = drag.draggingId else { return false }
        drag.draggingId = nil
        drag.target = nil
        store.requestMoveToDay(draggingId, day: dayKey)
        return true
    }
}

/// 月份标题格式化。
public enum MonthFormat {
    private static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.calendar = Calendar(identifier: .gregorian)
        f.dateFormat = "yyyy 年 M 月"
        return f
    }()

    public static func label(for date: Date) -> String {
        formatter.string(from: date)
    }
}
