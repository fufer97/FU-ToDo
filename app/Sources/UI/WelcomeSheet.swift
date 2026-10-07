import SwiftUI
import Core

/// 首次打开的一次性引导：**只讲四件事**，看完不再打扰。
/// 详细操作在「使用说明」窗口里，这里不重复。
public struct WelcomeSheet: View {
    @EnvironmentObject var store: TaskStore
    public let onOpenHelp: () -> Void
    public let onClose: () -> Void

    public init(onOpenHelp: @escaping () -> Void, onClose: @escaping () -> Void) {
        self.onOpenHelp = onOpenHelp
        self.onClose = onClose
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            VStack(alignment: .leading, spacing: 14) {
                point("一天一件", "每天只写一件最重要的事（主线），其余都是支线。主线只是个标记，随时能换。")
                point("点一下就改", "点一行的任意位置改文字；改的时候回车继续写、Tab 加下级。")
                point("拖动整理", "拖到一行的左半边＝与它同级，右半边＝接在它下面。")
                point("不会堆积", "跨天自动开新的一天，没做完的进「未完成项目清单」，随时搬回今天。")
            }
            .padding(.horizontal, 24)
            .padding(.top, 18)
            footer
        }
        .frame(width: 420)
        .background(Theme.paper)
        .themeSynced()
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            if let image = Avatar.image {
                Image(nsImage: image).resizable().scaledToFill()
                    .frame(width: 40, height: 40)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(Theme.hairline, lineWidth: 1)
                    )
            }
            VStack(alignment: .leading, spacing: 3) {
                Text("欢迎用 FU ToDo")
                    .font(Theme.serif(Theme.dateSize, .semibold))
                    .foregroundStyle(Theme.ink)
                Text("一句话：今天写一件最重要的事。")
                    .font(Theme.sans(Theme.metaSize))
                    .foregroundStyle(Theme.ink3)
            }
            Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.top, 22)
        .padding(.bottom, 16)
    }

    private var footer: some View {
        VStack(spacing: 0) {
            Rectangle().fill(Theme.hairline).frame(height: 1)
            HStack(spacing: 10) {
                TextButton("看完整说明") {
                    onOpenHelp()
                    onClose()
                }
                Spacer()
                TextButton("开始写今天", prominent: true) { onClose() }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 14)
        }
        .padding(.top, 20)
    }

    private func point(_ title: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Circle()
                .fill(Theme.accent)
                .frame(width: 6, height: 6)
                .padding(.top, 6)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(Theme.sans(Theme.controlSize, .semibold))
                    .foregroundStyle(Theme.ink)
                Text(detail)
                    .font(Theme.sans(12))
                    .foregroundStyle(Theme.ink2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
