import SwiftUI
import AppKit

// 卡片家族：同一张任务，在四个浅色主题里各自长成「那个世界的一件印刷品」。
private func chx(_ v: UInt32) -> Color {
    Color(.sRGB,
          red: Double((v >> 16) & 0xFF) / 255,
          green: Double((v >> 8) & 0xFF) / 255,
          blue: Double(v & 0xFF) / 255, opacity: 1)
}
private func cMono(_ s: CGFloat) -> Font { .system(size: s, design: .monospaced) }
private func cHeavy(_ s: CGFloat) -> Font { .system(size: s, weight: .heavy) }
private func cSerif(_ s: CGFloat) -> Font { .custom("Songti SC Bold", size: s) }
private func cCondensed(_ s: CGFloat) -> Font { .custom("HelveticaNeue-CondensedBlack", size: s) }

// MARK: 器物：工单 / 吊牌

private struct AtelierCard: View {
    let done: Bool
    private let paper = chx(0xFBF6EA)
    private let ink = chx(0x14231D)
    private let red = chx(0xB4432A)

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text("ATELIER  /  器物").font(cMono(8.5)).tracking(1.8).foregroundStyle(ink.opacity(0.6))
                Spacer()
                Text("No. 07").font(.system(size: 13, design: .serif)).italic().foregroundStyle(ink.opacity(0.75))
            }
            Rectangle().fill(ink.opacity(0.6)).frame(height: 0.9).padding(.top, 6)
            Rectangle().fill(ink.opacity(0.25)).frame(height: 0.5).padding(.top, 2)

            Text("写完产品原型说明").font(cSerif(23)).foregroundStyle(ink).padding(.top, 14)
            Text("一天一件，其余的排在它后面。").font(.system(size: 12)).foregroundStyle(ink.opacity(0.7)).padding(.top, 5)

            HStack(spacing: 20) {
                meta(" MATERIAL", "纸")
                meta(" STEPS", "3")
                meta(" HOURS", "24")
            }
            .padding(.top, 14)

            Spacer(minLength: 0)
            Rectangle().fill(red.opacity(0.85)).frame(height: 0.9)
            HStack(alignment: .center) {
                Text("2026.10.08  星期四").font(cMono(8.5)).tracking(1).foregroundStyle(ink.opacity(0.65))
                Spacer()
                if done {
                    Text("已交付")
                        .font(cSerif(12))
                        .foregroundStyle(paper)
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(Circle().fill(red))
                        .rotationEffect(.degrees(-8))
                } else {
                    Text("待装订").font(cMono(8.5)).tracking(1).foregroundStyle(red)
                }
            }
            .padding(.top, 9)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .frame(width: 520, height: 340, alignment: .topLeading)
        .background(Rectangle().fill(paper))
        .overlay(Rectangle().strokeBorder(ink.opacity(0.55), lineWidth: 0.9))
        .overlay(alignment: .topLeading) {
            Circle().strokeBorder(ink.opacity(0.25), lineWidth: 0.8)
                .frame(width: 9, height: 9)
                .padding(.leading, 8).padding(.top, 8)
        }
    }

    private func meta(_ label: String, _ value: String) -> some View {
        HStack(spacing: 5) {
            Text(label).font(cMono(7.5)).tracking(1).foregroundStyle(ink.opacity(0.45))
            Text(value).font(cSerif(12)).foregroundStyle(ink)
        }
    }
}

// MARK: 标本室：标本标签

private struct HerbariumCard: View {
    let done: Bool
    private let pal = SpecPalette(
        page: chx(0xE4E7D8), card: chx(0xDFE4D3), ink: chx(0x1C241D), accent: chx(0x3F7A4E)
    )
    var body: some View {
        SpecimenCardView(
            title: "写完产品原型说明",
            summary: "今天唯一重要的事。其余都是它的枝叶。",
            specs: [("ALT.", "今日主线"), ("LOC.", "2026.10.08 星期四"), ("ACC.", "3 步 · 1 完成")],
            footer: "MOISTURE  /  LOW ENERGY  /  MORNING",
            seed: "FUTODO-2026-10-08",
            completed: done,
            p: pal
        )
        .frame(width: 520, height: 340, alignment: .topLeading)
    }
}

