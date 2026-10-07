import SwiftUI
import AppKit
import Core

extension NSColor {
    convenience init(hex: UInt32) {
        let r = CGFloat((hex >> 16) & 0xFF) / 255
        let g = CGFloat((hex >> 8) & 0xFF) / 255
        let b = CGFloat(hex & 0xFF) / 255
        self.init(srgbRed: r, green: g, blue: b, alpha: 1)
    }
}

extension Color {
    /// 随系统明暗自动切换的颜色。
    init(light: UInt32, dark: UInt32) {
        self.init(nsColor: NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            return NSColor(hex: isDark ? dark : light)
        })
    }
}

/// 动效：安静、短促，不弹跳。
public enum Motion {
    /// 悬停、按压这类即时反馈。
    public static let quick = Animation.easeOut(duration: 0.12)
    /// 列表增删、移动、角色变化。
    public static let spring = Animation.spring(response: 0.34, dampingFraction: 0.86)
    /// 切换日期、切换视图这类整体过渡。
    public static let soft = Animation.easeInOut(duration: 0.26)
    /// 圆环打勾。
    public static let ring = Animation.spring(response: 0.26, dampingFraction: 0.66)
}

/// 视觉系统「纸 · 日历」：暖纸底、墨色字、强调色只标记今天与进行中的事。
/// 颜色与字号由 AppSettings 驱动（外观设置），其余界面代码只读这里。
public enum Theme {

    // MARK: 当前设置

    nonisolated(unsafe) private static var current = AppSettings()

    /// 应用外观设置：界面重绘前调用一次即可，同时同步系统控件的外观。
    @MainActor
    public static func apply(_ settings: AppSettings) {
        // 设置没变就什么也不做：重设 NSApplication.appearance 会触发全窗口重画
        guard settings != current else { return }
        let appearanceChanged = settings.appearance != current.appearance
        current = settings
        guard appearanceChanged else { return }
        switch settings.appearance {
        case .system:
            NSApplication.shared.appearance = nil
        case .light:
            NSApplication.shared.appearance = NSAppearance(named: .aqua)
        case .dark:
            NSApplication.shared.appearance = NSAppearance(named: .darkAqua)
        }
    }

    /// 颜色缓存：key = 外观模式 + 明色 + 暗色。这些值只在换配色/换深浅色时变。
    private static var colorCache: [UInt64: Color] = [:]

    private static func dyn(_ light: UInt32, _ dark: UInt32) -> Color {
        let mode: UInt64 = current.appearance == .system ? 0 : (current.appearance == .light ? 1 : 2)
        let key = mode << 60 | UInt64(light) << 28 | UInt64(dark)
        if let cached = colorCache[key] { return cached }
        let color: Color
        switch current.appearance {
        case .system: color = Color(light: light, dark: dark)
        case .light: color = Color(light: light, dark: light)
        case .dark: color = Color(light: dark, dark: dark)
        }
        colorCache[key] = color
        return color
    }

    // MARK: 纸面色调

    /// 墨色族：冷色纸配冷调墨，暖色纸配暖调墨——冷纸上写暖灰会发浑。
    private enum InkFamily { case warm, cool }

    private struct Tone {
        let paper: UInt32, paperDeep: UInt32, surface: UInt32, surfaceAlt: UInt32, hairline: UInt32, rail: UInt32
        let paperD: UInt32, paperDeepD: UInt32, surfaceD: UInt32, surfaceAltD: UInt32, hairlineD: UInt32, railD: UInt32
        let inkFamily: InkFamily

        static let front = Tone(
            paper: 0xF5F6F7, paperDeep: 0xEBEDF0, surface: 0xFFFFFF, surfaceAlt: 0xF2F3F5, hairline: 0xE5E6EB, rail: 0xC9CDD4,
            paperD: 0x17171A, paperDeepD: 0x1F1F23, surfaceD: 0x232324, surfaceAltD: 0x2B2B2E, hairlineD: 0x3A3A3E, railD: 0x4E4E52,
            inkFamily: .cool
        )
        static let blue = Tone(
            paper: 0xEAF1F7, paperDeep: 0xDDE7F0, surface: 0xFFFFFF, surfaceAlt: 0xD8E4EF, hairline: 0xCFDDE9, rail: 0xB6C6D6,
            paperD: 0x14181C, paperDeepD: 0x101316, surfaceD: 0x1E2429, surfaceAltD: 0x181E23, hairlineD: 0x2C343B, railD: 0x414B54,
            inkFamily: .cool
        )

