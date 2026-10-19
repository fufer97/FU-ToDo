import Foundation
import CoreGraphics

/// 主题：四套完整的浅色视觉世界。每个主题自带配色、字体与卡片物种。
public enum ThemeChoice: String, Codable, CaseIterable, Equatable {
    case atelier, herbarium, acid, blueprint

    public var label: String {
        switch self {
        case .atelier: return "器物"
        case .herbarium: return "标本室"
        case .acid: return "酸纸"
        case .blueprint: return "蓝图"
        }
    }

    public var en: String {
        switch self {
        case .atelier: return "ATELIER"
        case .herbarium: return "HERBARIUM"
        case .acid: return "ACID"
        case .blueprint: return "BLUEPRINT"
        }
    }

    public var note: String {
        switch self {
        case .atelier: return "奶油纸、宋体、赭红整页，像一页装订好的工单。"
        case .herbarium: return "鼠尾草卡、窄黑体、标本标签与条码，默认主题。"
        case .acid: return "荧光黄绿、重黑体、黑贴纸，最冲的一档。"
        case .blueprint: return "图纸底、蓝墨、标题栏与修订章，工具感最强。"
        }
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
        case .small: return 0.92
        case .medium: return 1.0
        case .large: return 1.14
        }
    }
}

/// 应用设置。随数据一起落盘，导出备份时一并带上。
public struct AppSettings: Codable, Equatable {
    public var theme: ThemeChoice
    public var fontScale: FontScale
    /// 启动时静默检查是否有新版
    public var autoCheckUpdates: Bool

    public init(
        theme: ThemeChoice = .herbarium,
        fontScale: FontScale = .medium,
        autoCheckUpdates: Bool = true
    ) {
        self.theme = theme
        self.fontScale = fontScale
        self.autoCheckUpdates = autoCheckUpdates
    }

    /// 容错解码：老数据（有 paper / accent / font 等旧字段、没有 theme）按默认主题读入，不丢数据。
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        theme = try c.decodeIfPresent(ThemeChoice.self, forKey: .theme) ?? .herbarium
        fontScale = try c.decodeIfPresent(FontScale.self, forKey: .fontScale) ?? .medium
        autoCheckUpdates = try c.decodeIfPresent(Bool.self, forKey: .autoCheckUpdates) ?? true
    }
}
