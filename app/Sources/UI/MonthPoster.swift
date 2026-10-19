import SwiftUI
import AppKit
import Core

/// 月度海报：把一个月导出成一张可打印/分享的图。
public struct MonthPosterView: View {
    let year: Int
    let month: Int
    let days: [PosterDay]

    public init(year: Int, month: Int, days: [PosterDay]) {
        self.year = year
        self.month = month
        self.days = days
    }

    private var cal: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.firstWeekday = 2
        return c
    }

    private var monthName: String {
        let names = ["一月", "二月", "三月", "四月", "五月", "六月", "七月", "八月", "九月", "十月", "十一月", "十二月"]
        return names[max(0, min(11, month - 1))]
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text("FU TODO  /  MONTHLY SPECIMEN").font(Theme.mono(11)).tracking(2.4).foregroundStyle(Theme.ink3)
                Spacer()
                Text("\(year)  ·  \(String(format: "%02d", month))").font(Theme.mono(11)).tracking(2).foregroundStyle(Theme.ink3)
            }
            .padding(.bottom, 26)

            HStack(alignment: .firstTextBaseline, spacing: 22) {
                Text(monthName)
                    .font(Theme.display(150))
                    .tracking(Theme.displayTracking(150))
                    .foregroundStyle(Theme.ink)
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text("一天一件").font(Theme.mono(10)).tracking(2).foregroundStyle(Theme.ink2)
                    Text("ONE THING A DAY").font(Theme.mono(8.5)).tracking(2).foregroundStyle(Theme.ink3)
                }
                .padding(.bottom, 24)
            }

            HStack(spacing: 0) {
                ForEach(["一", "二", "三", "四", "五", "六", "日"], id: \.self) { w in
                    Text(w).font(Theme.mono(9)).tracking(1.4).foregroundStyle(Theme.ink3)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.leading, 8)
                }
            }
            .frame(height: 24)

            VStack(spacing: 0) {
                ForEach(0..<6, id: \.self) { row in
                    HStack(spacing: 0) {
                        ForEach(0..<7, id: \.self) { col in
                            let i = row * 7 + col
                            if i < days.count { cell(days[i]) } else { Color.clear.frame(maxWidth: .infinity) }
                        }
                    }
                    .frame(maxHeight: .infinity)
                    .overlay(alignment: .top) {
                        if row > 0 { Rectangle().fill(Theme.rule).frame(height: 0.7) }
                    }
                }
            }
            .frame(maxHeight: .infinity)

            Rectangle().fill(Theme.rule).frame(height: 0.8)
            HStack {
                Text("写完这一页，剩下的交给明天。").font(Theme.display(22)).foregroundStyle(Theme.ink)
                Spacer()
                Text("FU TODO 2.0").font(Theme.mono(9)).tracking(1.6).foregroundStyle(Theme.ink3)
            }
            .padding(.top, 14)
        }
        .padding(64)
        .frame(width: 1200, height: 1600, alignment: .topLeading)
        .background(Theme.canvas)
    }

    private func cell(_ d: PosterDay) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("\(d.day)")
                    .font(Theme.mono(d.isToday ? 11 : 10))
                    .foregroundStyle(d.isToday ? Theme.todayInk : (d.hasContent ? Theme.fillInk : Theme.ink3))
                Spacer()
                if d.done > 0 { Text("✓").font(Theme.mono(8)).foregroundStyle(d.isToday ? Theme.todayInk : Theme.fillInk) }
            }
            if let main = d.mainTitle {
                Text(main)
                    .font(Theme.display(13))
                    .foregroundStyle(d.isToday ? Theme.todayInk : Theme.fillInk)
                    .lineLimit(2)
            }
            if d.roots > 0 {
                Text("\(d.roots) 件").font(Theme.mono(7.5))
                    .foregroundStyle((d.isToday ? Theme.todayInk : Theme.fillInk).opacity(0.7))
            }
            Spacer(minLength: 0)
        }
        .padding(8)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(
            d.isToday ? Theme.todayFill : (d.hasContent ? Theme.fill : Color.clear)
        )
        .overlay(alignment: .leading) { Rectangle().fill(Theme.rule).frame(width: 0.7) }
        .opacity(d.inMonth ? 1 : 0.35)
    }
}

