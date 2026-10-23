import SwiftUI
import AppKit
import Core

/// 动效：短、稳、不弹跳。
public enum Motion {
    public static let quick = Animation.easeOut(duration: 0.14)
    public static let spring = Animation.spring(response: 0.30, dampingFraction: 0.90)
    public static let soft = Animation.easeInOut(duration: 0.24)
    public static let ring = Animation.easeOut(duration: 0.18)
}

/// 卡片外壳形态：日课没有卡片（纸上一体），夜之城是切角面板。
public enum CardStyle {
    case rike
    case night
}

/// 4.0 视觉系统「排印日课」：层级交给字号声部，重点交给留白，朱砂只出现在今天。
/// 夜之城是同一套结构的深色换肤：切角面板 + 黄青两色纪律。
public enum Theme {

    nonisolated(unsafe) private static var current = AppSettings()

    @MainActor
    public static func apply(_ settings: AppSettings) {
        current = settings
        // 日课是浅色纸面，夜之城要求系统深色外观（控件、弹窗跟着变）。
        NSApplication.shared.appearance = NSAppearance(
            named: settings.theme == .night ? .darkAqua : .aqua
        )
    }

    public static var choice: ThemeChoice { current.theme }
    public static var isNight: Bool { current.theme == .night }

    public static var cardStyle: CardStyle {
        current.theme == .night ? .night : .rike
    }

    // MARK: - 色板

    private struct Spec {
        let canvas: UInt32
        let surfaceAlt: UInt32
        let ink: UInt32
        let ink2: UInt32
        let ink3: UInt32
        let ruleOpacity: Double
        let fill: UInt32
        let fillInk: UInt32
        let doneFill: UInt32
        let todayFill: UInt32
        let todayInk: UInt32
        let accent: UInt32
        let accentSoft: UInt32
        let stamp: UInt32
        let signal: UInt32
        /// 夜之城：卡片是切角面板；日课：纸上一体（无面板底色）。
        let panel: UInt32
        let panelEnabled: Bool
        let cutCorner: CGFloat
        let cardBorderOpacity: Double
    }

    private static var spec: Spec {
        switch current.theme {
        case .rike:
            return Spec(
                canvas: 0xFAF9F5, surfaceAlt: 0xF0EDE4,
                ink: 0x1A1A18, ink2: 0x57524A, ink3: 0x6E6960, ruleOpacity: 0.14,
                fill: 0x1A1A18, fillInk: 0xFAF9F5, doneFill: 0xF0EDE4,
                todayFill: 0xFAF9F5, todayInk: 0xC3402B,
                accent: 0xC3402B, accentSoft: 0xF5E4DF, stamp: 0xC3402B, signal: 0x57524A,
                panel: 0xFAF9F5, panelEnabled: false, cutCorner: 0, cardBorderOpacity: 0.14
            )
        case .night:
            return Spec(
                canvas: 0x0C0D11, surfaceAlt: 0x171A21,
                ink: 0xE8E6DF, ink2: 0xA8ACB4, ink3: 0x7A8088, ruleOpacity: 0.16,
                fill: 0xFCEE0A, fillInk: 0x0C0D11, doneFill: 0x171A21,
                todayFill: 0x0C0D11, todayInk: 0xFCEE0A,
                accent: 0xFCEE0A, accentSoft: 0x26260F, stamp: 0xFCEE0A, signal: 0x3AE0E6,
                panel: 0x13151B, panelEnabled: true, cutCorner: 14, cardBorderOpacity: 0.18
            )
        }
    }

    private static func hex(_ v: UInt32) -> Color {
        Color(.sRGB,
              red: Double((v >> 16) & 0xFF) / 255,
              green: Double((v >> 8) & 0xFF) / 255,
              blue: Double(v & 0xFF) / 255, opacity: 1)
    }

    // MARK: - 颜色（沿用 2.0 的接口名，视图层不用跟着改）

    public static var canvas: Color { hex(spec.canvas) }
    public static var paper: Color { canvas }
    public static var paperDeep: Color { hex(spec.surfaceAlt) }
    public static var surface: Color { canvas }
    public static var surfaceAlt: Color { hex(spec.surfaceAlt) }
    public static var ink: Color { hex(spec.ink) }
    public static var ink2: Color { hex(spec.ink2) }
    public static var ink3: Color { hex(spec.ink3) }
    public static var rule: Color { ink.opacity(spec.ruleOpacity) }
    public static var hairline: Color { rule }
    public static var rail: Color { ink.opacity(spec.ruleOpacity + 0.10) }
    public static var control: Color { ink.opacity(0.62) }
    public static var faint: Color { ink.opacity(0.40) }
    public static var doneInk: Color { ink.opacity(0.52) }

