import SwiftUI
import Core

/// 主题卡片外壳：同一个任务，在四个主题里分别是工单、标本标签、贴纸、图纸。
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
        switch style {
        case .atelier:
            AtelierChrome(task: task, completed: completed) { content }
        case .herbarium:
            HerbariumChrome(task: task, completed: completed) { content }
        case .acid:
            AcidChrome(task: task, completed: completed) { content }
        case .blueprint:
            BlueprintChrome(task: task, completed: completed) { content }
        }
    }
}

private func cardDate(_ day: String) -> String {
    day.replacingOccurrences(of: "-", with: ".")
}

private struct PunchHole: View {
    var body: some View {
        Circle()
            .strokeBorder(Theme.cardInk.opacity(0.28), lineWidth: 0.8)
            .frame(width: 9, height: 9)
            .padding(.leading, 9)
            .padding(.top, 9)
    }
}

private struct BarcodeStrips: View {
    let seed: String
    var body: some View {
        HStack(spacing: 1.2) {
            ForEach(Array(seed.unicodeScalars.prefix(22).enumerated()), id: \.offset) { index, scalar in
                let w = CGFloat((Int(scalar.value) + index * 3) % 3 + 1) * 0.9
                Rectangle().fill(Theme.cardInk.opacity(0.75)).frame(width: w, height: 18)
            }
        }
    }
}

// MARK: 器物：工单 / 吊牌

private struct AtelierChrome<Content: View>: View {
    let task: Task
    let completed: Bool
    let content: Content

    init(task: Task, completed: Bool, @ViewBuilder content: () -> Content) {
        self.task = task
        self.completed = completed
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text("ATELIER  /  器物").font(Theme.mono(7.5)).tracking(1.6).foregroundStyle(Theme.cardInk.opacity(0.6))
                Spacer()
                Text("No. \(task.id.uuidString.prefix(2))")
                    .font(Theme.serifPreview(11))
                    .italic()
                    .foregroundStyle(Theme.cardInk.opacity(0.7))
            }
            .padding(.horizontal, 14)
            .padding(.top, 10)

            Rectangle().fill(Theme.cardInk.opacity(0.55)).frame(height: 0.9)
                .padding(.horizontal, 14).padding(.top, 6)
            Rectangle().fill(Theme.cardInk.opacity(0.22)).frame(height: 0.5)
                .padding(.horizontal, 14).padding(.top, 2)

            content.padding(.horizontal, 14).padding(.vertical, 4)

            Rectangle().fill(Theme.stamp.opacity(0.8)).frame(height: 0.8)
                .padding(.horizontal, 14).padding(.top, 2)
            HStack {
                Text(cardDate(task.day)).font(Theme.mono(8)).tracking(1).foregroundStyle(Theme.cardInk.opacity(0.55))
                Spacer()
                Text(completed ? "已交付" : "待装订")
                    .font(Theme.mono(8))
                    .tracking(1.2)
                    .foregroundStyle(completed ? Theme.cardInk : Theme.stamp)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
        }
        .background(Theme.cardBackground)
        .overlay(Rectangle().strokeBorder(Theme.cardBorder, lineWidth: 0.9))
        .overlay(alignment: .topTrailing) {
            if completed {
                Text("已交付")
                    .font(Theme.display(13))
                    .foregroundStyle(Theme.cardBackground)
                    .padding(7)
                    .background(Circle().fill(Theme.stamp))
                    .rotationEffect(.degrees(-9))
                    .padding(.top, 14).padding(.trailing, 14)
            }
        }
    }
}

// MARK: 标本室：标本标签

private struct HerbariumChrome<Content: View>: View {
    let task: Task
    let completed: Bool
    let content: Content

    init(task: Task, completed: Bool, @ViewBuilder content: () -> Content) {
        self.task = task
        self.completed = completed
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text("FU TODO  /  SPECIMEN").font(Theme.mono(7.5)).tracking(1.6).foregroundStyle(Theme.cardInk.opacity(0.75))
                Spacer()
                Text("CH-\(task.id.uuidString.prefix(2))").font(Theme.mono(7.5)).tracking(1.2).foregroundStyle(Theme.cardInk.opacity(0.45))
            }
            .padding(.horizontal, 14).padding(.top, 10)
            Rectangle().fill(Theme.cardInk.opacity(0.5)).frame(height: 0.8)
                .padding(.horizontal, 14).padding(.top, 7)

            content.padding(.horizontal, 14).padding(.vertical, 4)

            Rectangle().fill(Theme.cardInk.opacity(0.22)).frame(height: 0.7)
                .padding(.horizontal, 14)
            HStack(alignment: .center) {
                Text(completed ? "DRIED & MOUNTED" : "MOISTURE / LOW / MORNING")
                    .font(Theme.mono(7)).tracking(0.8)
                    .foregroundStyle(Theme.cardInk.opacity(0.65))
                Spacer()
                BarcodeStrips(seed: task.id.uuidString)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
        }
        .background(Theme.cardBackground)
        .overlay(Rectangle().strokeBorder(Theme.cardBorder, lineWidth: 0.9))
        .overlay(alignment: .topTrailing) {
            if completed {
                Text("DRIED & MOUNTED · \(cardDate(task.day))")
                    .font(Theme.mono(6.5)).tracking(0.4)
                    .foregroundStyle(Theme.stamp)
                    .padding(.horizontal, 7).padding(.vertical, 4)
                    .overlay(Rectangle().strokeBorder(Theme.stamp, lineWidth: 1))
                    .rotationEffect(.degrees(-7))
                    .padding(.top, 44).padding(.trailing, 14)
            }
        }
    }
}

