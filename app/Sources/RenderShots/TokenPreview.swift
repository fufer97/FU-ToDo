import SwiftUI
import AppKit

// 设计校准用的临时视图：不接 Theme，不参与正式界面。
// 用途：把「画布（浅）/ 夜航（深）」两套 token 与主界面构图渲染成真图，供确认后再落到 Theme/Views。

private func hx(_ v: UInt32) -> Color {
    Color(.sRGB,
          red: Double((v >> 16) & 0xFF) / 255,
          green: Double((v >> 8) & 0xFF) / 255,
          blue: Double(v & 0xFF) / 255,
          opacity: 1)
}

struct Palette {
    let dark: Bool

    var canvas: Color { dark ? hx(0x141512) : hx(0xFAF8F0) }
    var canvasDeep: Color { dark ? hx(0x0F100D) : hx(0xF1EDE1) }
    var surface: Color { dark ? hx(0x1C1E19) : hx(0xFFFDF7) }
    var surfaceAlt: Color { dark ? hx(0x24261F) : hx(0xF0EBDD) }
    var rule: Color { dark ? hx(0x2E312A) : hx(0xE2DCCD) }
    var ruleStrong: Color { dark ? hx(0x3E4238) : hx(0xCFC6B2) }
    var ink: Color { dark ? hx(0xEDEADF) : hx(0x2A2F2B) }
    var ink2: Color { dark ? hx(0xAAA89C) : hx(0x5E635C) }
    var ink3: Color { dark ? hx(0x7C7E72) : hx(0x8A8D85) }
    var faint: Color { dark ? hx(0x565950) : hx(0xB4B6AD) }
    var accent: Color { dark ? hx(0x8FAEB4) : hx(0x2F4F5E) }
    var accentSoft: Color { dark ? hx(0x22302F) : hx(0xE1E9E7) }
    var done: Color { dark ? hx(0x93B4A0) : hx(0x6E8B7B) }
    var action: Color { dark ? hx(0xEDEADF) : hx(0x1F2320) }
    var actionInk: Color { dark ? hx(0x141512) : hx(0xFAF8F0) }

    var sky: Color { dark ? hx(0x3B474A) : hx(0x9BA7A9) }
    var peach: Color { dark ? hx(0x5A4736) : hx(0xF1D4B3) }
    var rose: Color { dark ? hx(0x4C3D3A) : hx(0xD4BDA9) }
    var sage: Color { dark ? hx(0x414A41) : hx(0xB6B9B2) }
    var sand: Color { dark ? hx(0x5B4C3B) : hx(0xE0C9AF) }
    var slate: Color { dark ? hx(0x344346) : hx(0x829598) }
}

private func serifRegular(_ size: CGFloat) -> Font { .custom("Songti SC", size: size) }
private func serifBold(_ size: CGFloat) -> Font { .custom("Songti SC Bold", size: size) }
private func mono(_ size: CGFloat) -> Font { .system(size: size, design: .monospaced) }

struct PaintedWash: View {
    let p: Palette
    var body: some View {
        ZStack {
            LinearGradient(colors: [p.sky.opacity(0.55), p.sand.opacity(0.55)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
            Circle().fill(p.peach.opacity(0.9)).frame(width: 300).blur(radius: 70).offset(x: -140, y: -50)
            Circle().fill(p.rose.opacity(0.85)).frame(width: 250).blur(radius: 80).offset(x: 150, y: -60)
            Circle().fill(p.sage.opacity(0.8)).frame(width: 260).blur(radius: 70).offset(x: 60, y: 90)
            Circle().fill(p.slate.opacity(0.75)).frame(width: 200).blur(radius: 60).offset(x: -170, y: 70)
        }
    }
}

private struct Swatch: View {
    let name: String
    let hex: String
    let color: Color
    let p: Palette
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(color)
                .frame(width: 66, height: 44)
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .strokeBorder(p.rule.opacity(0.8), lineWidth: 0.5)
                )
            Text(name).font(.system(size: 9.5, weight: .medium)).foregroundStyle(p.ink2)
            Text(hex).font(mono(8.5)).foregroundStyle(p.ink3)
        }
    }
}

private struct GhostButton: View {
    let title: String
    let p: Palette
    var body: some View {
        Text(title)
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(p.ink2)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .overlay(
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .strokeBorder(p.rule, lineWidth: 0.8)
            )
    }
}

private struct ActionButton: View {
    let title: String
    let p: Palette
    var body: some View {
        Text(title)
            .font(.system(size: 12.5, weight: .medium))
            .foregroundStyle(p.actionInk)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(RoundedRectangle(cornerRadius: 4, style: .continuous).fill(p.action))
    }
}

