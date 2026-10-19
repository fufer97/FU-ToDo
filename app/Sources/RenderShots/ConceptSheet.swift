import SwiftUI
import AppKit

// 设计校准第二版：把「画布 / 夜航」落到主界面构图上。
// 只用于看方向，不接 Theme、不参与正式界面。

private func hx2(_ v: UInt32) -> Color {
    Color(.sRGB,
          red: Double((v >> 16) & 0xFF) / 255,
          green: Double((v >> 8) & 0xFF) / 255,
          blue: Double(v & 0xFF) / 255,
          opacity: 1)
}

private func cSerif(_ size: CGFloat, _ bold: Bool = false) -> Font {
    .custom(bold ? "Songti SC Bold" : "Songti SC", size: size)
}
private func cBody(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
    .system(size: size, weight: weight)
}
private func cMono(_ size: CGFloat) -> Font { .system(size: size, design: .monospaced) }

private struct Canvas2 {
    let dark: Bool
    var canvas: Color { dark ? hx2(0x121310) : hx2(0xF7F3E8) }
    var canvasDeep: Color { dark ? hx2(0x0D0E0B) : hx2(0xEFE9DA) }
    var surface: Color { dark ? hx2(0x1B1D18) : hx2(0xFFFCF4) }
    var surfaceAlt: Color { dark ? hx2(0x232620) : hx2(0xEFE9DA) }
    var rule: Color { dark ? hx2(0x2F332B) : hx2(0xDCD3C0) }
    var ruleSoft: Color { dark ? hx2(0x24271F) : hx2(0xE8E1D1) }
    var ink: Color { dark ? hx2(0xECE8DC) : hx2(0x26302B) }
    var ink2: Color { dark ? hx2(0xA9A79B) : hx2(0x59635C) }
    var ink3: Color { dark ? hx2(0x7B7D72) : hx2(0x8B9089) }
    var faint: Color { dark ? hx2(0x55584E) : hx2(0xB3B5AA) }
    var accent: Color { dark ? hx2(0x8FAEB4) : hx2(0x2E4E5B) }
    var accentSoft: Color { dark ? hx2(0x1F2A29) : hx2(0xDEE9E6) }
    var done: Color { dark ? hx2(0x93B4A0) : hx2(0x6E8B7B) }
    var action: Color { dark ? hx2(0xECE8DC) : hx2(0x1E2420) }
    var actionInk: Color { dark ? hx2(0x121310) : hx2(0xF7F3E8) }
    var sky: Color { dark ? hx2(0x39464A) : hx2(0x9BA7A9) }
    var peach: Color { dark ? hx2(0x5B4634) : hx2(0xF1D4B3) }
    var rose: Color { dark ? hx2(0x4E3E3B) : hx2(0xD4BDA9) }
    var sage: Color { dark ? hx2(0x424B42) : hx2(0xB6B9B2) }
    var sand: Color { dark ? hx2(0x5C4D3C) : hx2(0xE0C9AF) }
    var slate: Color { dark ? hx2(0x334246) : hx2(0x829598) }
}

/// 纸/油画颗粒。
private struct Grain2: View {
    let dark: Bool
    var body: some View {
        Canvas { ctx, size in
            var seed: UInt64 = 0x9E37_79B9_7F4A_7C15
            func rnd() -> Double {
                seed = seed &* 6364136223846793005 &+ 1442695040888963407
                return Double((seed >> 33) & 0xFFFF) / Double(0xFFFF)
            }
            let color: Color = dark ? .white : .black
            for _ in 0..<2200 {
                let x = rnd() * size.width
                let y = rnd() * size.height
                let a = rnd() * 0.10
                ctx.fill(Path(ellipseIn: CGRect(x: x, y: y, width: 1, height: 1)),
                         with: .color(color.opacity(a)))
            }
        }
        .allowsHitTesting(false)
    }
}

/// 油画色块：低饱和、边缘全糊，只在留白处使用。
private struct OilWash3: View {
    let p: Canvas2

    /// 确定性笔触：位置/大小/颜色都由固定种子生成，每次渲染一致。
    private var dabs: [(CGFloat, CGFloat, CGFloat, Color)] {
        var seed: UInt64 = 0xC0FF_EE12_3456_789A
        func rnd() -> CGFloat {
            seed = seed &* 6364136223846793005 &+ 1442695040888963407
            return CGFloat((seed >> 33) & 0xFFFF) / CGFloat(0xFFFF)
        }
        let colors: [Color] = [p.sky, p.peach, p.rose, p.sage, p.sand, p.slate]
        var out: [(CGFloat, CGFloat, CGFloat, Color)] = []
        for i in 0..<34 {
            let x = (rnd() - 0.5) * 520
            let y = (rnd() - 0.5) * 220
            let size = 70 + rnd() * 220
            out.append((x, y, size, colors[i % colors.count]))
        }
        return out
    }

