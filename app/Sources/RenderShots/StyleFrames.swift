import SwiftUI
import AppKit

// 风格帧：只回答「新审美够不够大胆」。不是界面实现，不接 Theme。
private func fhx(_ v: UInt32) -> Color {
    Color(.sRGB,
          red: Double((v >> 16) & 0xFF) / 255,
          green: Double((v >> 8) & 0xFF) / 255,
          blue: Double(v & 0xFF) / 255, opacity: 1)
}
private func fSerif(_ s: CGFloat, _ bold: Bool = false) -> Font {
    .custom(bold ? "Songti SC Bold" : "Songti SC", size: s)
}
private func fSans(_ s: CGFloat, _ w: Font.Weight = .regular) -> Font {
    .system(size: s, weight: w)
}
private func fMono(_ s: CGFloat) -> Font { .system(size: s, design: .monospaced) }

// A. 标本室：深墨绿 + 奶油 + 酸柠
struct FrameArchive: View {
    private let field = fhx(0x0F1F18)
    private let cream = fhx(0xF3EDDD)
    private let lime = fhx(0xC8F45A)
    private let rule = fhx(0x2A4034)

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("FU TODO  /  SPECIMEN ARCHIVE").font(fMono(9)).tracking(1.8).foregroundStyle(cream.opacity(0.55))
                Spacer()
                Text("2026 / 10  ·  SHEET 01").font(fMono(9)).tracking(1.8).foregroundStyle(cream.opacity(0.55))
            }
            .padding(.horizontal, 28).padding(.top, 22)

            HStack(alignment: .bottom, spacing: 18) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("十月").font(fSerif(104, true)).foregroundStyle(cream)
                    HStack(spacing: 12) {
                        Text("THURSDAY 08").font(fMono(11)).tracking(2).foregroundStyle(lime)
                        Text("一天一件，其余排在后面").font(fSans(12)).foregroundStyle(cream.opacity(0.6))
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("08").font(fSerif(64, true)).foregroundStyle(lime)
                    Text("OCT").font(fMono(10)).tracking(3).foregroundStyle(cream.opacity(0.5))
                }
            }
            .padding(.horizontal, 28)
            .padding(.top, 18)

            HStack(alignment: .top, spacing: 18) {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(["01  主线", "02  支线", "03  完成"], id: \.self) { s in
                        HStack(spacing: 10) {
                            Text(s).font(fMono(9.5)).tracking(1.6).foregroundStyle(cream.opacity(0.55))
                            Rectangle().fill(rule).frame(height: 0.7)
                        }
                    }
                    Spacer()
                    Text("SPECIMEN").font(fMono(8.5)).tracking(2).foregroundStyle(lime.opacity(0.8))
                }
                .frame(width: 170, height: 170, alignment: .topLeading)

                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 12) {
                        Text("8").font(fSerif(38, true)).foregroundStyle(field)
                        VStack(alignment: .leading, spacing: 1) {
                            Text("写完产品原型说明").font(fSerif(20, true)).foregroundStyle(field)
                            Text("7 件事 · 1 件已完成").font(fMono(9)).foregroundStyle(field.opacity(0.55))
                        }
                        Spacer()
                        Text("LIVE").font(fMono(8.5)).tracking(1.5).foregroundStyle(field.opacity(0.6))
                    }
                    .padding(.horizontal, 18).padding(.top, 16)
                    Rectangle().fill(field.opacity(0.18)).frame(height: 0.8).padding(.horizontal, 18)
                    ForEach(["整理阶段 1 的规则条目", "校对文案与标点", "画出三个界面的草图"], id: \.self) { t in
                        HStack(spacing: 10) {
                            Circle().fill(field.opacity(0.35)).frame(width: 3, height: 3)
                            Text(t).font(fSans(12.5)).foregroundStyle(field.opacity(0.8))
                            Spacer()
                        }
                        .frame(height: 30).padding(.horizontal, 20)
                    }
                    Spacer(minLength: 0)
                }
                .frame(width: 430, height: 200, alignment: .topLeading)
                .background(RoundedRectangle(cornerRadius: 3).fill(cream))
            }
            .padding(.horizontal, 28)
            .padding(.top, 22)

            Spacer(minLength: 0)
            HStack {
                Text("写好今天最重要的一件事").font(fSans(14, .semibold)).foregroundStyle(field)
                Spacer()
                Text("→").font(fSans(16, .semibold)).foregroundStyle(field)
            }
            .padding(.horizontal, 28)
            .frame(height: 62)
            .background(lime)
        }
        .frame(width: 900, height: 560)
        .background(field)
    }
}

