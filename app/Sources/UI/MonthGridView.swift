import SwiftUI
import UniformTypeIdentifiers
import Core

/// 刊眉栏月历（4.0）：密度点阵。只放数字与墨点，不放任务文字——中文永不截断。
/// 今天是唯一的朱砂圈；未到日期压淡（规则 #33）。
public struct MonthGridView: View {
    @EnvironmentObject var store: TaskStore
    /// 普通引用：月历只在事件里读它，不订阅，所以拖动时不会跟着重渲染。
    public let drag: DragController

    public let anchor: Date
    public let onSelect: (String) -> Void

    private let weekdaySymbols = ["一", "二", "三", "四", "五", "六", "日"]
    private let cell: CGFloat = 23
    private let rowGap: CGFloat = 8

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
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 0) {
                ForEach(weekdaySymbols, id: \.self) { symbol in
                    Text(symbol)
                        .font(Theme.mono(8))
                        .tracking(1)
                        .foregroundStyle(Theme.ink3)
                        .frame(width: cell)
                }
            }
            .padding(.bottom, 11)

            VStack(alignment: .leading, spacing: rowGap) {
                ForEach(0..<6, id: \.self) { row in
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
                                    onSelect: onSelect
                                )
                            } else {
                                Color.clear.frame(width: cell, height: cell)
                            }
                        }
                    }
                }
            }
        }
        .frame(width: cell * 7, alignment: .topLeading)
    }
}

/// 单个日子：数字 + 密度墨点。今天＝朱砂圈；全部完成＝空心点。
struct DayCellView: View {
    @EnvironmentObject var store: TaskStore
    let drag: DragController

    let dayKey: String
    let dayNumber: Int
    let inMonth: Bool
    let onSelect: (String) -> Void

    @State private var dropHovering = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var isToday: Bool { dayKey == store.currentDay }
    private var isFuture: Bool { dayKey > store.currentDay }
    private var isSelected: Bool { dayKey == store.selectedDay }
    private var hasContent: Bool { store.taskCount(on: dayKey) > 0 }
    private var allDone: Bool {
        let all = store.taskCount(on: dayKey)
        return all > 0 && store.doneCount(on: dayKey) == all
    }
    /// 过去、且有没做完的事：夜之城给它一枚洋红点（未结）。
    private var hasUnfinished: Bool {
        dayKey < store.currentDay && store.doneCount(on: dayKey) < store.taskCount(on: dayKey)
    }

    var body: some View {
        if Theme.isNight {
            nightCell
        } else {
            rikeCell
        }
    }

    /// 日课格子：数字 + 墨点；今天＝朱砂圈。
    private var rikeCell: some View {
        Text("\(dayNumber)")
            .font(Theme.mono(isToday ? 10.5 : 10, isToday ? .bold : .regular))
            .foregroundStyle(
                isToday ? Theme.todayInk
                    : (isFuture ? Theme.faint.opacity(0.75)
                        : (inMonth ? Theme.ink3 : Theme.faint.opacity(0.4)))
            )
            .frame(width: 23, height: 23)
            .background(alignment: .bottom) {
                if hasContent {
                    Group {
                        if allDone && !isToday {
                            Circle().strokeBorder(Theme.ink3.opacity(0.7), lineWidth: 1)
                                .frame(width: 3.5, height: 3.5)
                        } else {
                            Circle().fill(isFuture ? Theme.faint.opacity(0.5) : Theme.ink3)
                                .frame(width: 3.5, height: 3.5)
                        }
                    }
                    .offset(y: 2)
                }
            }
            .overlay {
                if isToday {
                    Circle()
                        .strokeBorder(Theme.accent, lineWidth: 1)
                        .frame(width: 19, height: 19)
                } else if dropHovering {
                    Circle()
                        .strokeBorder(Theme.accent, lineWidth: 1.4)
                        .frame(width: 19, height: 19)
                } else if isSelected {
                    Rectangle()
                        .fill(Theme.ink2)
                        .frame(width: 12, height: 1)
                        .offset(y: 11)
                }
            }
            .animation(reduceMotion ? nil : Motion.quick, value: dropHovering)
            .animation(reduceMotion ? nil : Motion.quick, value: isSelected)
            .contentShape(Rectangle())
            .onTapGesture { onSelect(dayKey) }
            .onDrop(of: [UTType.text], delegate: DayCellDropDelegate(
                store: store,
                drag: drag,
                dayKey: dayKey,
                isTargeted: $dropHovering
            ))
    }

    /// 夜之城格子：数字 + 青色刻度；今天＝黄色切角块；未结＝洋红点。
    private var nightCell: some View {
        Group {
            if isToday {
                Text("\(dayNumber)")
                    .font(Theme.mono(10.5, .bold))
                    .foregroundStyle(Theme.fillInk)
                    .frame(width: 21, height: 21)
                    .background(Theme.accent)
                    .clipShape(CutCornerShape(radius: 5))
            } else {
                Text("\(dayNumber)")
                    .font(Theme.mono(10.5))
                    .foregroundStyle(
                        isFuture ? Theme.faint.opacity(0.6)
                            : (inMonth ? Theme.ink2 : Theme.faint.opacity(0.3))
                    )
                    .frame(width: 21, height: 21)
                    .background(alignment: .bottom) {
                        if hasContent {
                            Rectangle()
                                .fill(isFuture ? Theme.faint.opacity(0.45) : (allDone ? Theme.ink3.opacity(0.6) : Theme.signal))
                                .frame(width: 8, height: 2.5)
                                .offset(y: 2)
                        }
                    }
                    .overlay(alignment: .topTrailing) {
                        if hasUnfinished {
                            Circle().fill(Theme.warn).frame(width: 4, height: 4).offset(x: 2, y: -1)
                        }
                    }
                    .overlay {
                        if isSelected {
                            Rectangle().fill(Theme.accent).frame(width: 12, height: 1.5).offset(y: 11)
                        } else if dropHovering {
                            CutCornerShape(radius: 4)
                                .stroke(Theme.accent, lineWidth: 1.2)
                                .frame(width: 19, height: 19)
                        }
                    }
            }
        }
        .frame(width: 23, height: 23)
        .animation(reduceMotion ? nil : Motion.quick, value: dropHovering)
        .animation(reduceMotion ? nil : Motion.quick, value: isSelected)
        .contentShape(Rectangle())
        .onTapGesture { onSelect(dayKey) }
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