public struct PosterDay {
    public let key: String
    public let day: Int
    public let inMonth: Bool
    public let roots: Int
    public let done: Int
    public let hasContent: Bool
    public let isToday: Bool
    public let mainTitle: String?

    public init(key: String, day: Int, inMonth: Bool, roots: Int, done: Int, hasContent: Bool, isToday: Bool, mainTitle: String?) {
        self.key = key
        self.day = day
        self.inMonth = inMonth
        self.roots = roots
        self.done = done
        self.hasContent = hasContent
        self.isToday = isToday
        self.mainTitle = mainTitle
    }
}

@MainActor
public enum PosterBuilder {
    public static func build(store: TaskStore) -> (year: Int, month: Int, days: [PosterDay])? {
        let day = DayKey.date(from: store.selectedDay) ?? Date()
        let cal = Calendar(identifier: .gregorian)
        let year = cal.component(.year, from: day)
        let month = cal.component(.month, from: day)

        var map: [String: (roots: Int, done: Int, main: String?)] = [:]
        for t in store.tasks {
            var v = map[t.day] ?? (0, 0, nil)
            if t.parentId == nil { v.roots += 1 }
            if t.done { v.done += 1 }
            if t.isMain { v.main = t.title }
            map[t.day] = v
        }

        var monthCal = cal
        monthCal.firstWeekday = 2
        guard let monthStart = monthCal.date(from: DateComponents(year: year, month: month, day: 1)),
              let interval = monthCal.dateInterval(of: .month, for: monthStart) else { return nil }
        let weekday = monthCal.component(.weekday, from: monthStart)
        let offset = (weekday - monthCal.firstWeekday + 7) % 7
        guard let start = monthCal.date(byAdding: .day, value: -offset, to: monthStart) else { return nil }

        let days: [PosterDay] = (0..<42).compactMap { i in
            guard let date = monthCal.date(byAdding: .day, value: i, to: start) else { return nil }
            let key = DayKey.key(for: date)
            let info = map[key] ?? (0, 0, nil)
            return PosterDay(
                key: key,
                day: monthCal.component(.day, from: date),
                inMonth: monthCal.isDate(date, equalTo: interval.start, toGranularity: .month),
                roots: info.roots,
                done: info.done,
                hasContent: info.roots > 0,
                isToday: key == store.currentDay,
                mainTitle: info.main
            )
        }
        return (year, month, days)
    }
}

@MainActor
enum PosterExporter {
    static func export(store: TaskStore) {
        guard let built = PosterBuilder.build(store: store) else { return }
        let year = built.year, month = built.month, days = built.days

        let panel = NSSavePanel()
        panel.nameFieldStringValue = "FU ToDo 海报-\(year)-\(String(format: "%02d", month)).png"
        panel.allowedContentTypes = [.png]
        panel.canCreateDirectories = true
        guard panel.runModal() == .OK, let url = panel.url else { return }

        let view = MonthPosterView(year: year, month: month, days: days)
        let size = NSSize(width: 1200, height: 1600)
        let hosting = NSHostingView(rootView: view)
        hosting.frame = NSRect(origin: .zero, size: size)
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.contentView = hosting
        window.isReleasedWhenClosed = false
        window.orderBack(nil)
        hosting.layoutSubtreeIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.3))
        guard let rep = hosting.bitmapImageRepForCachingDisplay(in: hosting.bounds) else {
            store.toast = "海报导出失败：无法创建位图"
            return
        }
        hosting.cacheDisplay(in: hosting.bounds, to: rep)
        window.orderOut(nil)
        window.contentView = nil
        guard let data = rep.representation(using: .png, properties: [:]) else {
            store.toast = "海报导出失败：无法生成 PNG"
            return
        }
        do {
            try data.write(to: url, options: .atomic)
            store.toast = "本月海报已导出：\(url.lastPathComponent)"
            store.toastHasUndo = false
            Feedback.complete()
        } catch {
            store.toast = "海报导出失败：\(error.localizedDescription)"
        }
    }
}