// B. 酸纸：整块荧光底 + 巨型黑字（Fieldwork / Herbarium）
struct FrameAcid: View {
    private let acid = fhx(0xE7F86B)
    private let ink = fhx(0x11140F)
    private let paper = fhx(0xFAFAF2)

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("FU TODO®").font(fSans(12, .bold)).foregroundStyle(ink)
                Spacer()
                Text("DAILY  /  ONE THING").font(fMono(9)).tracking(2).foregroundStyle(ink.opacity(0.7))
            }
            .padding(.horizontal, 26).frame(height: 48)

            Text("把今天\n过成一页。").font(fSans(64, .black)).foregroundStyle(ink)
                .lineSpacing(-6)
                .padding(.horizontal, 24).padding(.top, 10)

            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("2026 · 10 · 08").font(fMono(10)).tracking(2).foregroundStyle(ink.opacity(0.7))
                    Text("星期四 / 第 281 天").font(fMono(10)).tracking(1.5).foregroundStyle(ink.opacity(0.45))
                }
                Spacer()
                Text("01 / 03").font(fMono(10)).tracking(2).foregroundStyle(ink.opacity(0.45))
            }
            .padding(.horizontal, 26).padding(.top, 6)

            HStack(alignment: .top, spacing: 10) {
                VStack(spacing: 8) {
                    ForEach(["ANCHOR", "BRANCH", "DONE"], id: \.self) { s in
                        Text(s).font(fMono(8.5)).tracking(2).foregroundStyle(ink.opacity(0.7))
                            .frame(maxWidth: .infinity, minHeight: 46, alignment: .center)
                            .background(Rectangle().fill(paper))
                    }
                }
                .frame(width: 130)

                VStack(alignment: .leading, spacing: 0) {
                    Text("写完产品原型说明").font(fSans(17, .bold)).foregroundStyle(ink)
                        .padding(.horizontal, 14).frame(height: 48)
                    ForEach(["整理阶段 1 的规则条目", "校对文案与标点", "画出三个界面的草图"], id: \.self) { t in
                        Text(t).font(fSans(12)).foregroundStyle(ink.opacity(0.75))
                            .padding(.horizontal, 14).frame(height: 32, alignment: .leading)
                    }
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, minHeight: 176, alignment: .topLeading)
                .background(Rectangle().fill(paper))
            }
            .padding(.horizontal, 24)
            .padding(.top, 14)

            Spacer(minLength: 0)
            HStack {
                Text("＋ 添加一件次要的事").font(fSans(12, .medium)).foregroundStyle(ink)
                Spacer()
                Text("⌘⏎").font(fMono(9)).foregroundStyle(ink.opacity(0.5))
            }
            .padding(.horizontal, 24).frame(height: 44)
        }
        .frame(width: 900, height: 560)
        .background(acid)
    }
}

// C. 工坊：奶油 + 深绿 + 赭红（Volders / Mercier / Chronos）
struct FrameAtelier: View {
    private let paper = fhx(0xF2EEE3)
    private let ink = fhx(0x14231D)
    private let red = fhx(0xB4432A)
    private let gold = fhx(0xC8A24A)

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("FU ToDo").font(fSerif(20, true)).foregroundStyle(ink)
                Spacer()
                Text("ATELIER  /  LYON · EST. 2026").font(fMono(8.5)).tracking(2).foregroundStyle(ink.opacity(0.55))
            }
            .padding(.horizontal, 30).frame(height: 56)

            HStack(alignment: .firstTextBaseline, spacing: 16) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("One thing.").font(.system(size: 60, design: .serif)).foregroundStyle(ink)
                    Text("一天一件。").font(fSerif(58, true)).foregroundStyle(ink)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("24").font(.system(size: 46, design: .serif)).foregroundStyle(red)
                    Text("HOURS / DAY").font(fMono(8)).tracking(2).foregroundStyle(ink.opacity(0.5))
                }
            }
            .padding(.horizontal, 30)

            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        Text("08").font(.system(size: 54, design: .serif)).foregroundStyle(paper)
                        VStack(alignment: .leading, spacing: 1) {
                            Text("OCT · THU").font(fMono(9)).tracking(2).foregroundStyle(paper.opacity(0.75))
                            Text("今日主线").font(fSans(11)).foregroundStyle(paper.opacity(0.75))
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 16).padding(.top, 12)
                    Text("写完产品原型说明").font(fSerif(19, true)).foregroundStyle(paper)
                        .padding(.horizontal, 16).padding(.top, 2)
                    Spacer()
                    Rectangle().fill(paper.opacity(0.25)).frame(height: 0.7).padding(.horizontal, 16)
                    Text("7 件事 · 1 件已完成").font(fMono(8.5)).tracking(1).foregroundStyle(paper.opacity(0.7))
                        .padding(.horizontal, 16).frame(height: 30, alignment: .leading)
                }
                .frame(width: 300, height: 210, alignment: .topLeading)
                .background(Rectangle().fill(red))

                VStack(alignment: .leading, spacing: 0) {
                    ForEach(["今日支线", "回一封邮件", "整理本月会议记录"], id: \.self) { t in
                        Text(t)
                            .font(t == "今日支线" ? fMono(8.5) : fSerif(15, t != "今日支线"))
                            .tracking(t == "今日支线" ? 2 : 0)
                            .foregroundStyle(t == "今日支线" ? ink.opacity(0.5) : ink)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .frame(height: 44)
                            .overlay(alignment: .bottom) { Rectangle().fill(ink.opacity(0.15)).frame(height: 0.7) }
                    }
                    Spacer()
                    HStack {
                        Text("＋ 添加").font(fSans(11)).foregroundStyle(ink.opacity(0.6))
                        Spacer()
                        Text("→").font(fSans(12)).foregroundStyle(gold)
                    }
                    .frame(height: 34)
                }
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .padding(.horizontal, 14)
            }
            .padding(.horizontal, 30)
            .padding(.top, 20)

            Spacer(minLength: 0)
            HStack {
                Text("三根腿，一块木板。不该有的都不加。").font(fSans(11)).foregroundStyle(ink.opacity(0.6))
                Spacer()
                Text("CHOOSE YOURS  →").font(fSans(10, .bold)).tracking(1.5).foregroundStyle(paper)
                    .padding(.horizontal, 18).frame(height: 36).background(Rectangle().fill(red))
            }
            .padding(.horizontal, 30).padding(.bottom, 22)
        }
        .frame(width: 900, height: 560)
        .background(paper)
    }
}