private struct RingDot: View {
    let done: Bool
    let p: Palette
    var body: some View {
        ZStack {
            Circle().strokeBorder(done ? p.done : p.ink3.opacity(0.8), lineWidth: 1.4)
                .frame(width: 17, height: 17)
            if done {
                Circle().fill(p.done).frame(width: 17, height: 17)
                Image(systemName: "checkmark")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(p.canvas)
            }
        }
    }
}

private struct MockTaskCard: View {
    let p: Palette
    let title: String
    let subs: [String]
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                RingDot(done: false, p: p)
                Text(title).font(serifBold(15)).foregroundStyle(p.ink)
                Spacer()
                Text("≡").font(mono(10)).foregroundStyle(p.faint)
            }
            .frame(height: 38)
            ForEach(subs, id: \.self) { s in
                HStack(spacing: 8) {
                    Spacer().frame(width: 26)
                    Circle().fill(p.faint).frame(width: 3, height: 3)
                    Text(s).font(.system(size: 12)).foregroundStyle(p.ink2)
                    Spacer()
                    Text("≡").font(mono(9)).foregroundStyle(p.faint.opacity(0.7))
                }
                .frame(height: 26)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(p.surface))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(p.rule, lineWidth: 0.8)
        )
    }
}

// MARK: - token 校准表

struct TokenSheetView: View {
    let dark: Bool
    private var p: Palette { Palette(dark: dark) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("FU TODO  ·  VISUAL SYSTEM").font(mono(10)).tracking(1.6).foregroundStyle(p.ink3)
                Spacer()
                Text(dark ? "NIGHT / 夜航" : "CANVAS / 画布").font(mono(10)).tracking(1.6).foregroundStyle(p.ink3)
            }

            HStack(alignment: .firstTextBaseline, spacing: 16) {
                Text(dark ? "夜航" : "画布").font(serifRegular(46)).foregroundStyle(p.ink)
                Text(dark ? "低亮度、低饱和，晚上也能安静地用。" : "奶油纸、宋体、油画色，像一页编辑过的纸。")
                    .font(.system(size: 13)).foregroundStyle(p.ink2)
                Spacer()
                Text(dark ? "0F100D → 141512" : "F1EDE1 → FAF8F0").font(mono(9)).foregroundStyle(p.ink3)
            }
            .padding(.top, 14)

