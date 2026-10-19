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

/// 卡片物种：每个主题的卡片是那个世界的一件「实物」。
public enum CardStyle {
    case atelier   // 工单 / 吊牌
    case herbarium // 标本标签
    case acid      // 贴纸 / 告示
    case blueprint // 图纸标题栏
}

/// 四套浅色主题。颜色、字体、卡片物种都由这里派发。
public enum Theme {

    nonisolated(unsafe) private static var current = AppSettings()

    @MainActor
    public static func apply(_ settings: AppSettings) {
        current = settings
        // 所有主题都是浅色的：系统控件也固定用亮色外观，避免系统深色模式下控件发黑。
        NSApplication.shared.appearance = NSAppearance(named: .aqua)
    }

    public static var choice: ThemeChoice { current.theme }

    public static var cardStyle: CardStyle {
        switch current.theme {
        case .atelier: return .atelier
        case .herbarium: return .herbarium
        case .acid: return .acid
        case .blueprint: return .blueprint
        }
    }

    // MARK: - 主题色板

    private struct Spec {
        let canvas: UInt32
        let surface: UInt32
        let surfaceAlt: UInt32
        let ink: UInt32
        let ink2: UInt32
        let ink3: UInt32
        let ruleOpacity: Double
        let fill: UInt32
        let fillInk: UInt32
        let todayFill: UInt32
        let todayInk: UInt32
        let accent: UInt32
        let accentSoft: UInt32
        let stamp: UInt32
        let dayBackground: UInt32
        let cardBackground: UInt32
        let cardInk: UInt32
        let cardBorder: UInt32
        let cardBorderOpacity: Double
        let gridOpacity: Double
    }

    private static var spec: Spec {
        switch current.theme {
        case .atelier:
            return Spec(
                canvas: 0xF2EFE6, surface: 0xFBF8F0, surfaceAlt: 0xE6E1D3,
                ink: 0x1C2A22, ink2: 0x5A6358, ink3: 0x899085, ruleOpacity: 0.20,
                fill: 0x233A2E, fillInk: 0xF3EFE2, todayFill: 0xDAD6C9, todayInk: 0x1C2A22,
                accent: 0x2F4A3A, accentSoft: 0xDEE4D7, stamp: 0x2F4A3A,
                dayBackground: 0xE7EADF, cardBackground: 0xFBF8F0, cardInk: 0x1C2A22,
                cardBorder: 0x1C2A22, cardBorderOpacity: 0.55, gridOpacity: 0
            )
        case .herbarium:
            return Spec(
                canvas: 0xE9E5D6, surface: 0xF4F1E5, surfaceAlt: 0xD3DEC5,
                ink: 0x1C241D, ink2: 0x4F5A50, ink3: 0x7C857A, ruleOpacity: 0.22,
                fill: 0xC9D9BF, fillInk: 0x1C241D, todayFill: 0xDAD6C9, todayInk: 0x1C241D,
                accent: 0x3F7A4E, accentSoft: 0xD9E2CF, stamp: 0x3F7A4E,
                dayBackground: 0xF4F1E5, cardBackground: 0xDFE4D3, cardInk: 0x1C241D,
                cardBorder: 0x1C241D, cardBorderOpacity: 0.50, gridOpacity: 0
            )
        case .acid:
            return Spec(
                canvas: 0x10231B, surface: 0xE7F86B, surfaceAlt: 0x1A3327,
                ink: 0xF2F0E4, ink2: 0xAAB5A6, ink3: 0x768578, ruleOpacity: 0.22,
                fill: 0xE7F86B, fillInk: 0x11140F, todayFill: 0xD8D5C7, todayInk: 0x11140F,
                accent: 0xE7F86B, accentSoft: 0x274536, stamp: 0x11140F,
                dayBackground: 0x10231B, cardBackground: 0xE7F86B, cardInk: 0x11140F,
                cardBorder: 0x0A1710, cardBorderOpacity: 0.85, gridOpacity: 0
            )
        case .blueprint:
            return Spec(
                canvas: 0xE6EBE6, surface: 0xF7F8F3, surfaceAlt: 0xEDF1EC,
                ink: 0x23496B, ink2: 0x456A86, ink3: 0x7A93A5, ruleOpacity: 0.25,
                fill: 0x23496B, fillInk: 0xF7F8F3, todayFill: 0xDCE0D8, todayInk: 0x23496B,
                accent: 0xD96A2B, accentSoft: 0xF0DCCB, stamp: 0xD96A2B,
                dayBackground: 0xF7F8F3, cardBackground: 0xF7F8F3, cardInk: 0x23496B,
                cardBorder: 0x23496B, cardBorderOpacity: 0.65, gridOpacity: 0.10
            )
        }
    }

    private static func hex(_ v: UInt32) -> Color {
        Color(.sRGB,
              red: Double((v >> 16) & 0xFF) / 255,
              green: Double((v >> 8) & 0xFF) / 255,
              blue: Double(v & 0xFF) / 255, opacity: 1)
    }

    // MARK: - 颜色

