import Foundation
import CoreGraphics

/// 主题：4.0 起只有两套——排印日课（默认，纸与朱砂）与夜之城终端（深色）。
/// 2.0 的三套「世界」（器物 / 标本室 / 蓝图 / 酸纸）已退役，旧数据自动落到日课。
public enum ThemeChoice: String, Codable, CaseIterable, Equatable {
    case rike    // 排印日课
    case night   // 夜之城终端

    public static var available: [ThemeChoice] { [.rike, .night] }

    public var label: String {
        switch self {
        case .rike: return "日课"
        case .night: return "夜之城"
        }
    }

    public var en: String {
        switch self {
        case .rike: return "RIKE"
        case .night: return "NIGHT CITY"
        }
    }

    public var note: String {
        switch self {
        case .rike: return "纸 #FAF9F5、墨 #1A1A18、朱砂 #C3402B。层级交给字号，红色只出现在今天。"
        case .night: return "夜 #0C0D11、黄 #FCEE0A、青 #3AE0E6。主线＝Main Job，切角面板与三种霓虹。"
        }
    }

    /// 2.0 旧主题值 → 4.0 主题（全部落到日课）。
    public static func migrate(_ raw: String) -> ThemeChoice {
        ThemeChoice(rawValue: raw) ?? .rike
    }
}

/// 字号档位（无障碍用）。
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
        case .small: return 1.0
        case .medium: return 1.10
        case .large: return 1.26
        }
    }
}

/// 应用设置。随数据一起落盘，导出备份时一并带上。
public struct AppSettings: Codable, Equatable {
    public var theme: ThemeChoice
    public var fontScale: FontScale
    /// 启动时静默检查是否有新版
    public var autoCheckUpdates: Bool
    /// 完成 / 翻页时的轻音效与触感
    public var soundEnabled: Bool
    public init(
        theme: ThemeChoice = .rike,
        fontScale: FontScale = .medium,
        autoCheckUpdates: Bool = true,
        soundEnabled: Bool = true
    ) {
        self.theme = theme
        self.fontScale = fontScale
        self.autoCheckUpdates = autoCheckUpdates
        self.soundEnabled = soundEnabled
    }

    /// 容错解码：2.0 的旧主题值（atelier / herbarium / acid / blueprint）一律落到日课，不丢数据。
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        // 先按字符串读再迁移：直接 decode 枚举遇到旧值会抛错，导致整个数据文件读不进来。
        let rawTheme = try c.decodeIfPresent(String.self, forKey: .theme)
        theme = rawTheme.map { ThemeChoice.migrate($0) } ?? .rike
        fontScale = try c.decodeIfPresent(FontScale.self, forKey: .fontScale) ?? .medium
        autoCheckUpdates = try c.decodeIfPresent(Bool.self, forKey: .autoCheckUpdates) ?? true
        soundEnabled = try c.decodeIfPresent(Bool.self, forKey: .soundEnabled) ?? true
    }
}