// MARK: 酸纸：贴纸 / 告示

private struct AcidChrome<Content: View>: View {
    let task: Task
    let completed: Bool
    let content: Content

    init(task: Task, completed: Bool, @ViewBuilder content: () -> Content) {
        self.task = task
        self.completed = completed
        self.content = content()
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            Rectangle().fill(Theme.cardBackground).offset(x: 5, y: 5)
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text("ACID  /  STICKER \(task.id.uuidString.prefix(2))")
                        .font(Theme.mono(7.5)).tracking(1.4)
                        .foregroundStyle(Theme.cardInk.opacity(0.65))
                    Spacer()
                    Text("★").font(.system(size: 10)).foregroundStyle(Theme.cardInk)
                }
                .padding(.horizontal, 14).padding(.top, 10)

                content.padding(.horizontal, 14).padding(.vertical, 4)

                HStack(spacing: 3) {
                    ForEach(0..<18, id: \.self) { i in
                        Circle().fill(Theme.cardInk.opacity(0.3 + Double(i % 3) * 0.2)).frame(width: 3, height: 3)
                    }
                }
                .padding(.horizontal, 14)

                Rectangle().fill(Theme.cardInk.opacity(0.45)).frame(height: 0.8)
                    .padding(.horizontal, 14).padding(.top, 7)
                HStack {
                    Text(cardDate(task.day)).font(Theme.mono(8)).tracking(1)
                        .foregroundStyle(Theme.cardInk.opacity(0.7))
                    Spacer()
                    Text("PEEL HERE →").font(Theme.mono(8)).tracking(1)
                        .foregroundStyle(Theme.cardInk)
                }
                .padding(.horizontal, 14).padding(.vertical, 7)
            }
            .background(Theme.cardBackground)
        }
        .rotationEffect(.degrees(0.8))
        .overlay(alignment: .topTrailing) {
            if completed {
                Text("DONE")
                    .font(.system(size: 15, weight: .black))
                    .foregroundStyle(Theme.cardBackground)
                    .padding(.horizontal, 8).padding(.vertical, 2)
                    .background(Rectangle().fill(Theme.stamp))
                    .rotationEffect(.degrees(-9))
                    .padding(.top, 24).padding(.trailing, 16)
            }
        }
    }
}

// MARK: 蓝图：图纸标题栏

private struct BlueprintChrome<Content: View>: View {
    let task: Task
    let completed: Bool
    let content: Content

    init(task: Task, completed: Bool, @ViewBuilder content: () -> Content) {
        self.task = task
        self.completed = completed
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("DWG  /  FU-\(task.id.uuidString.prefix(4))")
                    .font(Theme.mono(7.5)).tracking(1.2)
                    .foregroundStyle(Theme.cardInk.opacity(0.7))
                Spacer()
                Text(completed ? "REV. A / DONE" : "REV. A")
                    .font(Theme.mono(7)).tracking(0.8)
                    .foregroundStyle(Theme.stamp)
            }
            .padding(.horizontal, 14).padding(.top, 9)

            content.padding(.horizontal, 14).padding(.vertical, 4)

            HStack(spacing: 0) {
                block("DWG NO", "FU-\(task.id.uuidString.prefix(4))")
                block("DATE", cardDate(task.day))
                block("REV", completed ? "A / DONE" : "A")
            }
            .overlay(alignment: .top) { Rectangle().fill(Theme.cardBorder).frame(height: 0.7) }
        }
        .background(
            ZStack {
                Theme.cardBackground
                BlueprintGrid()
            }
        )
        .overlay(Rectangle().strokeBorder(Theme.cardBorder, lineWidth: 0.9))
        .overlay(alignment: .topTrailing) {
            if completed {
                Text("REV. A")
                    .font(.system(size: 14, weight: .black))
                    .foregroundStyle(Theme.stamp)
                    .padding(.horizontal, 7).padding(.vertical, 2)
                    .overlay(Rectangle().strokeBorder(Theme.stamp, lineWidth: 1.1))
                    .rotationEffect(.degrees(-7))
                    .padding(.top, 34).padding(.trailing, 18)
            }
        }
    }

    private func block(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label).font(Theme.mono(6)).tracking(0.6).foregroundStyle(Theme.cardInk.opacity(0.45))
            Text(value).font(Theme.mono(7.5)).foregroundStyle(Theme.cardInk)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 8).padding(.vertical, 4)
        .overlay(alignment: .leading) { Rectangle().fill(Theme.cardBorder).frame(width: 0.7) }
    }
}

private struct BlueprintGrid: View {
    var body: some View {
        Canvas { ctx, size in
            let color = GraphicsContext.Shading.color(Theme.gridLine)
            var x: CGFloat = 0
            while x < size.width {
                ctx.fill(Path(CGRect(x: x, y: 0, width: 0.6, height: size.height)), with: color)
                x += 18
            }
            var y: CGFloat = 0
            while y < size.height {
                ctx.fill(Path(CGRect(x: 0, y: y, width: size.width, height: 0.6)), with: color)
                y += 18
            }
        }
        .allowsHitTesting(false)
    }
}
