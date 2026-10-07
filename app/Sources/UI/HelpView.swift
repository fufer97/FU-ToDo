import SwiftUI
import Core

/// 使用说明：独立窗口，从顶栏打开。主界面不重复这些说明。
public struct HelpView: View {
    @EnvironmentObject var store: TaskStore

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Rectangle().fill(Theme.hairline).frame(height: 1)
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    group("写下与修改", [
                        "点击一行的**任意位置**就能改文字；开始拖动时，正在编辑的内容会先自动保存",
                        "写或改的时候：**回车**＝继续下一条，**Tab**＝改成下级，点任意空白＝结束，**Esc**＝放弃",
                        "一级任务（主线 / 支线）只有「＋下级」；再添一条支线，用「今日支线」下面的空白卡片",
                        "主线与支线是**同一种任务**，「主线」只是当天那个位置的标记，可以随时换"
                    ])
                    group("拖动", [
                        "按住一行拖动：左侧高亮＝与它**同级**（上半排在它前面，下半排在它后面）",
                        "右侧高亮＝**接在它下面**，成为它的子步骤；拖动时两区会画出来",
                        "拖到**一级卡片**上：所有卡片会先收起成只剩标题，方便整张卡片换位，松手后自动展开",
                        "拖到**日历**上的某一天：整棵子树搬到那天"
                    ])
                    group("换主线", [
                        "把别的**一级任务**拖到「今日主线」：换成今天的主线",
                        "把当前**主线**拖到「今日支线」：降为支线（一天可以没有主线）",
                        "其它情况栏标题不亮、也不受理"
                    ])
                    group("完成与恢复", [
                        "点圆环完成，**连带整棵子步骤**；再点一次圆环就是恢复",
                        "恢复只恢复这一条与它上面的任务链；在已完成的行上**右键**可以选「恢复这条及其子步骤」"
                    ])
                    group("未完成项目清单", [
                        "只列**一级任务**、只收今天以前的；未来的事在自己的日历格子里",
                        "范围按系统当天往回数：本周 7 天 / 本月 30 天 / 所有不限，默认「所有」",
                        "「跳转」＝跳到它所在的那一天；「结束」＝这件事不做了，仍可在已结束清单里找回",
                        "「重新执行」＝整棵树搬到今天，已经完成的步骤保持完成"
                    ])
                    group("每一天", [
                        "跨天**自动**完成：打开应用、每分钟、以及窗口重新激活时都会检查",
                        "旧任务不会自动结转，会进入未完成项目清单"
                    ])
                }
                .padding(.horizontal, 22)
                .padding(.top, 20)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            Rectangle().fill(Theme.hairline).frame(height: 1)
            author
        }
        .frame(width: 470, height: 640)
        .background(Theme.paper)
        .themeSynced()
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("使用说明")
                .font(Theme.serif(19, .semibold))
                .foregroundStyle(Theme.ink)
            Text("主界面不写这些提示，需要时来这里查")
                .font(Theme.sans(11.5))
                .foregroundStyle(Theme.ink3)
        }
        .padding(.horizontal, 22)
        .padding(.top, 20)
        .padding(.bottom, 14)
    }

    /// 作者署名：头像 + 名称。
    private var author: some View {
        HStack(spacing: 10) {
            Group {
                if let image = Avatar.image {
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    Circle().fill(Theme.surfaceAlt)
                }
            }
            .frame(width: 36, height: 36)
            .clipShape(Circle())
            .overlay(Circle().strokeBorder(Theme.hairline, lineWidth: 1))

            VStack(alignment: .leading, spacing: 1) {
                Text("FUFU（不想上班版）")
                    .font(Theme.sans(12, .medium))
                    .foregroundStyle(Theme.ink)
                Text("FU ToDo \(AppVersion.current) · PolyForm Noncommercial 1.0.0")
                    .font(Theme.sans(10.5))
                    .foregroundStyle(Theme.ink3)
            }
            Spacer()
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 14)
    }

    /// 用 `LocalizedStringKey` 渲染，这样 `**加粗**` 会真的变成粗体
    /// （`Text(字符串变量)` 不会解析 Markdown，会原样显示星号）。
    private func bodyText(_ line: String) -> Text {
        Text(LocalizedStringKey(line))
    }

    private func group(_ title: String, _ lines: [String]) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title)
                .font(Theme.sans(11.5, .semibold))
                .foregroundStyle(Theme.ink3)
                .tracking(1.2)
            VStack(alignment: .leading, spacing: 5) {
                ForEach(lines, id: \.self) { line in
                    HStack(alignment: .top, spacing: 7) {
                        Circle()
                            .fill(Theme.faint)
                            .frame(width: 3, height: 3)
                            .padding(.top, 6)
                        bodyText(line)
                            .font(Theme.sans(12))
                            .foregroundStyle(Theme.ink2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }
}
