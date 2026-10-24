import SwiftUI
import Core

/// 勾选框：日课是圆形；夜之城主线子步骤是切角方框、支线是菱形。
/// 本产品唯一的「完成」操作，尺寸随层级递减。
public struct RingView: View {
    public enum Form { case circle, square, diamond }

    public let level: Int
    public let done: Bool
    public let diamond: Bool
    public let tint: Color?
    public let action: () -> Void
    @State private var hovering = false

    public init(level: Int, done: Bool, diamond: Bool = false, tint: Color? = nil, action: @escaping () -> Void) {
        self.level = level
        self.done = done
        self.diamond = diamond
        self.tint = tint
        self.action = action
    }

    private var form: Form {
        if diamond { return .diamond }
        return Theme.isNight ? .square : .circle
    }

    public var body: some View {
        let size = Theme.ringSize(level)
        let stroke = tint ?? Theme.control
        let fill = tint ?? Theme.accent
        Button(action: action) {
            ZStack {
                switch form {
                case .circle:
                    Circle()
                        .fill(done ? fill : Color.clear)
                        .frame(width: size, height: size)
                    Circle()
                        .strokeBorder(done ? fill : (hovering ? fill : stroke), lineWidth: level == 1 ? 1.6 : 1.3)
                        .frame(width: size, height: size)
                case .square:
                    let box = CutCornerShape(radius: max(2.5, size * 0.26))
                    if done { box.fill(fill) }
                    box.stroke(done ? fill : (hovering ? fill : stroke), lineWidth: 1.4)
                case .diamond:
                    let box = Rectangle()
                    if done { box.fill(fill) }
                    box.stroke(done ? fill : (hovering ? fill : stroke), lineWidth: 1.4)
                }
                if done {
                    Image(systemName: "checkmark")
                        .font(.system(size: size * 0.5, weight: .bold))
                        .foregroundStyle(Theme.fillInk)
                }
            }
            .scaleEffect(form == .diamond ? 0.82 : 1)
            .frame(width: size, height: size)
            .contentShape(Rectangle())
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
                if Theme.isNight {
                    // 夜之城：支线的角色标是空心菱形（Side Job）。
                    Rectangle()
                        .strokeBorder(Theme.ink2, lineWidth: 1.2)
                        .frame(width: 6.5, height: 6.5)
                        .rotationEffect(.degrees(45))
                } else {
                    Circle()
                        .fill(Theme.ink2)
                        .frame(width: 6, height: 6)
                }
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
    public let color: Color?

    public init(level: Int, color: Color? = nil) {
        self.level = level
        self.color = color
    }

    public var body: some View {
        HStack(spacing: 0) {
            ForEach(0..<Theme.railCount(level), id: \.self) { _ in
                Rectangle()
                    .fill(color ?? Theme.rail)
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
                .foregroundStyle(hovering ? Theme.ink : Theme.ink2)
                .frame(width: 28, height: 28)
                .background(
                    RoundedRectangle(cornerRadius: 3)
                        .fill(hovering ? Theme.accentSoft : Color.clear)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 3)
                        .strokeBorder(hovering ? Theme.ink.opacity(0.45) : Theme.rule, lineWidth: 0.8)
                )
                .contentShape(Rectangle())
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
                Text(title).font(Theme.sans(12.5, .medium)).lineLimit(1).fixedSize(horizontal: true, vertical: false)
                if let badge {
                    Text("\(badge)")
                        .font(Theme.mono(10.5, .semibold))
                        .foregroundStyle(Theme.canvas)
                        .fixedSize(horizontal: true, vertical: false)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 1.5)
                        .background(Capsule().fill(Theme.ink))
                }
            }
            .foregroundStyle(prominent ? Theme.ink : (hovering ? Theme.ink : Theme.ink2))
            .padding(.horizontal, 11)
            .padding(.vertical, 7)
            .frame(minHeight: 28)
            .background(
                RoundedRectangle(cornerRadius: 3)
                    .fill(hovering ? Theme.accentSoft : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 3)
                    .strokeBorder(hovering ? Theme.ink.opacity(0.45) : Theme.rule, lineWidth: 0.8)
            )
            .contentShape(Rectangle())
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
                .font(Theme.mono(9.5, .semibold))
                .foregroundStyle(Theme.ink3)
                .tracking(1.4)
            Spacer()
            if let trailing {
                Text(trailing)
                    .font(Theme.sans(11.5))
                    .foregroundStyle(Theme.faint)
            }
        }
    }
}

