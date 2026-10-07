import SwiftUI
import Core

/// 圆形勾选圈：本产品唯一的「完成」操作，尺寸随层级递减。
public struct RingView: View {
    public let level: Int
    public let done: Bool
    public let action: () -> Void
    @State private var hovering = false

    public init(level: Int, done: Bool, action: @escaping () -> Void) {
        self.level = level
        self.done = done
        self.action = action
    }

    public var body: some View {
        let size = Theme.ringSize(level)
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(done ? Theme.accent : Color.clear)
                    .frame(width: size, height: size)
                Circle()
                    .strokeBorder(
                        done ? Theme.accent : (hovering ? Theme.accent : Theme.control),
                        lineWidth: level == 1 ? 1.8 : 1.5
                    )
                    .frame(width: size, height: size)
                if done {
                    Image(systemName: "checkmark")
                        .font(.system(size: size * 0.52, weight: .bold))
                        .foregroundStyle(Theme.surface)
                }
            }
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }
}

/// 角色 / 等级图标：◆ 主线、● 支线、▫ 二级、▪ 三级及以下。
/// 刻意避开圆形——完成圆环已经是圆，再用圆会撞在一起。
public struct RoleGlyph: View {
    public let isMain: Bool
    public let level: Int

    public init(isMain: Bool, level: Int) {
        self.isMain = isMain
        self.level = level
    }

    public var body: some View {
        Group {
            if level <= 1 && isMain {
                Text("◆")
                    .font(.system(size: 10))
                    .foregroundStyle(Theme.accent)
            } else if level <= 1 {
                Circle()
                    .fill(Theme.ink2)
                    .frame(width: 6, height: 6)
            } else if level == 2 {
                Rectangle()
                    .strokeBorder(Theme.ink3, lineWidth: 1.2)
                    .frame(width: 6.5, height: 6.5)
            } else {
                Rectangle()
                    .fill(Theme.faint)
                    .frame(width: 4.5, height: 4.5)
            }
        }
        .frame(width: 14, height: 14)
    }
}

/// 树线：每一级一条竖向细线；相邻行首尾相接，形成连续的层级导轨。
public struct TreeRails: View {
    public let level: Int

    public init(level: Int) {
        self.level = level
    }

    public var body: some View {
        HStack(spacing: 0) {
            ForEach(0..<Theme.railCount(level), id: \.self) { _ in
                Rectangle()
                    .fill(Theme.rail)
                    .frame(width: 1)
                    .frame(maxHeight: .infinity)
                Spacer(minLength: 0).frame(width: Theme.indentStep - 1)
            }
        }
    }
}

/// 只有图标的极简按钮。
public struct IconButton: View {
    public let systemName: String
    public let help: String
    public let action: () -> Void
    @State private var hovering = false

    public init(systemName: String, help: String, action: @escaping () -> Void) {
        self.systemName = systemName
        self.help = help
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(hovering ? Theme.ink : Theme.ink3)
                .frame(width: 22, height: 22)
                .background(
                    RoundedRectangle(cornerRadius: 5)
                        .fill(hovering ? Theme.surfaceAlt : Color.clear)
                )
        }
        .buttonStyle(.plain)
        .help(help)
        .onHover { hovering = $0 }
    }
}

/// 文字按钮（页头用）。
public struct TextButton: View {
    public let title: String
    public let badge: Int?
    public let prominent: Bool
    public let action: () -> Void
    @State private var hovering = false

    public init(_ title: String, badge: Int? = nil, prominent: Bool = false, action: @escaping () -> Void) {
        self.title = title
        self.badge = badge
        self.prominent = prominent
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Text(title).font(Theme.sans(12.5, .medium))
                if let badge, badge > 0 {
                    Text("\(badge)")
                        .font(Theme.sans(11, .semibold))
                        .foregroundStyle(Theme.ink2)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(Capsule().fill(Theme.surfaceAlt))
                }
            }
            .foregroundStyle(prominent ? Theme.ink : (hovering ? Theme.ink : Theme.ink2))
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(prominent ? Theme.surfaceAlt : (hovering ? Theme.surfaceAlt : Color.clear))
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }
}

/// 底部提示条，可携带「撤销」。
public struct ToastBar: View {
    public let text: String
    public let hasUndo: Bool
    public let undo: () -> Void

    public init(text: String, hasUndo: Bool, undo: @escaping () -> Void) {
        self.text = text
        self.hasUndo = hasUndo
        self.undo = undo
    }

    public var body: some View {
        HStack(spacing: 14) {
            Text(text)
                .font(Theme.sans(13))
                .foregroundStyle(Theme.surface)
            if hasUndo {
                Button(action: undo) {
                    Text("撤销")
                        .font(Theme.sans(13, .semibold))
                        .foregroundStyle(Theme.surface)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(Color.white.opacity(0.16)))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Theme.ink)
        )
        .shadow(color: Color.black.opacity(0.22), radius: 14, y: 5)
    }
}

/// 一条水平线，配合 stroke 的 dash 用来画书写虚线。
public struct HorizontalRule: Shape {
    public init() {}

    public func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        return path
    }
}

/// 一级标题（面板内的小标题）。
public struct SectionLabel: View {
    public let text: String
    public let trailing: String?

    public init(_ text: String, trailing: String? = nil) {
        self.text = text
        self.trailing = trailing
    }

    public var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(text)
                .font(Theme.sans(11.5, .semibold))
                .foregroundStyle(Theme.ink3)
                .tracking(1.2)
            Spacer()
            if let trailing {
                Text(trailing)
                    .font(Theme.sans(11.5))
                    .foregroundStyle(Theme.faint)
            }
        }
    }
}