    public static var canvas: Color { hex(spec.canvas) }
    public static var paper: Color { canvas }
    public static var paperDeep: Color { hex(spec.surfaceAlt) }
    public static var surface: Color { hex(spec.cardBackground) }
    public static var surfaceAlt: Color { hex(spec.surfaceAlt) }
    public static var ink: Color { hex(spec.ink) }
    public static var ink2: Color { hex(spec.ink2) }
    public static var ink3: Color { hex(spec.ink3) }
    public static var rule: Color { ink.opacity(spec.ruleOpacity) }
    public static var hairline: Color { rule }
    public static var rail: Color { ink.opacity(spec.ruleOpacity + 0.12) }
    public static var control: Color { ink.opacity(0.62) }
    public static var faint: Color { ink.opacity(0.40) }
    public static var doneInk: Color { ink.opacity(0.52) }

    public static var fill: Color { hex(spec.fill) }
    public static var fillInk: Color { hex(spec.fillInk) }
    public static var todayFill: Color { hex(spec.todayFill) }
    public static var todayInk: Color { hex(spec.todayInk) }
    public static var accent: Color { hex(spec.accent) }
    public static var accentInk: Color { accent }
    public static var accentSoft: Color { hex(spec.accentSoft) }
    public static var stamp: Color { hex(spec.stamp) }

    /// 日页整块的底色；卡片在它上面。
    public static var dayBackground: Color { hex(spec.dayBackground) }
    /// 卡片纸色与卡片上的墨色。
    public static var cardBackground: Color { hex(spec.cardBackground) }
    public static var cardInk: Color { hex(spec.cardInk) }
    public static var cardBorder: Color { hex(spec.cardBorder).opacity(spec.cardBorderOpacity) }

    /// 日页上的正文色（在 dayBackground 上）。
    public static var dayInk: Color { ink }
    public static var dayInk2: Color { dayInk.opacity(0.68) }
    public static var dayInk3: Color { dayInk.opacity(0.45) }
    public static var dayRule: Color { dayInk.opacity(0.22) }

    public static var gridLine: Color { hex(spec.cardInk).opacity(spec.gridOpacity) }

    // MARK: - 字体

    public static var fontScale: CGFloat { current.fontScale.factor }
    public static var soundEnabled: Bool { current.soundEnabled }

    /// 主题的展示声部：标题、日期、月名、卡片大标题。
    public static func display(_ size: CGFloat) -> Font {
        let scaled = size * fontScale
        switch current.theme {
        case .atelier: return .custom("Songti SC Bold", size: scaled)
        case .herbarium: return .system(size: scaled, weight: .heavy)
        case .acid: return .system(size: scaled, weight: .black)
        case .blueprint: return .system(size: scaled, weight: .heavy)
        }
    }

    public static func displayTracking(_ size: CGFloat) -> CGFloat {
        switch current.theme {
        case .acid: return -size * 0.035
        case .blueprint: return -size * 0.01
        default: return 0
        }
    }

    /// 与当前主题无关的衬线预览（设置、工单编号等）。
    public static func serifPreview(_ size: CGFloat) -> Font {
        .custom("Songti SC Bold", size: size * fontScale)
    }

    /// 设置页的主题预览用：这套主题的展示字（不随当前主题变）。
    public static func previewDisplay(_ theme: ThemeChoice, _ size: CGFloat) -> Font {
        switch theme {
        case .atelier: return .custom("Songti SC Bold", size: size)
        case .herbarium: return .system(size: size, weight: .heavy)
        case .acid: return .system(size: size, weight: .black)
        case .blueprint: return .system(size: size, weight: .heavy)
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

    // MARK: - 字号表

    public static let monthDisplaySize: CGFloat = 64
    public static let dateDisplaySize: CGFloat = 104
    public static let taskDisplaySize: CGFloat = 34
    public static let cardTitleSize: CGFloat = 27
    public static let dateSize: CGFloat = 19
    public static let sectionSize: CGFloat = 11
    public static let mainSize: CGFloat = 15.5
    public static let branchSize: CGFloat = 14.5
    public static let level2Size: CGFloat = 13
    public static let level3Size: CGFloat = 12
    public static let metaSize: CGFloat = 10.5
    public static let controlSize: CGFloat = 12.5
    public static let inputSize: CGFloat = 13.5

    public static var sectionFont: Font { mono(sectionSize, .semibold) }

    public static func titleFont(_ level: Int, isMain: Bool = false) -> Font {
        if level == 1 { return display(isMain ? mainSize + 4 : branchSize + 4) }
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

    public static func rowHeight(_ level: Int) -> CGFloat {
        let base: CGFloat = level == 1 ? 40 : (level == 2 ? 32 : 28)
        return (base * fontScale).rounded()
    }

    public static func ringSize(_ level: Int) -> CGFloat {
        let base: CGFloat = level == 1 ? 18 : (level == 2 ? 15 : 13)
        return (base * fontScale).rounded()
    }

    public static func railCount(_ level: Int) -> Int { max(0, level - 1) }
}
