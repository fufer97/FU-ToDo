import SwiftUI
import AppKit

// 「一整页」激进稿：整窗色域 + 满高日页 + 档案式月历。
// 只用于看方向，不接 Theme。

private func rhx(_ v: UInt32) -> Color {
    Color(.sRGB,
          red: Double((v >> 16) & 0xFF) / 255,
          green: Double((v >> 8) & 0xFF) / 255,
          blue: Double(v & 0xFF) / 255, opacity: 1)
}
private func rSerif(_ s: CGFloat, _ bold: Bool = false) -> Font {
    .custom(bold ? "Songti SC Bold" : "Songti SC", size: s)
}
private func rSans(_ s: CGFloat, _ w: Font.Weight = .regular) -> Font {
    .system(size: s, weight: w)
}
private func rMono(_ s: CGFloat) -> Font { .system(size: s, design: .monospaced) }

private struct RadicalPalette {
    let night: Bool
    var canvas: Color { night ? rhx(0x0F1F18) : rhx(0xF2EEE3) }
    var ink: Color { night ? rhx(0xF3EDDD) : rhx(0x14231D) }
    var sheet: Color { night ? rhx(0xF3EDDD) : rhx(0xB4432A) }
    var sheetInk: Color { night ? rhx(0x14231D) : rhx(0xF6EFE2) }
    var rule: Color { night ? rhx(0xF3EDDD).opacity(0.16) : rhx(0x14231D).opacity(0.20) }
    var todayFill: Color { night ? rhx(0xC8F45A) : rhx(0x14231D) }
    var todayInk: Color { night ? rhx(0x0F1F18) : rhx(0xF2EEE3) }
    var accent: Color { night ? rhx(0xC8F45A) : rhx(0xC8A24A) }
    var faint: Color { night ? rhx(0xF3EDDD).opacity(0.45) : rhx(0x14231D).opacity(0.45) }
}

private struct RadicalDay {
    let n: Int
    let main: String?
    let branches: Int
    let today: Bool
    let dim: Bool
}

struct RadicalSpread: View {
    let night: Bool
    var mosaic: Bool = false
    private var p: RadicalPalette { RadicalPalette(night: night) }

