import SwiftUI
import AppKit

// 主题变体：同一套「色块月历 + 满高日页」结构，四套完整的视觉世界。
// 只用于选主题，不接 Theme。

private func thx(_ v: UInt32) -> Color {
    Color(.sRGB,
          red: Double((v >> 16) & 0xFF) / 255,
          green: Double((v >> 8) & 0xFF) / 255,
          blue: Double(v & 0xFF) / 255, opacity: 1)
}
private func tMono(_ s: CGFloat) -> Font { .system(size: s, design: .monospaced) }
private func tBody(_ s: CGFloat, _ w: Font.Weight = .regular) -> Font { .system(size: s, weight: w) }

enum DisplayFace { case serif, grotesque }

struct SpreadTheme {
    let id: String
    let name: String
    let note: String
    let canvas: UInt32
    let ink: UInt32
    let fill: UInt32
    let fillInk: UInt32
    let rule: Color
    let todayFill: UInt32
    let todayInk: UInt32
    let accent: UInt32
    let face: DisplayFace

    func display(_ size: CGFloat, _ bold: Bool = true) -> Font {
        switch face {
        case .serif:
            return .custom(bold ? "Songti SC Bold" : "Songti SC", size: size)
        case .grotesque:
            return .system(size: size, weight: bold ? .black : .heavy)
        }
    }

    var canvasC: Color { thx(canvas) }
    var inkC: Color { thx(ink) }
    var fillC: Color { thx(fill) }
    var fillInkC: Color { thx(fillInk) }
    var todayFillC: Color { thx(todayFill) }
    var todayInkC: Color { thx(todayInk) }
    var accentC: Color { thx(accent) }

    static let atelier = SpreadTheme(
        id: "atelier", name: "器物 / Atelier", note: "奶油纸、宋体、赭红整页",
        canvas: 0xF2EEE3, ink: 0x14231D, fill: 0xB4432A, fillInk: 0xF6EFE2,
        rule: thx(0x14231D).opacity(0.20), todayFill: 0x14231D, todayInk: 0xF2EEE3,
        accent: 0xC8A24A, face: .serif
    )
    static let archive = SpreadTheme(
        id: "archive", name: "档案 / Archive", note: "近黑、酸柠、重黑体、档案编号",
        canvas: 0x0A0B08, ink: 0xEDEDE0, fill: 0xC8FF00, fillInk: 0x0A0B08,
        rule: thx(0xEDEDE0).opacity(0.16), todayFill: 0xEDEDE0, todayInk: 0x0A0B08,
        accent: 0xC8FF00, face: .grotesque
    )
    static let chronos = SpreadTheme(
        id: "chronos", name: "天文台 / Chronos", note: "黑、金、衬线、刻度与仪表",
        canvas: 0x0A0A08, ink: 0xEDE6D6, fill: 0xC8A24A, fillInk: 0x0A0A08,
        rule: thx(0xEDE6D6).opacity(0.14), todayFill: 0xEDE6D6, todayInk: 0x0A0A08,
        accent: 0xC8A24A, face: .serif
    )
    static let acid = SpreadTheme(
        id: "acid", name: "酸纸 / Acid", note: "荧光底、巨黑字、黑色整页",
        canvas: 0xE7F86B, ink: 0x11140F, fill: 0x11140F, fillInk: 0xE7F86B,
        rule: thx(0x11140F).opacity(0.22), todayFill: 0x11140F, todayInk: 0xE7F86B,
        accent: 0x11140F, face: .grotesque
    )
    static let all: [SpreadTheme] = [.atelier, .archive, .chronos, .acid]
}

private struct TDay {
    let n: Int
    let main: String?
    let branches: Int
    let today: Bool
    let dim: Bool
}

struct ThemeSpread: View {
    let theme: SpreadTheme