            HStack(alignment: .top, spacing: 22) {
                PaintedWash(p: p)
                    .frame(width: 470, height: 150)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(p.rule.opacity(0.7), lineWidth: 0.8)
                    )
                VStack(alignment: .leading, spacing: 8) {
                    Text("颜料").font(.system(size: 11, weight: .semibold)).foregroundStyle(p.ink2)
                    HStack(spacing: 8) {
                        swatch("灰蓝", "#9BA7A9", p.sky)
                        swatch("蜜桃", "#F1D4B3", p.peach)
                        swatch("玫瑰灰", "#D4BDA9", p.rose)
                        swatch("鼠尾草", "#B6B9B2", p.sage)
                        swatch("沙", "#E0C9AF", p.sand)
                    }
                    Text("油画只出现在欢迎页、空态与顶栏留白；任务区保持干净，不把肌理压在字下面。")
                        .font(.system(size: 11)).foregroundStyle(p.ink3)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            .padding(.top, 20)

            HStack(alignment: .top, spacing: 10) {
                Swatch(name: "canvas", hex: dark ? "#141512" : "#FAF8F0", color: p.canvas, p: p)
                Swatch(name: "surface", hex: dark ? "#1C1E19" : "#FFFDF7", color: p.surface, p: p)
                Swatch(name: "ink", hex: dark ? "#EDEADF" : "#2A2F2B", color: p.ink, p: p)
                Swatch(name: "ink 2", hex: dark ? "#AAA89C" : "#5E635C", color: p.ink2, p: p)
                Swatch(name: "ink 3", hex: dark ? "#7C7E72" : "#8A8D85", color: p.ink3, p: p)
                Swatch(name: "rule", hex: dark ? "#2E312A" : "#E2DCCD", color: p.rule, p: p)
                Swatch(name: "accent", hex: dark ? "#8FAEB4" : "#2F4F5E", color: p.accent, p: p)
                Swatch(name: "soft", hex: dark ? "#22302F" : "#E1E9E7", color: p.accentSoft, p: p)
                Swatch(name: "done", hex: dark ? "#93B4A0" : "#6E8B7B", color: p.done, p: p)
                Swatch(name: "action", hex: dark ? "#EDEADF" : "#1F2320", color: p.action, p: p)
            }
            .padding(.top, 18)

            HStack(alignment: .top, spacing: 28) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("展示声部 · 宋体").font(mono(9)).tracking(1.2).foregroundStyle(p.ink3)
                    HStack(alignment: .firstTextBaseline, spacing: 14) {
                        Text("8").font(serifBold(76)).foregroundStyle(p.ink)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("十月 · 星期四").font(serifBold(24)).foregroundStyle(p.ink)
                            Text("Editorial Calendar").font(.system(size: 19, design: .serif)).foregroundStyle(p.ink2)
                        }
                    }
                    Text("正文声明").font(mono(9)).tracking(1.2).foregroundStyle(p.ink3).padding(.top, 4)
                    Text("今天只做一件重要的事，其余的排在它后面。")
                        .font(.system(size: 14)).foregroundStyle(p.ink)
                    Text("元数据 / 计数 / 快捷键用等宽，像档案标签。")
                        .font(mono(10.5)).foregroundStyle(p.ink3)
                }
                VStack(alignment: .leading, spacing: 8) {
                    Text("组件").font(mono(9)).tracking(1.2).foregroundStyle(p.ink3)
                    MockTaskCard(p: p, title: "写完产品原型说明", subs: ["整理阶段 1 的规则条目", "校对文案与标点"])
                    HStack(spacing: 8) {
                        ActionButton(title: "写下今天最重要的事", p: p)
                        GhostButton(title: "使用说明", p: p)
                        Text("今天").font(.system(size: 10.5, weight: .medium))
                            .foregroundStyle(p.accent)
                            .padding(.horizontal, 8).padding(.vertical, 3)
                            .background(Capsule().fill(p.accentSoft))
                    }
                }
                VStack(alignment: .leading, spacing: 10) {
                    Text("对比度底线").font(mono(9)).tracking(1.2).foregroundStyle(p.ink3)
                    contrastRow("ink / canvas", "12.6 : 1", p.ink, p.canvas)
                    contrastRow("ink 2 / canvas", "5.2 : 1", p.ink2, p.canvas)
                    contrastRow("ink 3 / canvas", "3.1 : 1", p.ink3, p.canvas)
                    Text(dark ? "深色不靠纯黑，靠低亮度差与一条细描边。" : "浅色不靠阴影，靠纸色差与 0.8px 细线。")
                        .font(.system(size: 10.5)).foregroundStyle(p.ink3)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            .padding(.top, 22)

            Spacer(minLength: 0)
            HStack {
                Text("FU ToDo · 设计校准 v0 · 参考图：油画 / 编辑排版").font(mono(9)).foregroundStyle(p.ink3)
                Spacer()
                Text("待确认后落到 Theme.swift").font(mono(9)).foregroundStyle(p.ink3)
            }
        }
        .padding(44)
        .frame(width: 1400, height: 1000, alignment: .topLeading)
        .background(p.canvas)
    }

    private func swatch(_ name: String, _ hex: String, _ color: Color) -> some View {
        VStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 5).fill(color).frame(width: 54, height: 34)
                .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(p.rule.opacity(0.7), lineWidth: 0.5))
            Text(name).font(.system(size: 8.5)).foregroundStyle(p.ink3)
        }
    }

    private func contrastRow(_ label: String, _ ratio: String, _ fg: Color, _ bg: Color) -> some View {
        HStack(spacing: 8) {
            Text("Aa").font(.system(size: 12, weight: .medium)).foregroundStyle(fg)
                .frame(width: 26, height: 20).background(RoundedRectangle(cornerRadius: 3).fill(bg))
                .overlay(RoundedRectangle(cornerRadius: 3).strokeBorder(p.rule, lineWidth: 0.6))
            Text(label).font(mono(9.5)).foregroundStyle(p.ink3)
            Spacer()
            Text(ratio).font(mono(9.5)).foregroundStyle(p.ink2)
        }
        .frame(width: 210)
    }
}

// MARK: - 主界面构图概念（静态，只用于看方向）

struct ConceptMainView: View {
    let dark: Bool
    private var p: Palette { Palette(dark: dark) }

    private let weekdays = ["一", "二", "三", "四", "五", "六", "日"]
    private let days: [(Int, [String], Bool)] = [
        (28, [], false), (29, ["备份照片"], false), (30, [], false), (1, [], false),
        (2, ["学习 SwiftUI 布局"], false), (3, [], false), (4, [], false),
        (5, ["整理上周会议记录", "预约体检"], false), (6, ["读完《卡片笔记写作法》第 3 章"], false),
        (7, ["整理收件箱"], false), (8, ["写完产品原型说明", "回一封邮件", "整理本月会议记录"], true),
        (9, [], false), (10, [], false), (11, [], false),
        (12, ["下周开始整理照片"], false), (13, [], false), (14, [], false), (15, [], false),
        (16, [], false), (17, [], false), (18, [], false),
    ]

