import SwiftUI
import AppKit
import CoreImage
import CoreImage.CIFilterBuiltins

// 标本卡（Herbarium 风格）可行性样张：浅色、不黑底。
private func shx(_ v: UInt32) -> Color {
    Color(.sRGB,
          red: Double((v >> 16) & 0xFF) / 255,
          green: Double((v >> 8) & 0xFF) / 255,
          blue: Double(v & 0xFF) / 255, opacity: 1)
}
private func sMono(_ s: CGFloat) -> Font { .system(size: s, design: .monospaced) }
private func sHeavyCN(_ s: CGFloat) -> Font { .system(size: s, weight: .heavy) }
private func sCondensed(_ s: CGFloat) -> Font { .custom("HelveticaNeue-CondensedBlack", size: s) }

struct SpecPalette {
    let page: Color
    let card: Color
    let ink: Color
    let accent: Color
    var rule: Color { ink.opacity(0.28) }
    var faint: Color { ink.opacity(0.5) }
}

private func barcodeImage(_ seed: String, width: CGFloat, height: CGFloat) -> NSImage? {
    let filter = CIFilter.code128BarcodeGenerator()
    filter.message = Data(seed.utf8)
    filter.quietSpace = 1
    guard let out = filter.outputImage,
          let cg = CIContext().createCGImage(out, from: out.extent) else { return nil }
    return NSImage(cgImage: cg, size: NSSize(width: width, height: height))
}

struct SpecimenCardView: View {
    let title: String
    let summary: String
    let specs: [(String, String)]
    let footer: String
    let seed: String
    let completed: Bool
    let p: SpecPalette

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text("FU TODO  /  SPECIMEN").font(sMono(9)).tracking(1.6).foregroundStyle(p.ink.opacity(0.8))
                Spacer()
                Text("CH-08").font(sMono(9)).tracking(1.6).foregroundStyle(p.faint)
            }
            Rectangle().fill(p.ink.opacity(0.55)).frame(height: 0.8).padding(.top, 8)

            Text(title)
                .font(sHeavyCN(27))
                .tracking(0.4)
                .foregroundStyle(p.ink)
                .lineLimit(2)
                .padding(.top, 14)

            Text(summary)
                .font(.system(size: 12.5))
                .foregroundStyle(p.ink.opacity(0.78))
                .lineSpacing(2)
                .padding(.top, 8)

            VStack(alignment: .leading, spacing: 5) {
                ForEach(specs, id: \.0) { row in
                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                        Text(row.0).font(sMono(9.5)).tracking(1.2).foregroundStyle(p.faint)
                            .frame(width: 44, alignment: .leading)
                        Text(row.1).font(.system(size: 12.5)).foregroundStyle(p.ink)
                    }
                }
            }
            .padding(.top, 14)

            Spacer(minLength: 0)

            Rectangle().fill(p.rule).frame(height: 0.8)
            HStack(alignment: .center, spacing: 12) {
                Text(footer).font(sMono(8.5)).tracking(1.4).foregroundStyle(p.ink.opacity(0.75))
                Spacer()
                if let img = barcodeImage(seed, width: 92, height: 24) {
                    Image(nsImage: img).resizable().interpolation(.none).frame(width: 92, height: 24)
                } else {
                    HStack(spacing: 1) {
                        ForEach(0..<30, id: \.self) { i in
                            Rectangle().fill(p.ink).frame(width: CGFloat((i * 7) % 3 + 1), height: 24)
                        }
                    }
                }
            }
            .padding(.top, 10)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 18)
        .background(
            RoundedRectangle(cornerRadius: 2, style: .continuous).fill(p.card)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .strokeBorder(p.ink.opacity(0.55), lineWidth: 1)
        )
        .overlay(alignment: .topTrailing) {
            if completed {
                Text("DRIED & MOUNTED · 2026.10.08")
                    .font(sMono(7)).tracking(0.6)
                    .foregroundStyle(p.accent.opacity(0.95))
                    .padding(.horizontal, 10).padding(.vertical, 6)
                .overlay(Rectangle().strokeBorder(p.accent.opacity(0.9), lineWidth: 1.2))
                .rotationEffect(.degrees(-7))
                .padding(.top, 18).padding(.trailing, 16)
            }
        }
    }
}

