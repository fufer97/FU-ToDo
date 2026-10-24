import SwiftUI
import Core

/// 卡片外壳（4.0）：日课没有卡片——任务块直接排在纸上，靠字号与留白分层；
/// 夜之城是切角面板（对角切 14pt，来自 2077 的组件语法）。
/// 只负责「外壳」；里面的行仍是 TaskRowView（onCard: true）。
public struct TaskCardChrome<Content: View>: View {
    public let task: Task
    public let style: CardStyle
    public let completed: Bool
    private let content: Content

    public init(task: Task, style: CardStyle, completed: Bool = false, @ViewBuilder content: () -> Content) {
        self.task = task
        self.style = style
        self.completed = completed
        self.content = content()
    }

    public var body: some View {
        if Theme.panelEnabled {
            content
                .padding(.horizontal, 22)
                .padding(.vertical, task.isMain ? 22 : 14)
                .background(Theme.cardBackground)
                .clipShape(CutCornerShape(radius: Theme.cutCorner))
                .overlay(
                    CutCornerShape(radius: Theme.cutCorner)
                        .stroke(Theme.cardBorder, lineWidth: 1)
                )
        } else {
            content
        }
    }
}

/// 对角切角：左上与右下各切一刀。
public struct CutCornerShape: Shape {
    let radius: CGFloat

    public init(radius: CGFloat) {
        self.radius = radius
    }

    public func path(in rect: CGRect) -> Path {
        guard radius > 0, rect.width > radius * 2, rect.height > radius * 2 else {
            return Path(rect)
        }
        var p = Path()
        p.move(to: CGPoint(x: rect.minX + radius, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - radius))
        p.addLine(to: CGPoint(x: rect.maxX - radius, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.minY + radius))
        p.closeSubpath()
        return p
    }
}

/// 夜之城的面板：切角容器（主线 22pt / 子面板 14pt），内容自带留白。
public struct NightPanel<Content: View>: View {
    var corner: CGFloat
    /// true = 纵向撑满所给空间（支线/已完成）；false = 包住内容（主线）
    var fillHeight: Bool
    private let content: Content

    public init(corner: CGFloat, fillHeight: Bool = false, @ViewBuilder content: () -> Content) {
        self.corner = corner
        self.fillHeight = fillHeight
        self.content = content()
    }

    public var body: some View {
        content
            .padding(.horizontal, 26)
            .padding(.vertical, 20)
            .frame(maxWidth: .infinity, maxHeight: fillHeight ? .infinity : nil, alignment: .topLeading)
            .background(Theme.cardBackground)
            .clipShape(CutCornerShape(radius: corner))
            .overlay(
                CutCornerShape(radius: corner)
                    .stroke(Theme.cardBorder, lineWidth: 1)
            )
    }
}