        static let warm = Tone(
            paper: 0xF3F0E7, paperDeep: 0xE9E4D6, surface: 0xFFFDF8, surfaceAlt: 0xE7E1D2, hairline: 0xDCD6C6, rail: 0xC4BCA8,
            paperD: 0x171614, paperDeepD: 0x121110, surfaceD: 0x222120, surfaceAltD: 0x1D1C1A, hairlineD: 0x322F2B, railD: 0x4A453D,
            inkFamily: .warm
        )
        static let cool = Tone(
            paper: 0xEEF1F1, paperDeep: 0xE3E8E8, surface: 0xFBFDFD, surfaceAlt: 0xE1E6E6, hairline: 0xD4DBDA, rail: 0xB8C2C0,
            paperD: 0x15181A, paperDeepD: 0x101314, surfaceD: 0x1F2224, surfaceAltD: 0x1A1D1F, hairlineD: 0x2E3335, railD: 0x454C4E,
            inkFamily: .cool
        )
        static let plain = Tone(
            paper: 0xF6F6F4, paperDeep: 0xECECEA, surface: 0xFFFFFF, surfaceAlt: 0xE9E9E6, hairline: 0xDDDDD9, rail: 0xC5C5BF,
            paperD: 0x1A1A1A, paperDeepD: 0x141414, surfaceD: 0x232323, surfaceAltD: 0x1E1E1E, hairlineD: 0x333333, railD: 0x4A4A4A,
            inkFamily: .warm
        )

        static func of(_ tone: PaperTone) -> Tone {
            switch tone {
            case .front: return .front
            case .blue: return .blue
            case .warm: return .warm
            case .cool: return .cool
            case .plain: return .plain
            }
        }
    }

    private static var tone: Tone { Tone.of(current.paper) }

    // MARK: 颜色

    public static var paper: Color { dyn(tone.paper, tone.paperD) }
    public static var paperDeep: Color { dyn(tone.paperDeep, tone.paperDeepD) }
    public static var surface: Color { dyn(tone.surface, tone.surfaceD) }
    public static var surfaceAlt: Color { dyn(tone.surfaceAlt, tone.surfaceAltD) }
    public static var hairline: Color { dyn(tone.hairline, tone.hairlineD) }
    public static var rail: Color { dyn(tone.rail, tone.railD) }

    private static var inkPalette: (ink: UInt32, ink2: UInt32, ink3: UInt32, control: UInt32,
                                    inkD: UInt32, ink2D: UInt32, ink3D: UInt32, controlD: UInt32) {
        if tone.inkFamily == .cool {
            // 冷色纸（浅灰 / 浅蓝 / 冷纸）：冷调墨。
            // ink3 5.35:1、control 3.1:1，均达标；faint 2.8:1 只做装饰。
            return (0x1F2329, 0x646A73, 0x61666D, 0x878D96,
                    0xE8E9EA, 0xA6A8AD, 0x9A9DA3, 0x8A8D93)
        }
        return (0x23211E, 0x5C584F, 0x6F6857, 0x8F8A7A,
                0xF2EFE8, 0xB5AFA1, 0x9A9488, 0x807B71)
    }

    public static var ink: Color { dyn(inkPalette.ink, inkPalette.inkD) }
    public static var ink2: Color { dyn(inkPalette.ink2, inkPalette.ink2D) }
    /// 次要文字：各纸色上均 ≥4.5:1
    public static var ink3: Color { dyn(inkPalette.ink3, inkPalette.ink3D) }
    /// 可交互控件（完成圆环等）的描边色：UI 控件按 WCAG 需要 ≥3:1。
    public static var control: Color { dyn(inkPalette.control, inkPalette.controlD) }

    /// **纯装饰色**：只用于不需要阅读的地方（远超/未来的日期数字、拖动把手、点线）。
    /// 不要用它写任何需要看清的文字——它的对比度只有 2.2:1。
    public static var faint: Color {
        tone.inkFamily == .cool ? dyn(0x8F959E, 0x75777C) : dyn(0xA9A395, 0x615C53)
    }
    /// 已完成文字：仍要能读，所以比 faint 深一档
    public static var doneInk: Color {
        tone.inkFamily == .cool ? dyn(0x6B7078, 0x8E9298) : dyn(0x8F897B, 0x827C70)
    }

    private static var accentPair: (UInt32, UInt32) {
        switch current.accent {
        case .blue: return (0x3370FF, 0x4E83FD)
        case .vermilion: return (0xC4462B, 0xCE5B3E)
        case .indigo: return (0x3D5C99, 0x7396D8)
        case .pine: return (0x2F6F5E, 0x5FA98F)
        case .graphite: return (0x4C4C50, 0xA6A6AD)
        }
    }

