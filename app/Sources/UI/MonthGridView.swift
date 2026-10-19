import SwiftUI
import UniformTypeIdentifiers
import Core

/// 月历：细线分栏的版面，有内容的日子整格上色。
public struct MonthGridView: View {
    @EnvironmentObject var store: TaskStore
    /// 普通引用：月历只在事件里读它，不订阅，所以拖动时不会跟着重渲染。
    public let drag: DragController

    public let anchor: Date
    public let onSelect: (String) -> Void

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

    private var range: CalendarRange { store.settings.calendarRange }

    private var cells: [Date] {
        let cal = calendar
        if range == .month {
            guard let monthStart = cal.dateInterval(of: .month, for: anchor)?.start else { return [] }
            let weekday = cal.component(.weekday, from: monthStart)
            let offset = (weekday - cal.firstWeekday + 7) % 7
            guard let start = cal.date(byAdding: .day, value: -offset, to: monthStart) else { return [] }
            return (0..<42).compactMap { cal.date(byAdding: .day, value: $0, to: start) }
        }
        let base = DayKey.date(from: store.selectedDay) ?? anchor
        let weekday = cal.component(.weekday, from: base)
        let offset = (weekday - cal.firstWeekday + 7) % 7
        guard let start = cal.date(byAdding: .day, value: -offset, to: base) else { return [] }
        let count = range == .week ? 7 : 14
        return (0..<count).compactMap { cal.date(byAdding: .day, value: $0, to: start) }
    }

    private var rowCount: Int {
        switch range {
        case .month: return 6
        case .biweek: return 2
        case .week: return 1
        }
    }

    public var body: some View {
        let days = cells
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                ForEach(weekdaySymbols, id: \.self) { symbol in
                    Text(symbol)
                        .font(Theme.mono(9))
                        .tracking(2)
                        .foregroundStyle(Theme.ink3)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.leading, 8)
                }
            }
            .frame(height: 26)

            ForEach(0..<rowCount, id: \.self) { row in
                HStack(spacing: 0) {
                    ForEach(0..<7, id: \.self) { col in
                        let index = row * 7 + col
                        if index < days.count {
                            let date = days[index]
                            DayCellView(
                                drag: drag,
                                dayKey: DayKey.key(for: date),
                                dayNumber: calendar.component(.day, from: date),
                                inMonth: calendar.isDate(date, equalTo: anchor, toGranularity: .month),
                                range: range,
                                onSelect: onSelect
                            )
                        } else {
                            Color.clear.frame(maxWidth: .infinity)
                        }
                    }
                }
                .frame(maxHeight: .infinity)
                .overlay(alignment: .top) {
                    if row > 0 { Rectangle().fill(Theme.rule).frame(height: 0.7) }
                }
            }
        }
    }
}

/// 单个日子格子：有内容 = 一整块颜色；今天 = 最深的一块。
struct DayCellView: View {
    @EnvironmentObject var store: TaskStore
    let drag: DragController

    let dayKey: String
    let dayNumber: Int
    let inMonth: Bool
    let range: CalendarRange
    let onSelect: (String) -> Void

    @State private var hovering = false
    @State private var dropHovering = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var isToday: Bool { dayKey == store.currentDay }
    private var isFuture: Bool { dayKey > store.currentDay }
    private var isSelected: Bool { dayKey == store.selectedDay }

    var body: some View {
        let roots = store.orderedRoots(of: dayKey)
        let all = store.taskCount(on: dayKey)
        let doneCount = store.doneCount(on: dayKey)
        let capacity: Int = range == .week ? 9 : (range == .biweek ? 6 : (hovering ? 6 : 4))
        let shown = Array(roots.prefix(capacity))
        let hasContent = !roots.isEmpty || all > 0
        let allDone = all > 0 && doneCount == all
        let filled = hasContent && !isFuture

        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 5) {
                Text(range == .month ? "\(dayNumber)" : "\(Calendar(identifier: .gregorian).component(.month, from: DayKey.date(from: dayKey) ?? Date()))/\(dayNumber)")
                    .font(Theme.mono(range == .week ? 12 : (isToday ? 10.5 : 10)))
                    .foregroundStyle(isToday ? Theme.todayInk : (isFuture ? Theme.faint : Theme.ink2))
                Spacer(minLength: 0)
                if allDone && !isToday {
                    Image(systemName: "checkmark")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(Theme.doneInk)
                }
            }
            ForEach(shown) { task in
                HStack(alignment: .top, spacing: 5) {
                    if task.isMain {
                        Rectangle()
                            .fill(isToday ? Theme.todayInk : (filled ? Theme.fillInk : Theme.accent))
                            .frame(width: 3, height: 9)
                            .padding(.top, 1)
                    }
                    Text(task.title)
                        .font(task.isMain ? Theme.display(range == .week ? 14 : 12) : Theme.sans(range == .week ? 13 : 11, .medium))
                        .foregroundStyle(
                            isToday ? Theme.todayInk
                                : (filled ? Theme.fillInk : (isFuture ? Theme.faint : Theme.ink2))
                        )
                        .lineLimit(1)
                }
            }
            if roots.count > shown.count {
                Text("+\(roots.count - shown.count)")
                    .font(Theme.mono(8.5))
                    .foregroundStyle(isToday ? Theme.todayInk.opacity(0.7) : Theme.ink3)
                    .padding(.leading, 8)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, range == .week ? 10 : 8)
        .padding(.vertical, range == .week ? 10 : 7)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(
            isToday ? Theme.todayFill
                : (filled ? Theme.fill : (hovering ? Theme.surfaceAlt.opacity(0.45) : Color.clear))
        )
        .overlay(alignment: .leading) {
            Rectangle().fill(Theme.rule).frame(width: 0.7)
        }
        .overlay {
            if dropHovering {
                Rectangle().strokeBorder(Theme.accent, lineWidth: 2)
            } else if isToday {
                Rectangle().strokeBorder(Theme.accent, lineWidth: 1.2)
            } else if isSelected {
                Rectangle().strokeBorder(Theme.ink.opacity(0.45), lineWidth: 1)
            }
        }
        .opacity(inMonth ? 1 : 0.5)
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