    private let days: [TDay] = [
        TDay(n: 28, main: nil, branches: 0, today: false, dim: true),
        TDay(n: 29, main: "备份照片", branches: 0, today: false, dim: true),
        TDay(n: 30, main: nil, branches: 0, today: false, dim: true),
        TDay(n: 1, main: nil, branches: 0, today: false, dim: true),
        TDay(n: 2, main: "学习 SwiftUI 布局", branches: 1, today: false, dim: true),
        TDay(n: 3, main: nil, branches: 0, today: false, dim: true),
        TDay(n: 4, main: nil, branches: 0, today: false, dim: true),
        TDay(n: 5, main: "整理上周会议记录", branches: 2, today: false, dim: false),
        TDay(n: 6, main: "读完《卡片笔记写作法》", branches: 0, today: false, dim: false),
        TDay(n: 7, main: "整理收件箱", branches: 0, today: false, dim: false),
        TDay(n: 8, main: "写完产品原型说明", branches: 3, today: true, dim: false),
        TDay(n: 9, main: nil, branches: 0, today: false, dim: false),
        TDay(n: 10, main: nil, branches: 0, today: false, dim: false),
        TDay(n: 11, main: nil, branches: 0, today: false, dim: false),
        TDay(n: 12, main: "下周开始整理照片", branches: 1, today: false, dim: false),
        TDay(n: 13, main: nil, branches: 0, today: false, dim: false),
        TDay(n: 14, main: nil, branches: 0, today: false, dim: false),
        TDay(n: 15, main: nil, branches: 0, today: false, dim: false),
        TDay(n: 16, main: nil, branches: 0, today: false, dim: false),
        TDay(n: 17, main: nil, branches: 0, today: false, dim: false),
        TDay(n: 18, main: nil, branches: 0, today: false, dim: false),
        TDay(n: 19, main: nil, branches: 0, today: false, dim: false),
        TDay(n: 20, main: nil, branches: 0, today: false, dim: false),
        TDay(n: 21, main: nil, branches: 0, today: false, dim: false),
        TDay(n: 22, main: nil, branches: 0, today: false, dim: false),
        TDay(n: 23, main: nil, branches: 0, today: false, dim: false),
        TDay(n: 24, main: nil, branches: 0, today: false, dim: false),
        TDay(n: 25, main: "项目复盘", branches: 2, today: false, dim: false),
        TDay(n: 26, main: nil, branches: 0, today: false, dim: false),
        TDay(n: 27, main: nil, branches: 0, today: false, dim: false),
        TDay(n: 28, main: nil, branches: 0, today: false, dim: false),
        TDay(n: 29, main: nil, branches: 0, today: false, dim: false),
        TDay(n: 30, main: nil, branches: 0, today: false, dim: false),
        TDay(n: 31, main: nil, branches: 0, today: false, dim: false),
        TDay(n: 1, main: nil, branches: 0, today: false, dim: false),
        TDay(n: 2, main: nil, branches: 0, today: false, dim: false),
        TDay(n: 3, main: nil, branches: 0, today: false, dim: false),
        TDay(n: 4, main: nil, branches: 0, today: false, dim: false),
        TDay(n: 5, main: nil, branches: 0, today: false, dim: false),
        TDay(n: 6, main: nil, branches: 0, today: false, dim: false),
        TDay(n: 7, main: nil, branches: 0, today: false, dim: false),
        TDay(n: 8, main: nil, branches: 0, today: false, dim: false),
    ]

    var body: some View {
        HStack(spacing: 0) {
            VStack(spacing: 0) {
                masthead
                weekdayRow
                calendar
            }
            .frame(maxWidth: .infinity)
            .background(theme.canvasC)

            sheet.frame(width: 470)
        }
        .frame(width: 1200, height: 760)
        .background(theme.canvasC)
    }

    private var masthead: some View {
        HStack(alignment: .bottom, spacing: 14) {
            VStack(alignment: .leading, spacing: 0) {
                Text("2026  ·  \(theme.id.uppercased())").font(tMono(9)).tracking(2.5).foregroundStyle(theme.inkC.opacity(0.5))
                Text("十月")
                    .font(theme.display(64))
                    .tracking(theme.face == .grotesque ? -2 : 0)
                    .foregroundStyle(theme.inkC)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("‹   ›").font(tMono(11)).foregroundStyle(theme.inkC.opacity(0.6))
                Text("今天").font(tMono(9)).tracking(1).foregroundStyle(theme.inkC.opacity(0.6))
            }
            .padding(.bottom, 8)
            Spacer()
            VStack(alignment: .trailing, spacing: 3) {
                Text("未完成 07 / 已结束").font(tMono(8.5)).tracking(1.4).foregroundStyle(theme.inkC.opacity(0.45))
                Text("使用说明   设置").font(tBody(10)).foregroundStyle(theme.inkC.opacity(0.6))
            }
            .padding(.bottom, 8)
        }
        .padding(.horizontal, 22)
        .padding(.top, 20)
        .frame(height: 108)
    }

