import SwiftUI
import Core

/// 年视图：12 个小月历，一眼看到这一年哪几天有主线、哪几天完成了。
public struct YearView: View {
    @EnvironmentObject var store: TaskStore
    let onClose: () -> Void

    public init(onClose: @escaping () -> Void) {
        self.onClose = onClose
    }

    private var year: Int {
        let base = DayKey.date(from: store.currentDay) ?? Date()
        return Calendar(identifier: .gregorian).component(.year, from: base)
    }

    private var cal: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.firstWeekday = 2
        return c
    }

    private struct DayInfo {
        let key: String
        let day: Int
        let inMonth: Bool
        let roots: Int
        let done: Int
        let hasMain: Bool
        let isToday: Bool
    }

    private var index: [String: (roots: Int, done: Int, main: Bool)] {
        var map: [String: (roots: Int, done: Int, main: Bool)] = [:]
        for task in store.tasks {
            var v = map[task.day] ?? (0, 0, false)
            if task.parentId == nil { v.roots += 1 }
            if task.done { v.done += 1 }
            if task.isMain { v.main = true }
            map[task.day] = v
        }
        return map
    }

    public var body: some View {
        ZStack {
            Theme.canvas.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .firstTextBaseline) {
                    Text("FU TODO  /  YEAR \(String(year))").font(Theme.mono(9.5)).tracking(2.2).foregroundStyle(Theme.ink3)
                    Spacer()
                    Text("点任意一天跳到那天 · Esc 退出").font(Theme.mono(8.5)).tracking(1).foregroundStyle(Theme.ink3)
                    Button(action: onClose) {
                        Text("关闭").font(Theme.mono(8.5, .semibold)).tracking(1)
                            .foregroundStyle(Theme.canvas)
                            .padding(.horizontal, 10).padding(.vertical, 4)
                            .background(Rectangle().fill(Theme.ink))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.bottom, 18)

                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 16), count: 4), spacing: 18) {
                    ForEach(1...12, id: \.self) { month in
                        monthBlock(month)
                    }
                }

                Spacer(minLength: 0)

                HStack(spacing: 16) {
                    legend(Theme.todayFill, "今天")
                    legend(Theme.fill, "有主线")
                    legend(Theme.fill.opacity(0.35), "只有支线")
                    legend(Theme.stamp.opacity(0.55), "已完成")
                    Spacer()
                    Text("\(store.tasks.count) 件事 · \(year)").font(Theme.mono(8.5)).tracking(1).foregroundStyle(Theme.ink3)
                }
                .padding(.top, 16)
            }
            .padding(36)
        }
        .onExitCommand(perform: onClose)
        .focusable()
    }

    private func legend(_ color: Color, _ label: String) -> some View {
        HStack(spacing: 6) {
            Rectangle().fill(color).frame(width: 12, height: 10)
                .overlay(Rectangle().strokeBorder(Theme.rule, lineWidth: 0.6))
            Text(label).font(Theme.mono(7.5)).foregroundStyle(Theme.ink3)
        }
    }

    private func monthBlock(_ month: Int) -> some View {
        let days = monthDays(month)
        return VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("\(month) 月").font(Theme.display(17)).foregroundStyle(Theme.ink)
                Text(String(format: "%02d", month)).font(Theme.mono(7)).tracking(1).foregroundStyle(Theme.ink3)
                Spacer()
            }
            HStack(spacing: 0) {
                ForEach(["一", "二", "三", "四", "五", "六", "日"], id: \.self) { w in
                    Text(w).font(Theme.mono(6.5)).foregroundStyle(Theme.ink3)
                        .frame(maxWidth: .infinity)
                }
            }
            VStack(spacing: 2) {
                ForEach(0..<6, id: \.self) { row in
                    HStack(spacing: 2) {
                        ForEach(0..<7, id: \.self) { col in
                            let i = row * 7 + col
                            if i < days.count { cell(days[i]) } else { Color.clear.frame(height: 18) }
                        }
                    }
                }
            }
        }
    }

    private func cell(_ d: DayInfo) -> some View {
        Button {
            store.selectDay(d.key)
            Feedback.open()
            onClose()
        } label: {
            ZStack {
                Rectangle().fill(color(for: d))
                if d.inMonth {
                    Text("\(d.day)")
                        .font(Theme.mono(6.5))
                        .foregroundStyle(d.isToday ? Theme.todayInk : (d.hasMain ? Theme.canvas : (d.roots > 0 ? Theme.ink2 : Theme.ink3)))
                }
            }
            .frame(height: 18)
            .overlay(Rectangle().strokeBorder(d.isToday ? Theme.ink : Theme.rule.opacity(0.35), lineWidth: d.isToday ? 1 : 0.4))
        }
        .buttonStyle(.plain)
        .help(helpText(d))
    }

    private func color(for d: DayInfo) -> Color {
        if d.isToday { return Theme.todayFill }
        if d.hasMain { return Theme.accent }
        if d.done > 0 { return Theme.accent.opacity(0.55) }
        if d.roots > 0 { return Theme.accent.opacity(0.25) }
        return d.inMonth ? Theme.rule.opacity(0.16) : .clear
    }

    private func helpText(_ d: DayInfo) -> String {
        "\(d.key) · \(d.roots) 件\(d.hasMain ? " · 有主线" : "")"
    }

    private func monthDays(_ month: Int) -> [DayInfo] {
        let map = index
        guard let monthStart = cal.date(from: DateComponents(year: year, month: month, day: 1)),
              let interval = cal.dateInterval(of: .month, for: monthStart) else { return [] }
        let weekday = cal.component(.weekday, from: monthStart)
        let offset = (weekday - cal.firstWeekday + 7) % 7
        guard let start = cal.date(byAdding: .day, value: -offset, to: monthStart) else { return [] }
        let today = store.currentDay
        return (0..<42).compactMap { i in
            guard let date = cal.date(byAdding: .day, value: i, to: start) else { return nil }
            let key = DayKey.key(for: date)
            let info = map[key] ?? (0, 0, false)
            return DayInfo(
                key: key,
                day: cal.component(.day, from: date),
                inMonth: cal.isDate(date, equalTo: interval.start, toGranularity: .month),
                roots: info.roots,
                done: info.done,
                hasMain: info.main,
                isToday: key == today
            )
        }
    }
}