// MARK: 夜之城组件

/// 扫描线：整窗覆盖的 CRT 质感（2.5% 白，不伤对比度，不吃点击）。
public struct Scanlines: View {
    public init() {}

    public var body: some View {
        Canvas { ctx, size in
            let color = GraphicsContext.Shading.color(Color.white.opacity(0.025))
            var y: CGFloat = 0
            while y < size.height {
                ctx.fill(Path(CGRect(x: 0, y: y, width: size.width, height: 1)), with: color)
                y += 3
            }
        }
        .allowsHitTesting(false)
    }
}

/// 斜纹警示条：终端状态行的装饰音。
public struct HazardStripe: View {
    var width: CGFloat = 92

    public init(width: CGFloat = 92) {
        self.width = width
    }

    public var body: some View {
        Canvas { ctx, size in
            let color = GraphicsContext.Shading.color(Theme.accent.opacity(0.5))
            var x: CGFloat = -size.height
            while x < size.width {
                var p = Path()
                p.move(to: CGPoint(x: x, y: size.height))
                p.addLine(to: CGPoint(x: x + size.height, y: 0))
                p.addLine(to: CGPoint(x: x + size.height + 4, y: 0))
                p.addLine(to: CGPoint(x: x + 4, y: size.height))
                ctx.fill(p, with: color)
                x += 12
            }
        }
        .frame(width: width, height: 6)
        .allowsHitTesting(false)
    }
}

/// HUD 切角按钮：夜之城顶栏用语。激活＝黄底黑字。
public struct HudButton: View {
    let title: String
    var count: Int? = nil
    var active: Bool = false
    let action: () -> Void
    @State private var hovering = false

    public init(_ title: String, count: Int? = nil, active: Bool = false, action: @escaping () -> Void) {
        self.title = title
        self.count = count
        self.active = active
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: 7) {
                Text(title)
                    .font(Theme.sans(11.5, active ? .semibold : .regular))
                    .tracking(1.5)
                if let count {
                    Text("\(count)")
                        .font(Theme.mono(10, .bold))
                        .foregroundStyle(active ? Theme.fillInk : Theme.accent)
                }
            }
            .foregroundStyle(active ? Theme.fillInk : (hovering ? Theme.ink : Theme.ink2))
            .padding(.horizontal, 13)
            .frame(height: 27)
            .background(active ? Theme.accent : Theme.cardBackground)
            .clipShape(CutCornerShape(radius: 6))
            .overlay(
                CutCornerShape(radius: 6)
                    .stroke(hovering || active ? Theme.accent.opacity(0.8) : Theme.cardBorder, lineWidth: 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }
}

/// 线框植物（夜之城左栏装饰）：双线茎、交替叶、放射花瓣、故障色块。
/// 全部细描边、低透明度，只是终端背景里的一个电子标本，不参与交互。
public struct WireframeFlora: View {
    var size: CGSize

    public init(size: CGSize = CGSize(width: 196, height: 218)) {
        self.size = size
    }

    /// 二次贝塞尔取点。
    private func quad(_ p0: CGPoint, _ c: CGPoint, _ p1: CGPoint, _ t: CGFloat) -> CGPoint {
        let u = 1 - t
        return CGPoint(
            x: u * u * p0.x + 2 * u * t * c.x + t * t * p1.x,
            y: u * u * p0.y + 2 * u * t * c.y + t * t * p1.y
        )
    }