    private let days: [RadicalDay] = [
        RadicalDay(n: 28, main: nil, branches: 0, today: false, dim: true),
        RadicalDay(n: 29, main: "备份照片", branches: 0, today: false, dim: true),
        RadicalDay(n: 30, main: nil, branches: 0, today: false, dim: true),
        RadicalDay(n: 1, main: nil, branches: 0, today: false, dim: true),
        RadicalDay(n: 2, main: "学习 SwiftUI 布局", branches: 1, today: false, dim: true),
        RadicalDay(n: 3, main: nil, branches: 0, today: false, dim: true),
        RadicalDay(n: 4, main: nil, branches: 0, today: false, dim: true),
        RadicalDay(n: 5, main: "整理上周会议记录", branches: 2, today: false, dim: false),
        RadicalDay(n: 6, main: "读完《卡片笔记写作法》", branches: 0, today: false, dim: false),
        RadicalDay(n: 7, main: "整理收件箱", branches: 0, today: false, dim: false),
        RadicalDay(n: 8, main: "写完产品原型说明", branches: 3, today: true, dim: false),
        RadicalDay(n: 9, main: nil, branches: 0, today: false, dim: false),
        RadicalDay(n: 10, main: nil, branches: 0, today: false, dim: false),
        RadicalDay(n: 11, main: nil, branches: 0, today: false, dim: false),
        RadicalDay(n: 12, main: "下周开始整理照片", branches: 1, today: false, dim: false),
        RadicalDay(n: 13, main: nil, branches: 0, today: false, dim: false),
        RadicalDay(n: 14, main: nil, branches: 0, today: false, dim: false),
        RadicalDay(n: 15, main: nil, branches: 0, today: false, dim: false),
        RadicalDay(n: 16, main: nil, branches: 0, today: false, dim: false),
        RadicalDay(n: 17, main: nil, branches: 0, today: false, dim: false),
        RadicalDay(n: 18, main: nil, branches: 0, today: false, dim: false),
        RadicalDay(n: 19, main: nil, branches: 0, today: false, dim: false),
        RadicalDay(n: 20, main: nil, branches: 0, today: false, dim: false),
        RadicalDay(n: 21, main: nil, branches: 0, today: false, dim: false),
        RadicalDay(n: 22, main: nil, branches: 0, today: false, dim: false),
        RadicalDay(n: 23, main: nil, branches: 0, today: false, dim: false),
        RadicalDay(n: 24, main: nil, branches: 0, today: false, dim: false),
        RadicalDay(n: 25, main: "项目复盘", branches: 2, today: false, dim: false),
        RadicalDay(n: 26, main: nil, branches: 0, today: false, dim: false),
        RadicalDay(n: 27, main: nil, branches: 0, today: false, dim: false),
        RadicalDay(n: 28, main: nil, branches: 0, today: false, dim: false),
        RadicalDay(n: 29, main: nil, branches: 0, today: false, dim: false),
        RadicalDay(n: 30, main: nil, branches: 0, today: false, dim: false),
        RadicalDay(n: 31, main: nil, branches: 0, today: false, dim: false),
        RadicalDay(n: 1, main: nil, branches: 0, today: false, dim: false),
        RadicalDay(n: 2, main: nil, branches: 0, today: false, dim: false),
        RadicalDay(n: 3, main: nil, branches: 0, today: false, dim: false),
        RadicalDay(n: 4, main: nil, branches: 0, today: false, dim: false),
        RadicalDay(n: 5, main: nil, branches: 0, today: false, dim: false),
        RadicalDay(n: 6, main: nil, branches: 0, today: false, dim: false),
        RadicalDay(n: 7, main: nil, branches: 0, today: false, dim: false),
        RadicalDay(n: 8, main: nil, branches: 0, today: false, dim: false),
    ]