// MARK: 酸纸：贴纸 / 告示

private struct AcidCard: View {
    let done: Bool
    private let acid = chx(0xE7F86B)
    private let ink = chx(0x11140F)

    var body: some View {
        ZStack(alignment: .topLeading) {
            Rectangle().fill(ink).offset(x: 7, y: 7)
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text("ACID  /  STICKER 01").font(cMono(8.5)).tracking(1.8).foregroundStyle(acid.opacity(0.7))
                    Spacer()
                    Text("★").font(.system(size: 11)).foregroundStyle(acid)
                }
                Text("写完\n产品原型说明")
                    .font(cHeavy(25))
                    .tracking(-0.5)
                    .lineSpacing(-1)
                    .foregroundStyle(acid)
                    .padding(.top, 10)
                Text("一天一件。其余贴在后面。").font(.system(size: 12)).foregroundStyle(acid.opacity(0.75)).padding(.top, 8)
                Spacer(minLength: 0)
                HStack(spacing: 3) {
                    ForEach(0..<24, id: \.self) { i in
                        Circle().fill(acid.opacity(0.35 + Double(i % 3) * 0.2)).frame(width: 3, height: 3)
                    }
                }
                Rectangle().fill(acid.opacity(0.5)).frame(height: 0.8).padding(.top, 8)
                HStack {
                    Text("2026.10.08 / 3 STEPS").font(cMono(8.5)).tracking(1).foregroundStyle(acid.opacity(0.8))
                    Spacer()
                    Text("PEEL HERE →").font(cMono(8.5)).tracking(1).foregroundStyle(acid)
                }
                .padding(.top, 8)
            }
            .padding(18)
            .frame(width: 510, height: 330, alignment: .topLeading)
            .background(Rectangle().fill(ink))
            .overlay(alignment: .topTrailing) {
                if done {
                    Text("DONE")
                        .font(cCondensed(18))
                        .foregroundStyle(ink)
                        .padding(.horizontal, 10).padding(.vertical, 2)
                        .background(Rectangle().fill(acid))
                        .rotationEffect(.degrees(-9))
                        .padding(.top, 26).padding(.trailing, 20)
                }
            }
        }
        .rotationEffect(.degrees(1.2))
        .frame(width: 520, height: 340, alignment: .topLeading)
    }
}

// MARK: 蓝图：图纸标题栏