    public static var fill: Color { hex(spec.fill) }
    public static var fillInk: Color { hex(spec.fillInk) }
    public static var doneFill: Color { hex(spec.doneFill) }
    public static var todayFill: Color { hex(spec.todayFill) }
    public static var todayInk: Color { hex(spec.todayInk) }
    public static var accent: Color { hex(spec.accent) }
    public static var accentInk: Color { accent }
    public static var accentSoft: Color { hex(spec.accentSoft) }
    public static var stamp: Color { hex(spec.stamp) }
    /// 数据色：日课是次墨，夜之城是青。
    public static var signal: Color { hex(spec.signal) }
    /// 警示色：夜之城是洋红（未结标记），日课回落到朱砂。
    public static var warn: Color { current.theme == .night ? hex(0xFF3A6C) : hex(spec.accent) }

    /// 日页与卡片同底（纸上一体）；夜之城里日页就是夜底。
    public static var dayBackground: Color { canvas }
    public static var cardBackground: Color { hex(spec.panel) }
    public static var cardInk: Color { hex(spec.ink) }
    public static var cardBorder: Color { hex(spec.ink).opacity(spec.cardBorderOpacity) }
    public static var panelEnabled: Bool { spec.panelEnabled }
    public static var cutCorner: CGFloat { spec.cutCorner }

    public static var dayInk: Color { ink }
    public static var dayInk2: Color { ink2 }
    public static var dayInk3: Color { ink3 }
    public static var dayRule: Color { rule }

    public static var gridLine: Color { Color.clear }

    // MARK: - 字体

    public static var fontScale: CGFloat { current.fontScale.factor }
    public static var soundEnabled: Bool { current.soundEnabled }

    /// 展示声部：日课用宋体（日期、月名、主线标题），夜之城用 DIN 窄体（拉丁与数字）。
    public static func display(_ size: CGFloat) -> Font {
        let scaled = size * fontScale
        switch current.theme {
        case .rike: return .custom("Songti SC Bold", size: scaled)
        case .night: return .custom("DIN Alternate", size: scaled)
        }
    }

    public static func displayTracking(_ size: CGFloat) -> CGFloat { 0 }

    /// 与当前主题无关的宋体预览（设置页等）。
    public static func serifPreview(_ size: CGFloat) -> Font {
        .custom("Songti SC Bold", size: size * fontScale)
    }

    /// 设置页的主题预览用：这套主题自己的展示字（不随当前主题变）。
    public static func previewDisplay(_ theme: ThemeChoice, _ size: CGFloat) -> Font {
        switch theme {
        case .rike: return .custom("Songti SC Bold", size: size)
        case .night: return .custom("DIN Alternate", size: size)
        }
    }

    public static func sans(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .system(size: size * fontScale, weight: weight)
    }

    public static func mono(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .system(size: size * fontScale, weight: weight, design: .monospaced)
    }

    /// 旧接口：标题声部统一走主题展示字。
    public static func serif(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        display(size)
    }

    // MARK: - 字号表（4.0 排印日课）

    public static let monthDisplaySize: CGFloat = 30   // 刊眉栏月名（宋体）
    public static let dateDisplaySize: CGFloat = 30    // 日页日期行（宋体）
    public static let taskDisplaySize: CGFloat = 31    // 主线标题（宋体）
    public static let cardTitleSize: CGFloat = 27
    public static let dateSize: CGFloat = 19
    public static let sectionSize: CGFloat = 11.5      // 分栏标题（宽字距无衬线）
    public static let mainSize: CGFloat = 15
    public static let branchSize: CGFloat = 14.5
    public static let level2Size: CGFloat = 13
    public static let level3Size: CGFloat = 12
    public static let metaSize: CGFloat = 10.5
    public static let controlSize: CGFloat = 12.5
    public static let inputSize: CGFloat = 13.5
    public static let folioSize: CGFloat = 8.5         // 页边编号

    public static var sectionFont: Font { sans(sectionSize, .medium) }

    public static func titleFont(_ level: Int, isMain: Bool = false) -> Font {
        if level == 1 { return isMain ? display(taskDisplaySize) : sans(branchSize, .medium) }
        if level == 2 { return sans(level2Size) }
        return sans(level3Size)
    }

    public static func titleColor(_ level: Int, isMain: Bool = false) -> Color {
        if level == 1 { return isMain ? ink : ink2 }
        if level == 2 { return ink2 }
        return ink3
    }

    // MARK: - 度量

    public static var indentStep: CGFloat { 22 * fontScale }

    public static func rowHeight(_ level: Int, isMain: Bool = false) -> CGFloat {
        let base: CGFloat
        switch level {
        case 1: base = isMain ? 54 : 38
        case 2: base = 32
        default: base = 28
        }
        return (base * fontScale).rounded()
    }

    public static func ringSize(_ level: Int) -> CGFloat {
        let base: CGFloat = level == 1 ? 18 : (level == 2 ? 15 : 13)
        return (base * fontScale).rounded()
    }

    public static func railCount(_ level: Int) -> Int { max(0, level - 1) }
}