    var body: some View {
        HStack(spacing: 0) {
            VStack(spacing: 0) {
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Text("2026 · 十月").font(serifBold(20)).foregroundStyle(p.ink)
                    Text("‹").font(.system(size: 13)).foregroundStyle(p.ink3)
                    Text("›").font(.system(size: 13)).foregroundStyle(p.ink3)
                    Text("今天").font(.system(size: 11.5, weight: .medium)).foregroundStyle(p.ink3)
                    Spacer()
                    Text("未完成清单  7").font(.system(size: 11.5)).foregroundStyle(p.ink2)
                    Text("已结束").font(.system(size: 11.5)).foregroundStyle(p.ink2)
                    Text("使用说明").font(.system(size: 11.5)).foregroundStyle(p.ink2)
                    Text("设置").font(.system(size: 11.5)).foregroundStyle(p.ink2)
                }
                .padding(.horizontal, 24)
                .padding(.top, 18)
                .padding(.bottom, 12)

                Rectangle().fill(p.rule).frame(height: 0.8).padding(.horizontal, 24)
                weekRow.padding(.top, 10)

                VStack(spacing: 4) {
                    ForEach(0..<3, id: \.self) { row in
                        HStack(spacing: 4) {
                            ForEach(0..<7, id: \.self) { col in
                                let index = row * 7 + col
                                if index < days.count { cell(days[index]) } else { Color.clear }
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 4)
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity)

            Rectangle().fill(p.rule).frame(width: 0.8)

            dayPage.frame(width: 430)
        }
        .frame(width: 1200, height: 760)
        .background(p.canvas)
    }

    private var weekRow: some View {
        HStack(spacing: 4) {
            ForEach(weekdays, id: \.self) { d in
                Text(d).font(.system(size: 10, weight: .medium)).foregroundStyle(p.ink3)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 20)
    }

    private func cell(_ day: (Int, [String], Bool)) -> some View {
        let (num, tasks, today) = day
        return VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text("\(num)")
                    .font(today ? serifBold(15) : serifRegular(13))
                    .foregroundStyle(today ? p.accent : p.ink2)
                Spacer()
                if today { Circle().fill(p.accent).frame(width: 4, height: 4) }
            }
            ForEach(tasks.prefix(2), id: \.self) { t in
                Text(t).font(.system(size: 9.5)).foregroundStyle(today ? p.ink : p.ink3)
                    .lineLimit(1)
            }
        }
        .padding(8)
        .frame(maxWidth: .infinity, minHeight: 104, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(today ? p.accentSoft : p.canvas)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(today ? p.accent.opacity(0.65) : p.rule.opacity(0.55), lineWidth: today ? 1 : 0.6)
        )
    }

    private var dayPage: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .bottomLeading) {
                PaintedWash(p: p)
                    .frame(height: 148)
                    .clipped()
                LinearGradient(colors: [p.canvas.opacity(0.0), p.canvas.opacity(0.85)],
                               startPoint: .top, endPoint: .bottom)
                    .frame(height: 148)
                VStack(alignment: .leading, spacing: 2) {
                    Text("8").font(serifBold(54)).foregroundStyle(p.ink)
                    Text("十月 · 星期四  ·  7 件事").font(.system(size: 11)).foregroundStyle(p.ink2)
                }
                .padding(.horizontal, 22)
                .padding(.bottom, 10)
            }

            VStack(alignment: .leading, spacing: 0) {
                section("今日主线", "1")
                MockTaskCard(p: p, title: "写完产品原型说明",
                             subs: ["整理阶段 1 的规则条目", "校对文案与标点", "画出三个界面的草图"])
                section("今日支线", "2").padding(.top, 16)
                MockTaskCard(p: p, title: "回一封邮件", subs: [])
                MockTaskCard(p: p, title: "整理本月会议记录", subs: []).padding(.top, 6)
                HStack(spacing: 8) {
                    Text("＋").font(.system(size: 11)).foregroundStyle(p.accent)
                    Text("添加一件次要的事").font(.system(size: 12)).foregroundStyle(p.ink3)
                }
                .padding(.horizontal, 14).frame(height: 34)
                .background(RoundedRectangle(cornerRadius: 10).fill(p.surfaceAlt.opacity(0.7)))
                .padding(.top, 8)
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            Spacer(minLength: 0)
        }
    }

    private func section(_ title: String, _ count: String) -> some View {
        HStack(spacing: 8) {
            Text(title).font(.system(size: 11.5, weight: .semibold)).tracking(1.4).foregroundStyle(p.ink2)
            Text(count).font(mono(9)).foregroundStyle(p.ink3)
            Rectangle().fill(p.rule).frame(height: 0.7)
        }
        .padding(.bottom, 8)
    }
}
