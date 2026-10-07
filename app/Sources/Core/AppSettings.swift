import Foundation
import CoreGraphics

/// 深浅色模式。
public enum AppearanceMode: String, Codable, CaseIterable, Equatable {
    case system, light, dark

    public var label: String {
        switch self {
        case .system: return "跟随系统"
        case .light: return "浅色"
        case .dark: return "深色"
        }
    }
}

/// 强调色：只影响「今天」与进行中的事，不做整套换肤。
public enum AccentChoice: String, Codable, CaseIterable, Equatable {
    case blue, vermilion, indigo, pine, graphite

    public var label: String {
        switch self {
        case .blue: return "品牌蓝"
        case .vermilion: return "朱红"
        case .indigo: return "靛蓝"
        case .pine: return "松绿"
        case .graphite: return "石墨"
        }
    }
}

/// 纸面色调。
public enum PaperTone: String, Codable, CaseIterable, Equatable {
    case front, blue, warm, cool, plain

    public var label: String {
        switch self {
        case .front: return "浅灰"
        case .blue: return "浅蓝"
        case .warm: return "暖纸"
        case .cool: return "冷纸"
        case .plain: return "纯白"
        }
    }
}

/// 字体风格：纸墨＝标题走衬线（更有纸感）；苹果风＝全部用系统无衬线（干净、扁平）。
public enum FontChoice: String, Codable, CaseIterable, Equatable {
    case ink, apple

    public var label: String {
        switch self {
        case .ink: return "纸墨"
        case .apple: return "苹果风"
        }
    }

    public var note: String {
        switch self {
        case .ink: return "标题用衬线，更像纸上写字。"
        case .apple: return "全部用系统无衬线，线条干净、扁平。"
        }
    }
}

/// 字号档位。
public enum FontScale: String, Codable, CaseIterable, Equatable {
    case small, medium, large

    public var label: String {
        switch self {
        case .small: return "小"
        case .medium: return "中"
        case .large: return "大"
        }
    }

    public var factor: CGFloat {
        switch self {
        case .small: return 0.92
        case .medium: return 1.0
        case .large: return 1.14
        }
    }
}

/// 应用设置。随数据一起落盘，导出备份时一并带上。
public struct AppSettings: Codable, Equatable {
    public var appearance: AppearanceMode
    public var accent: AccentChoice
    public var paper: PaperTone
    public var fontScale: FontScale
    public var font: FontChoice

    public init(
        appearance: AppearanceMode = .system,
        accent: AccentChoice = .blue,
        paper: PaperTone = .front,
        fontScale: FontScale = .medium,
        font: FontChoice = .apple
    ) {
        self.appearance = appearance
        self.accent = accent
        self.paper = paper
        self.fontScale = fontScale
        self.font = font
    }

    /// 容错解码：老数据文件缺字段时用默认值，不丢用户数据。
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        appearance = try c.decodeIfPresent(AppearanceMode.self, forKey: .appearance) ?? .system
        accent = try c.decodeIfPresent(AccentChoice.self, forKey: .accent) ?? .blue
        paper = try c.decodeIfPresent(PaperTone.self, forKey: .paper) ?? .front
        fontScale = try c.decodeIfPresent(FontScale.self, forKey: .fontScale) ?? .medium
        font = try c.decodeIfPresent(FontChoice.self, forKey: .font) ?? .apple
    }
}

/// 配色方案预设：一套「纸面色调 + 强调色」。字号与深浅色独立于预设。
public struct ThemePreset: Identifiable, Equatable {
    public let id: String
    public let name: String
    public let note: String
    public let paper: PaperTone
    public let accent: AccentChoice

    public init(id: String, name: String, note: String, paper: PaperTone, accent: AccentChoice) {
        self.id = id
        self.name = name
        self.note = note
        self.paper = paper
        self.accent = accent
    }

    public func matches(_ settings: AppSettings) -> Bool {
        settings.paper == paper && settings.accent == accent
    }

    public static let all: [ThemePreset] = [
        ThemePreset(id: "front", name: "清爽", note: "浅灰底配纯白卡片与品牌蓝，克制的现代感。", paper: .front, accent: .blue),
        ThemePreset(id: "warm", name: "暖纸", note: "暖调米纸配朱红，最像纸上写计划。", paper: .warm, accent: .vermilion),
        ThemePreset(id: "ink", name: "墨蓝", note: "冷调灰蓝，清晰利落，适合长时间盯。", paper: .cool, accent: .indigo),
        ThemePreset(id: "charcoal", name: "炭墨", note: "纯白纸面配石墨，对比最高、最清楚。", paper: .plain, accent: .graphite),
        ThemePreset(id: "tea", name: "茶白", note: "暖纸配松绿，安静不刺眼。", paper: .warm, accent: .pine)
    ]
}