    public var body: some View {
        Canvas { ctx, canvas in
            let w = canvas.width, h = canvas.height
            let base = CGPoint(x: w * 0.60, y: h)
            let ctrl = CGPoint(x: w * 0.52, y: h * 0.58)
            let top = CGPoint(x: w * 0.46, y: h * 0.30)

            // 茎：双线（黄为主，青为衬）
            var stem = Path()
            stem.move(to: base)
            stem.addQuadCurve(to: top, control: ctrl)
            ctx.stroke(stem, with: .color(Theme.accent.opacity(0.5)), lineWidth: 2)
            var stem2 = Path()
            stem2.move(to: CGPoint(x: base.x + 3.5, y: base.y))
            stem2.addQuadCurve(to: CGPoint(x: top.x + 3.5, y: top.y), control: CGPoint(x: ctrl.x + 3.5, y: ctrl.y))
            ctx.stroke(stem2, with: .color(Theme.signal.opacity(0.28)), lineWidth: 0.8)

            // 叶：沿茎交替，椭圆描边 + 中脉
            let leafTs: [CGFloat] = [0.20, 0.38, 0.56, 0.74]
            for (i, t) in leafTs.enumerated() {
                let p = quad(base, ctrl, top, t)
                let side: CGFloat = i % 2 == 0 ? -1 : 1
                let len: CGFloat = 56 - CGFloat(i) * 7
                let angle = side * (0.42 + CGFloat(i % 2) * 0.1)
                let leafRect = CGRect(x: side < 0 ? -len : 0, y: -4.5, width: len, height: 9)
                var leaf = Path()
                leaf.addEllipse(in: leafRect)
                var tf = CGAffineTransform(translationX: p.x, y: p.y).rotated(by: angle)
                leaf = leaf.applying(tf)
                ctx.stroke(leaf, with: .color(Theme.ink2.opacity(0.55)), lineWidth: 1)
                var rib = Path()
                rib.move(to: p)
                rib.addLine(to: CGPoint(x: p.x + cos(angle) * len * side, y: p.y + sin(angle) * len * side))
                ctx.stroke(rib, with: .color(Theme.ink3.opacity(0.35)), lineWidth: 0.7)
            }

            // 花头：放射细长花瓣 + 中心圆簇
            let petalCount = 12
            for i in 0..<petalCount {
                let a = CGFloat(i) / CGFloat(petalCount) * 2 * .pi
                let len: CGFloat = i % 3 == 0 ? 40 : (i % 3 == 1 ? 32 : 36)
                var petal = Path()
                petal.addEllipse(in: CGRect(x: 0, y: -3.2, width: len, height: 6.4))
                let tf = CGAffineTransform(translationX: top.x, y: top.y).rotated(by: a)
                ctx.stroke(petal.applying(tf), with: .color(i % 4 == 2 ? Theme.signal.opacity(0.30) : Theme.ink2.opacity(0.5)), lineWidth: 0.9)
            }
            for offset in [CGPoint(x: -3, y: -2), CGPoint(x: 3, y: -1), CGPoint(x: 0, y: 3), CGPoint(x: 1, y: -4)] {
                let r: CGFloat = 4.5
                let c = CGPoint(x: top.x + offset.x, y: top.y + offset.y)
                ctx.stroke(Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2)), with: .color(Theme.ink3.opacity(0.5)), lineWidth: 0.8)
            }

            // 故障色块：茎上的两条灰条
            for (barIndex, barT) in [CGFloat(0.30), CGFloat(0.68)].enumerated() {
                let p = quad(base, ctrl, top, barT)
                let bw: CGFloat = barIndex == 0 ? 26 : 15
                ctx.fill(Path(CGRect(x: p.x + 4, y: p.y - 3.5, width: bw, height: 7)), with: .color(Theme.ink2.opacity(0.28)))
            }
        }
        .frame(width: size.width, height: size.height)
        .rotationEffect(.degrees(-2))
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