    var body: some View {
        ZStack {
            LinearGradient(colors: [p.sky.opacity(0.62), p.sand.opacity(0.68)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
            Circle().fill(p.peach.opacity(0.55)).frame(width: 420).blur(radius: 90).offset(x: -190, y: -60)
            Circle().fill(p.rose.opacity(0.5)).frame(width: 360).blur(radius: 100).offset(x: 210, y: -40)
            Circle().fill(p.slate.opacity(0.5)).frame(width: 380).blur(radius: 90).offset(x: -60, y: 90)
            ForEach(dabs.indices, id: \.self) { i in
                let d = dabs[i]
                Circle()
                    .fill(d.3.opacity(0.58))
                    .frame(width: d.2, height: d.2)
                    .blur(radius: d.2 * 0.20)
                    .offset(x: d.0, y: d.1)
            }
            Grain2(dark: p.dark).opacity(0.25)
            LinearGradient(colors: [.clear, p.canvas.opacity(0.42)],
                           startPoint: .top, endPoint: .bottom)
        }
    }
}

struct ConceptMainV2: View {
    let dark: Bool
    private var p: Canvas2 { Canvas2(dark: dark) }

    private let weekdays = ["一", "二", "三", "四", "五", "六", "日"]
    private struct D { let n: Int; let tasks: [String]; let today: Bool; let dim: Bool }
    private var days: [D] {
        var out: [D] = []
        let seed: [(Int, [String], Bool, Bool)] = [
            (28, [], false, true), (29, ["备份照片"], false, true), (30, [], false, true), (1, [], false, true),
            (2, ["学习 SwiftUI 布局"], false, true), (3, [], false, true), (4, [], false, true),
            (5, ["整理上周会议记录", "预约体检"], false, false), (6, ["读完《卡片笔记写作法》第 3 章"], false, false),
            (7, ["整理收件箱"], false, false), (8, ["写完产品原型说明", "回一封邮件", "整理本月会议记录"], true, false),
            (9, [], false, false), (10, [], false, false), (11, [], false, false),
            (12, ["下周开始整理照片"], false, false), (13, [], false, false), (14, [], false, false), (15, [], false, false),
            (16, [], false, false), (17, [], false, false), (18, [], false, false), (19, [], false, false),
            (20, [], false, false), (21, [], false, false), (22, [], false, false), (23, [], false, false),
            (24, [], false, false), (25, ["项目复盘"], false, false), (26, [], false, false), (27, [], false, false),
            (28, [], false, false), (29, [], false, false), (30, [], false, false), (31, [], false, false),
            (1, [], false, false), (2, [], false, false), (3, [], false, false), (4, [], false, false),
            (5, [], false, false), (6, [], false, false), (7, [], false, false), (8, [], false, false),
        ]
        for (n, tasks, today, dim) in seed { out.append(D(n: n, tasks: tasks, today: today, dim: dim)) }
        return out
    }

    var body: some View {
        HStack(spacing: 0) {
            VStack(spacing: 0) {
                header
                Rectangle().fill(p.rule).frame(height: 0.8)
                weekdayRow
                calendarGrid
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity)
            .background(p.canvas)

            Rectangle().fill(p.rule).frame(width: 0.8)

            dayPage.frame(width: 434)
        }
        .frame(width: 1200, height: 760)
        .background(p.canvas)
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: 14) {
            Text("2026 · 十月").font(cSerif(22, true)).foregroundStyle(p.ink)
            HStack(spacing: 6) {
                Text("‹").font(cBody(12)).foregroundStyle(p.ink3)
                Text("›").font(cBody(12)).foregroundStyle(p.ink3)
            }
            Text("今天").font(cBody(11.5, .medium)).foregroundStyle(p.ink2)
            Spacer()
            HStack(spacing: 16) {
                Text("未完成清单").font(cBody(11.5)).foregroundStyle(p.ink2)
                Text("7").font(cMono(9.5)).foregroundStyle(p.ink3)
                Text("已结束").font(cBody(11.5)).foregroundStyle(p.ink2)
                Text("使用说明").font(cBody(11.5)).foregroundStyle(p.ink2)
                Text("设置").font(cBody(11.5)).foregroundStyle(p.ink2)
            }
        }
        .padding(.horizontal, 26)
        .frame(height: 56)
    }

    private var weekdayRow: some View {
        HStack(spacing: 0) {
            ForEach(weekdays, id: \.self) { d in
                Text(d)
                    .font(cMono(9.5))
                    .tracking(1.2)
                    .foregroundStyle(p.ink3)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading, 10)
            }
        }
        .frame(height: 30)
        .padding(.horizontal, 20)
    }

