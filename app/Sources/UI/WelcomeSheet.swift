import SwiftUI
import Core

/// 首次打开的一次性引导：**只讲四件事**，看完不再打扰。
/// 详细操作在「使用说明」窗口里，这里不重复。
///
/// 版式：顶部等宽标签栏（右侧版本号）+ 大字号欢迎语 + 01–04 编号条目 + 页脚按钮。
public struct WelcomeSheet: View {
    @EnvironmentObject var store: TaskStore
    public let onOpenHelp: () -> Void
    public let onClose: () -> Void

    public init(onOpenHelp: @escaping () -> Void, onClose: @escaping () -> Void) {
        self.onOpenHelp = onOpenHelp
        self.onClose = onClose
    }

    private let points: [(title: String, detail: String)] = [
        ("一天一件", "每天只写一件最重要的事（主线），其余都是支线。主线只是个标记，随时能换。"),
        ("点一下就改", "点一行的任意位置改文字；改的时候回车继续写、Tab 加下级。"),
        ("拖动整理", "拖到一行的左半边＝与它同级，右半边＝接在它下面。"),
        ("不会堆积", "跨天自动开新的一天，没做完的进「未完成项目清单」，随时搬回今天。")
    ]

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            WindowTagBar("FU TODO / WELCOME", trailing: "v\(AppVersion.current)")
            Hairline()

            header
            pointList

            Spacer(minLength: 0)
            footer
        }
        .frame(width: 420)
        .background(Theme.canvas)
        .themeSynced()
    }

    // MARK: 页眉

    private var header: some View {
        HStack(alignment: .bottom, spacing: 12) {
            if let image = Avatar.image {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 32, height: 32)
                    .clipShape(Circle())
                    .overlay(Circle().strokeBorder(Theme.rule, lineWidth: 0.8))
            }
            VStack(alignment: .leading, spacing: 3) {
                Text("欢迎用 FU ToDo")
                    .font(Theme.display(26))
                    .tracking(Theme.displayTracking(26))
                    .foregroundStyle(Theme.ink)
                Text("WELCOME · 今天写一件最重要的事")
                    .font(Theme.mono(8.5))
                    .tracking(1.2)
                    .foregroundStyle(Theme.ink3)
            }
            Spacer(minLength: 12)
            SheetStamp(text: "START")
                .padding(.bottom, 2)
        }
        .padding(.horizontal, 24)
        .padding(.top, 14)
        .padding(.bottom, 10)
    }

    // MARK: 四条要点

    private var pointList: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(points.enumerated()), id: \.offset) { index, item in
                if index > 0 {
                    Hairline()
                }
                pointRow(index + 1, item.title, item.detail)
            }
        }
        .padding(.horizontal, 24)
    }

    private func pointRow(_ index: Int, _ title: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(String(format: "%02d", index))
                .font(Theme.mono(8, .semibold))
                .tracking(1)
                .foregroundStyle(Theme.accentInk)
                .frame(width: 18, alignment: .leading)
                .padding(.top, 2)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(Theme.sans(12.5, .semibold))
                    .tracking(0.5)
                    .foregroundStyle(Theme.ink)
                Text(detail)
                    .font(Theme.sans(11.5))
                    .lineSpacing(1)
                    .foregroundStyle(Theme.ink2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, 7)
    }

    // MARK: 页脚

    private var footer: some View {
        VStack(spacing: 0) {
            Hairline()
            HStack(spacing: 10) {
                SheetButton(title: "看完整说明", primary: false) {
                    onOpenHelp()
                    onClose()
                }
                Spacer(minLength: 12)
                SheetButton(title: "开始写今天", primary: true) { onClose() }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 10)
        }
        .padding(.top, 6)
    }
}

/// 页脚按钮：方角、极轻；主要动作用墨色实底、纸色文字。
private struct SheetButton: View {
    let title: String
    let primary: Bool
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(Theme.sans(primary ? 12 : 11.5, primary ? .semibold : .medium))
                .tracking(0.3)
                .foregroundStyle(primary ? Theme.canvas : (hovering ? Theme.ink : Theme.ink2))
                .padding(.horizontal, primary ? 14 : 10)
                .padding(.vertical, primary ? 7 : 6)
                .background(
                    primary
                        ? (hovering ? Theme.ink.opacity(0.86) : Theme.ink)
                        : (hovering ? Theme.ink.opacity(0.05) : Color.clear)
                )
                .overlay(
                    Rectangle()
                        .strokeBorder(primary ? Color.clear : Theme.rule, lineWidth: 0.8)
                )
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }
}