private struct BlueprintCard: View {
    let done: Bool
    private let paper = chx(0xF7F8F3)
    private let blue = chx(0x23496B)
    private let orange = chx(0xD96A2B)

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("DWG  /  FU-2026-1008").font(cMono(8.5)).tracking(1.6).foregroundStyle(blue.opacity(0.7))
                Spacer()
                Text("REV. A").font(cMono(8)).tracking(1).foregroundStyle(orange)
                    .padding(.horizontal, 5).padding(.vertical, 2)
                    .overlay(Rectangle().strokeBorder(orange.opacity(0.8), lineWidth: 0.8))
            }
            Text("写完产品原型说明")
                .font(cHeavy(22))
                .foregroundStyle(blue)
                .padding(.top, 12)
            Text("一层：主线。二层：支线。三层：细节。").font(.system(size: 11.5)).foregroundStyle(blue.opacity(0.7)).padding(.top, 5)

            HStack(spacing: 14) {
                tick("DATE", "2026.10.08")
                tick("SCALE", "1 : 1")
                tick("STEPS", "3")
            }
            .padding(.top, 12)

            Spacer(minLength: 0)

            // 标题栏
            HStack(spacing: 0) {
                block("DWG NO", "FU-1008")
                block("SCALE", "1:1")
                block("DATE", "2026.10.08")
                block("REV", done ? "A / DONE" : "A")
            }
            .overlay(alignment: .top) { Rectangle().fill(blue.opacity(0.5)).frame(height: 0.8) }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(width: 520, height: 340, alignment: .topLeading)
        .background(
            ZStack {
                Rectangle().fill(paper)
                GridPaper()
            }
        )
        .overlay(Rectangle().strokeBorder(blue.opacity(0.65), lineWidth: 1))
        .overlay(alignment: .topTrailing) {
            if done {
                Text("REV. A")
                    .font(cCondensed(16))
                    .foregroundStyle(orange)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .overlay(Rectangle().strokeBorder(orange, lineWidth: 1.2))
                    .rotationEffect(.degrees(-7))
                    .padding(.top, 52).padding(.trailing, 26)
            }
        }
    }

    private func tick(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label).font(cMono(7)).tracking(1).foregroundStyle(blue.opacity(0.45))
            Text(value).font(cMono(10)).foregroundStyle(blue)
        }
    }

    private func block(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label).font(cMono(6.5)).tracking(0.8).foregroundStyle(blue.opacity(0.45))
            Text(value).font(cMono(9)).foregroundStyle(blue)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 7)
        .padding(.vertical, 5)
        .overlay(alignment: .leading) { Rectangle().fill(blue.opacity(0.35)).frame(width: 0.7) }
        .overlay(alignment: .bottom) { Rectangle().fill(blue.opacity(0.35)).frame(height: 0.7) }
    }
}

private struct GridPaper: View {
    var body: some View {
        Canvas { ctx, size in
            let color = GraphicsContext.Shading.color(Color(red: 0.14, green: 0.29, blue: 0.42).opacity(0.08))
            var x: CGFloat = 0
            while x < size.width {
                ctx.fill(Path(CGRect(x: x, y: 0, width: 0.6, height: size.height)), with: color)
                x += 18
            }
            var y: CGFloat = 0
            while y < size.height {
                ctx.fill(Path(CGRect(x: 0, y: y, width: size.width, height: 0.6)), with: color)
                y += 18
            }
        }
    }
}

// MARK: 样张板

struct CardFamilyBoard: View {
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("CARD FAMILY  /  同一张任务，四个世界").font(cMono(10)).tracking(2).foregroundStyle(chx(0x2A2A26).opacity(0.7))
                Spacer()
                Text("ALL LIGHT  ·  NO BLACK BACKGROUND").font(cMono(9)).tracking(1.4).foregroundStyle(chx(0x2A2A26).opacity(0.45))
            }
            .padding(.bottom, 16)

            HStack(spacing: 18) {
                cell(label: "器物 / ATELIER  —  工单与吊牌", bg: chx(0xEFEAD9)) {
                    AtelierCard(done: false)
                }
                cell(label: "标本室 / HERBARIUM  —  标本标签", bg: chx(0xE4E7D8)) {
                    HerbariumCard(done: true)
                }
            }
            HStack(spacing: 18) {
                cell(label: "酸纸 / ACID  —  贴纸与告示", bg: chx(0xE7F86B)) {
                    AcidCard(done: false)
                }
                cell(label: "蓝图 / BLUEPRINT  —  图纸标题栏", bg: chx(0xE6EBE6)) {
                    BlueprintCard(done: true)
                }
            }
            .padding(.top, 18)
        }
        .padding(36)
        .frame(width: 1400, height: 1000, alignment: .topLeading)
        .background(chx(0xE9E5D8))
    }

    private func cell<Content: View>(label: String, bg: Color, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label).font(cMono(8.5)).tracking(1.2).foregroundStyle(chx(0x2A2A26).opacity(0.6))
            content()
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(Rectangle().fill(bg))
    }
}