struct SpecimenBoard: View {
    private let p = SpecPalette(
        page: shx(0xE9E5D6),
        card: shx(0xDFE4D3),
        ink: shx(0x1C241D),
        accent: shx(0x3F7A4E)
    )
    private let p2 = SpecPalette(
        page: shx(0xE9E5D6),
        card: shx(0xE6E8DB),
        ink: shx(0x1C241D),
        accent: shx(0xB4432A)
    )

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text("SPECIMEN CARD  /  组件可行性样张").font(sMono(10)).tracking(2).foregroundStyle(p.ink.opacity(0.65))
                Spacer()
                Text("LIGHT THEME · NO BLACK BACKGROUND").font(sMono(9)).tracking(1.6).foregroundStyle(p.ink.opacity(0.45))
            }

            HStack(alignment: .top, spacing: 26) {
                cardColumn(
                    p: p,
                    card: SpecimenCardView(
                        title: "写完产品原型说明",
                        summary: "今天唯一重要的事。其余都是它的枝叶。",
                        specs: [("ALT.", "今日主线"), ("LOC.", "2026.10.08 星期四"), ("ACC.", "3 步 · 1 完成")],
                        footer: "MOISTURE  /  LOW ENERGY  /  MORNING",
                        seed: "FUTODO-2026-10-08",
                        completed: false,
                        p: p
                    ),
                    caption: "进行中：主标题 + 两条说明 + 规格行 + 条码"
                )
                cardColumn(
                    p: p2,
                    card: SpecimenCardView(
                        title: "把今天的截图归档",
                        summary: "完成后盖一枚日期章，卡片留在这一页。",
                        specs: [("ALT.", "已完成"), ("LOC.", "2026.10.08 22:10"), ("ACC.", "勾选完成")],
                        footer: "DRIED  /  MOUNTED  /  ARCHIVED",
                        seed: "FUTODO-DONE-2026-10-08",
                        completed: true,
                        p: p2
                    ),
                    caption: "已完成：印章 + 褪色 + 条码编码任务 ID"
                )
            }
            .padding(.top, 22)

            Spacer(minLength: 0)

            HStack(alignment: .top, spacing: 30) {
                note("能实现", [
                    "卡片 = 纯 SwiftUI：底色 + 1px 描边 + 双横线 + 等宽规格行",
                    "标题：中文用 PingFang Heavy，英文/数字可用 HelveticaNeue-CondensedBlack（已验证本机存在）",
                    "条码：CIFilter CICode128BarcodeGenerator，用任务 ID/日期生成，不是画上去的装饰",
                    "印章：旋转 -7° 的红/绿框 + 日期文字，已完成状态出现"
                ], p: p)
                note("要定的事", [
                    "卡片用在哪些位置：日页主线 / 已完成 / 清单里的旧任务 / 月历 hover 预览",
                    "规格行映射什么字段：层级、日期、子步骤数、完成方式",
                    "条码编码什么：任务 ID、日期，或两者拼起来",
                    "中文标题是否需要更“重”的字体（本机没有 condensed 中文，只能加粗/换字体）"
                ], p: p)
            }
            .padding(.top, 20)
        }
        .padding(40)
        .frame(width: 1200, height: 760, alignment: .topLeading)
        .background(p.page)
    }

    private func cardColumn(p: SpecPalette, card: some View, caption: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            card.frame(width: 520, height: 360, alignment: .topLeading)
            Text(caption).font(sMono(9)).tracking(1).foregroundStyle(p.ink.opacity(0.55))
        }
    }

    private func note(_ title: String, _ items: [String], p: SpecPalette) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(sMono(9)).tracking(1.6).foregroundStyle(p.ink.opacity(0.55))
            ForEach(items, id: \.self) { s in
                HStack(alignment: .top, spacing: 8) {
                    Text("—").font(sMono(9)).foregroundStyle(p.ink.opacity(0.5))
                    Text(s).font(.system(size: 11.5)).foregroundStyle(p.ink.opacity(0.85))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