    private var calendarGrid: some View {
        VStack(spacing: 0) {
            ForEach(0..<6, id: \.self) { row in
                HStack(spacing: 0) {
                    ForEach(0..<7, id: \.self) { col in
                        let i = row * 7 + col
                        cell(days[i])
                            .overlay(alignment: .leading) {
                                if col > 0 { Rectangle().fill(p.ruleSoft).frame(width: 0.7) }
                            }
                    }
                }
                .frame(maxHeight: .infinity)
                .overlay(alignment: .top) {
                    if row > 0 { Rectangle().fill(p.ruleSoft).frame(height: 0.7) }
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 18)
        .frame(maxHeight: .infinity)
    }

    private func cell(_ d: D) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 5) {
                Text("\(d.n)")
                    .font(cSerif(d.today ? 16 : 12.5, d.today))
                    .foregroundStyle(d.today ? p.accent : (d.dim ? p.faint : p.ink2))
                if d.today { Circle().fill(p.accent).frame(width: 3.5, height: 3.5) }
                Spacer()
            }
            ForEach(d.tasks.prefix(3), id: \.self) { t in
                Text(t)
                    .font(cBody(10.5))
                    .foregroundStyle(d.today ? p.ink : p.ink2)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.top, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(d.today ? p.accentSoft.opacity(0.9) : .clear)
                .padding(3)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(d.today ? p.accent.opacity(0.55) : .clear, lineWidth: 0.8)
                .padding(3)
        )
    }

    private var dayPage: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .bottomLeading) {
                OilWash3(p: p)
                    .frame(height: 176)
                    .clipped()
                HStack(alignment: .center, spacing: 14) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("8").font(cSerif(44, true)).foregroundStyle(p.ink)
                        Text("十月 · 星期四").font(cBody(12, .medium)).foregroundStyle(p.ink2)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("7 件事").font(cMono(9.5)).foregroundStyle(p.ink3)
                        Text("1 件已完成").font(cMono(9.5)).foregroundStyle(p.ink3)
                    }
                    Spacer()
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(p.surface)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .strokeBorder(p.rule, lineWidth: 0.8)
                        )
                )
                .padding(.horizontal, 18)
                .padding(.bottom, 12)
            }

            VStack(alignment: .leading, spacing: 0) {
                section("今日主线", "1")
                card(title: "写完产品原型说明",
                     subs: ["整理阶段 1 的规则条目", "校对文案与标点", "画出三个界面的草图"])
                section("今日支线", "2").padding(.top, 18)
                card(title: "回一封邮件", subs: [])
                card(title: "整理本月会议记录", subs: []).padding(.top, 7)
                HStack(spacing: 8) {
                    Text("＋").font(cBody(11)).foregroundStyle(p.accent)
                    Text("添加一件次要的事").font(cBody(12)).foregroundStyle(p.ink3)
                }
                .padding(.horizontal, 14)
                .frame(height: 36)
                .background(RoundedRectangle(cornerRadius: 8).fill(p.surfaceAlt.opacity(dark ? 0.55 : 0.8)))
                .padding(.top, 9)
            }
            .padding(.horizontal, 22)
            .padding(.top, 14)
            Spacer(minLength: 0)
        }
    }

    private func section(_ title: String, _ count: String) -> some View {
        HStack(spacing: 9) {
            Text(title).font(cBody(10.5, .semibold)).tracking(1.6).foregroundStyle(p.ink2)
            Text(count).font(cMono(9)).foregroundStyle(p.ink3)
            Rectangle().fill(p.rule).frame(height: 0.7)
        }
        .padding(.bottom, 9)
    }

    private func card(title: String, subs: [String]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                ZStack {
                    Circle().strokeBorder(p.ink2.opacity(0.85), lineWidth: 1.4).frame(width: 17, height: 17)
                }
                Text(title).font(cSerif(15, true)).foregroundStyle(p.ink)
                Spacer()
                Text("≡").font(cMono(9)).foregroundStyle(p.faint.opacity(0.8))
            }
            .frame(height: 40)
            ForEach(subs, id: \.self) { s in
                HStack(spacing: 8) {
                    Spacer().frame(width: 27)
                    Circle().fill(p.faint).frame(width: 2.5, height: 2.5)
                    Text(s).font(cBody(12)).foregroundStyle(p.ink2)
                    Spacer()
                    Text("≡").font(cMono(8.5)).foregroundStyle(p.faint.opacity(0.6))
                }
                .frame(height: 27)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(p.surface))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(p.rule, lineWidth: 0.8)
        )
    }
}