    private var weekdayRow: some View {
        HStack(spacing: 0) {
            ForEach(["一", "二", "三", "四", "五", "六", "日"], id: \.self) { w in
                Text(w).font(tMono(9)).tracking(2).foregroundStyle(theme.inkC.opacity(0.45))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading, 8)
            }
        }
        .frame(height: 24)
        .padding(.horizontal, 22)
    }

    private var calendar: some View {
        VStack(spacing: 0) {
            ForEach(0..<6, id: \.self) { row in
                HStack(spacing: 0) {
                    ForEach(0..<7, id: \.self) { col in
                        let i = row * 7 + col
                        if i < days.count { cell(days[i]) } else { Color.clear }
                    }
                }
                .frame(maxHeight: .infinity)
                .overlay(alignment: .top) {
                    if row > 0 { Rectangle().fill(theme.rule).frame(height: 0.7) }
                }
            }
        }
        .padding(.horizontal, 22)
        .padding(.bottom, 20)
    }

    private func cell(_ d: TDay) -> some View {
        let filled = d.main != nil && !d.today && !d.dim
        let titleColor = d.today ? theme.todayInkC : (filled ? theme.fillInkC : theme.inkC.opacity(d.dim ? 0.35 : 0.85))
        return VStack(alignment: .leading, spacing: 3) {
            Text("\(d.n)")
                .font(tMono(d.today ? 11 : 10))
                .foregroundStyle(d.today ? theme.todayInkC : theme.inkC.opacity(d.dim ? 0.3 : 0.5))
            if let main = d.main {
                Text(main)
                    .font(d.today ? theme.display(13) : tBody(11.5, .medium))
                    .tracking(theme.face == .grotesque && d.today ? -0.5 : 0)
                    .foregroundStyle(titleColor)
                    .lineLimit(2)
                    .padding(.top, 1)
            }
            Spacer(minLength: 0)
            if d.branches > 0 {
                VStack(alignment: .leading, spacing: 3) {
                    ForEach(0..<min(d.branches, 3), id: \.self) { _ in
                        Rectangle()
                            .fill(d.today ? theme.todayInkC.opacity(0.45)
                                  : (filled ? theme.fillInkC.opacity(0.55) : theme.fillC.opacity(0.65)))
                            .frame(width: 26, height: 1.4)
                    }
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(
            d.today ? theme.todayFillC : (filled ? theme.fillC : Color.clear)
        )
        .overlay(alignment: .leading) {
            Rectangle().fill(theme.rule).frame(width: 0.7)
        }
    }

    private var sheet: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("THURSDAY / OCT 08").font(tMono(9)).tracking(2.2).foregroundStyle(theme.fillInkC.opacity(0.65))
                Spacer()
                Text("●  LIVE").font(tMono(8.5)).tracking(1.6).foregroundStyle(theme.fillInkC.opacity(0.9))
            }
            .padding(.top, 26)

            Text("08")
                .font(theme.display(104))
                .tracking(theme.face == .grotesque ? -4 : 0)
                .foregroundStyle(theme.fillInkC)
                .padding(.top, 4)
            Text("十月 · 星期四").font(tMono(10)).tracking(2).foregroundStyle(theme.fillInkC.opacity(0.65))
                .padding(.top, -2)

            Rectangle().fill(theme.fillInkC.opacity(0.28)).frame(height: 0.8).padding(.top, 22)

            Text("今日主线").font(tMono(8.5)).tracking(2.2).foregroundStyle(theme.fillInkC.opacity(0.55))
                .padding(.top, 18)
            Text("写完产品原型说明")
                .font(theme.display(34))
                .tracking(theme.face == .grotesque ? -1.5 : 0)
                .foregroundStyle(theme.fillInkC)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 6)

            Text("今日支线").font(tMono(8.5)).tracking(2.2).foregroundStyle(theme.fillInkC.opacity(0.55))
                .padding(.top, 24)
            VStack(spacing: 0) {
                ForEach(["回一封邮件", "整理本月会议记录"], id: \.self) { t in
                    HStack(spacing: 10) {
                        Rectangle().fill(theme.fillInkC.opacity(0.55)).frame(width: 14, height: 1)
                        Text(t).font(tBody(14)).foregroundStyle(theme.fillInkC.opacity(0.92))
                        Spacer()
                    }
                    .frame(height: 42)
                    .overlay(alignment: .bottom) {
                        Rectangle().fill(theme.fillInkC.opacity(0.16)).frame(height: 0.7)
                    }
                }
            }
            .padding(.top, 2)

            Text("今日完成").font(tMono(8.5)).tracking(2.2).foregroundStyle(theme.fillInkC.opacity(0.45))
                .padding(.top, 20)
            HStack(spacing: 10) {
                Text("✓").font(tBody(11, .bold)).foregroundStyle(theme.fillInkC.opacity(0.55))
                Text("把今天的截图归档").font(tBody(13)).strikethrough().foregroundStyle(theme.fillInkC.opacity(0.5))
            }
            .padding(.top, 8)

            Spacer(minLength: 0)

            HStack {
                Text("＋ 写下一件事").font(tBody(14, .medium)).foregroundStyle(theme.fillInkC)
                Spacer()
                Text("⏎").font(tMono(11)).foregroundStyle(theme.fillInkC.opacity(0.5))
            }
            .frame(height: 54)
            .overlay(alignment: .top) { Rectangle().fill(theme.fillInkC.opacity(0.3)).frame(height: 0.8) }
        }
        .padding(.horizontal, 30)
        .padding(.bottom, 22)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(theme.fillC)
    }
}