    var body: some View {
        HStack(spacing: 0) {
            VStack(spacing: 0) {
                masthead
                HStack(spacing: 0) {
                    ForEach(["一", "二", "三", "四", "五", "六", "日"], id: \.self) { w in
                        Text(w).font(rMono(9)).tracking(2).foregroundStyle(p.faint)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.leading, 8)
                    }
                }
                .frame(height: 24)
                .padding(.horizontal, 22)
                calendar
            }
            .frame(maxWidth: .infinity)
            .background(p.canvas)

            sheet.frame(width: 470)
        }
        .frame(width: 1200, height: 760)
        .background(p.canvas)
    }

    private var masthead: some View {
        HStack(alignment: .bottom, spacing: 14) {
            VStack(alignment: .leading, spacing: 0) {
                Text("2026").font(rMono(10)).tracking(3).foregroundStyle(p.faint)
                Text("十月").font(rSerif(64, true)).foregroundStyle(p.ink)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text("‹  ›").font(rMono(11)).foregroundStyle(p.ink.opacity(0.6))
                Text("今天").font(rMono(9)).tracking(1).foregroundStyle(p.ink.opacity(0.6))
            }
            .padding(.bottom, 8)
            Spacer()
            VStack(alignment: .trailing, spacing: 3) {
                Text("未完成 07 / 已结束").font(rMono(8.5)).tracking(1.5).foregroundStyle(p.faint)
                Text("使用说明  设置").font(rSans(10)).foregroundStyle(p.ink.opacity(0.65))
            }
            .padding(.bottom, 8)
        }
        .padding(.horizontal, 22)
        .padding(.top, 20)
        .frame(height: 108)
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
                    if row > 0 { Rectangle().fill(p.rule).frame(height: 0.7) }
                }
            }
        }
        .padding(.horizontal, 22)
        .padding(.bottom, 20)
    }

    private func cell(_ d: RadicalDay) -> some View {
        let filled = mosaic && d.main != nil && !d.today && !d.dim
        let titleColor = d.today ? p.todayInk : (filled ? p.sheetInk : (d.dim ? p.faint : p.ink))
        return VStack(alignment: .leading, spacing: 3) {
            Text("\(d.n)")
                .font(rMono(d.today ? 11 : 10))
                .foregroundStyle(d.today ? p.todayInk : (d.dim ? p.faint : p.ink.opacity(0.6)))
            if let main = d.main {
                Text(main)
                    .font(rSerif(12.5, !d.today))
                    .foregroundStyle(titleColor)
                    .lineLimit(2)
                    .padding(.top, 1)
            }
            Spacer(minLength: 0)
            if d.branches > 0 {
                VStack(alignment: .leading, spacing: 3) {
                    ForEach(0..<min(d.branches, 3), id: \.self) { _ in
                        Rectangle()
                            .fill(d.today ? p.todayInk.opacity(0.45)
                                  : (filled ? p.sheetInk.opacity(0.5) : p.sheet.opacity(d.dim ? 0.35 : 0.75)))
                            .frame(width: 26, height: 1.4)
                    }
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(
            d.today ? p.todayFill
                : (filled ? p.sheet.opacity(d.dim ? 0.28 : 0.92) : Color.clear)
        )
        .overlay(alignment: .leading) {
            Rectangle().fill(p.rule).frame(width: 0.7)
        }
    }

    private var sheet: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("THURSDAY / OCT 08").font(rMono(9)).tracking(2.2).foregroundStyle(p.sheetInk.opacity(0.65))
                Spacer()
                Text("●  LIVE").font(rMono(8.5)).tracking(1.6).foregroundStyle(p.accent)
            }
            .padding(.top, 26)

            Text("08").font(rSerif(104, true)).foregroundStyle(p.sheetInk)
                .padding(.top, 6)
            Text("十月 · 星期四").font(rMono(10)).tracking(2).foregroundStyle(p.sheetInk.opacity(0.7))
                .padding(.top, -4)

            Rectangle().fill(p.sheetInk.opacity(0.28)).frame(height: 0.8).padding(.top, 24)

            Text("今日主线").font(rMono(8.5)).tracking(2.2).foregroundStyle(p.sheetInk.opacity(0.55))
                .padding(.top, 20)
            Text("写完产品原型说明")
                .font(rSerif(34, true))
                .foregroundStyle(p.sheetInk)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 6)

            Text("今日支线").font(rMono(8.5)).tracking(2.2).foregroundStyle(p.sheetInk.opacity(0.55))
                .padding(.top, 26)
            VStack(spacing: 0) {
                ForEach(["回一封邮件", "整理本月会议记录"], id: \.self) { t in
                    HStack(spacing: 10) {
                        Rectangle().fill(p.sheetInk.opacity(0.55)).frame(width: 14, height: 1)
                        Text(t).font(rSans(14)).foregroundStyle(p.sheetInk.opacity(0.92))
                        Spacer()
                    }
                    .frame(height: 42)
                    .overlay(alignment: .bottom) {
                        Rectangle().fill(p.sheetInk.opacity(0.16)).frame(height: 0.7)
                    }
                }
            }
            .padding(.top, 2)

            Text("今日完成").font(rMono(8.5)).tracking(2.2).foregroundStyle(p.sheetInk.opacity(0.45))
                .padding(.top, 22)
            HStack(spacing: 10) {
                Text("✓").font(rSans(11, .bold)).foregroundStyle(p.sheetInk.opacity(0.55))
                Text("把今天的截图归档").font(rSans(13)).strikethrough().foregroundStyle(p.sheetInk.opacity(0.5))
            }
            .padding(.top, 8)

            Spacer(minLength: 0)

            HStack {
                Text("＋ 写下一件事").font(rSans(14, .medium)).foregroundStyle(p.sheetInk)
                Spacer()
                Text("⏎").font(rMono(11)).foregroundStyle(p.sheetInk.opacity(0.5))
            }
            .padding(.top, 14)
            .frame(height: 54)
            .overlay(alignment: .top) { Rectangle().fill(p.sheetInk.opacity(0.3)).frame(height: 0.8) }
        }
        .padding(.horizontal, 30)
        .padding(.bottom, 22)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(p.sheet)
    }
}