    /// 品牌蓝作为**文字**时的颜色：比填充蓝深一档，纸色上 5.4:1。
    public static var accentInk: Color {
        current.accent == .blue ? dyn(0x245BDB, 0x6E9BFF) : accent
    }

    private static var accentSoftPair: (UInt32, UInt32) {
        switch current.accent {
        case .blue: return (0xE1E9FF, 0x1E2A45)
        case .vermilion: return (0xF6E2DA, 0x3A2620)
        case .indigo: return (0xE1E7F3, 0x22283A)
        case .pine: return (0xDFEDE8, 0x1D2C28)
        case .graphite: return (0xE7E7E9, 0x2A2A2D)
        }
    }

    public static var accent: Color { dyn(accentPair.0, accentPair.1) }
    public static var accentSoft: Color { dyn(accentSoftPair.0, accentSoftPair.1) }

    // MARK: 字体（衬线只用于日期与数字，任务文字一律无衬线）

    private static var scale: CGFloat { current.fontScale.factor }

    /// 「纸墨」风格的中文衬线：系统自带的**宋体**。
    /// 注意：`.system(design: .serif)` 对中文几乎不生效（会回退到同一款无衬线），
    /// 只有数字和拉丁字会变——所以这里必须点名中文字体，否则"纸墨"看不出差别。
    private static let inkFontName = "Songti SC"
    private static let inkFontBoldName = "Songti SC Bold"

    /// 标题声部：纸墨 → 宋体（粗体显式取 Bold，否则 semibold 会落回常规）；
    /// 苹果风 → 系统无衬线（平、干净）。
    public static func serif(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        let bold = (weight == .semibold || weight == .bold || weight == .heavy || weight == .black)
        if current.font == .apple {
            return .system(size: size * scale, weight: weight, design: .default)
        }
        return .custom(bold ? inkFontBoldName : inkFontName, size: size * scale)
    }

    public static func sans(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .system(size: size * scale, weight: weight)
    }

    // MARK: 层级度量

    public static var indentStep: CGFloat { 22 * scale }

    public static func rowHeight(_ level: Int) -> CGFloat {
        let base: CGFloat
        switch level {
        case 1: base = 37
        case 2: base = 30
        default: base = 27
        }
        return (base * scale).rounded()
    }

    public static func ringSize(_ level: Int) -> CGFloat {
        let base: CGFloat
        switch level {
        case 1: base = 18
        case 2: base = 15
        default: base = 13
        }
        return (base * scale).rounded()
    }

    // MARK: 字号表（全应用只用这几档，避免各处大小不一）

    /// 日页日期
    public static let dateSize: CGFloat = 19
    /// 分栏标题（今日主线 / 今日支线 / 今日完成）：与一级任务同档，属于"章"这一层
    public static let sectionSize: CGFloat = 15.5
    /// 主标题（主线）
    public static let mainSize: CGFloat = 15.5
    /// 一级支线标题
    public static let branchSize: CGFloat = 14.5
    /// 二级
    public static let level2Size: CGFloat = 13
    /// 三级及以下
    public static let level3Size: CGFloat = 12
    /// 次要信息（日期、上级路径、计数）
    public static let metaSize: CGFloat = 11
    /// 按钮与控件
    public static let controlSize: CGFloat = 12.5
    /// 输入框正文
    public static let inputSize: CGFloat = 13

    /// 全局唯一的任务笔迹系统：一级 = 墨色；二级 = 次墨色，缩进 1 格；三级 = 浅墨色，缩进 2 格。
    /// 分栏标题的字体：属标题声部，所以纸墨风格下也是宋体。
    public static var sectionFont: Font { serif(sectionSize, .semibold) }

    public static func titleFont(_ level: Int, isMain: Bool = false) -> Font {
        // 一级任务就是卡片标题：跟"日页日期"同一声部。
        // 纸墨风格 → 衬线；苹果风 → serif() 内部会换回系统无衬线，所以这里只写一次。
        if level == 1 { return serif(isMain ? mainSize : branchSize, .semibold) }
        if level == 2 { return sans(level2Size) }
        return sans(level3Size)
    }

    public static func titleColor(_ level: Int, isMain: Bool = false) -> Color {
        if level == 1 { return isMain ? ink : ink2 }
        if level == 2 { return ink2 }
        return ink3
    }

    public static func railCount(_ level: Int) -> Int { max(0, level - 1) }
}
