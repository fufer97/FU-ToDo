import SwiftUI
import Core

/// 使用说明：独立窗口，从顶栏打开。主界面不重复这些说明。
///
/// 版式是一本薄手册：顶部等宽标签栏 + 版本号，大字号标题，
/// 下面按 01–06 分节，节与节之间只用 0.8pt 细线分隔。
public struct HelpView: View {
    @EnvironmentObject var store: TaskStore

    public init() {}

    private let sections: [(title: String, lines: [String])] = [
        ("写下与修改", [
            "点击一行的**任意位置**就能改文字；开始拖动时，正在编辑的内容会先自动保存",
            "写或改的时候：**回车**＝继续下一条，**Tab**＝改成下级，点任意空白＝结束，**Esc**＝放弃",
            "一级任务（主线 / 支线）只有「＋下级」；再添一条支线，用「今日支线」下面的空白卡片",
            "主线与支线是**同一种任务**，「主线」只是当天那个位置的标记，可以随时换"
        ]),
        ("拖动", [
            "按住一行拖动：左侧高亮＝与它**同级**（上半排在它前面，下半排在它后面）",
            "右侧高亮＝**接在它下面**，成为它的子步骤；拖动时两区会画出来",
            "拖到**一级卡片**上：所有卡片会先收起成只剩标题，方便整张卡片换位，松手后自动展开",
            "拖到**日历**上的某一天：整棵子树搬到那天"
        ]),
        ("换主线", [
            "把别的**一级任务**拖到「今日主线」：换成今天的主线",
            "把当前**主线**拖到「今日支线」：降为支线（一天可以没有主线）",
            "其它情况栏标题不亮、也不受理"
        ]),
        ("完成与恢复", [
            "点圆环完成，**连带整棵子步骤**；再点一次圆环就是恢复",
            "完成时会盖一枚当前主题的章（工单 / 标本 / 贴纸 / 图纸），只是一次性反馈",
            "恢复只恢复这一条与它上面的任务链；在已完成的行上**右键**可以选「恢复这条及其子步骤」"
        ]),
        ("专注模式", [
            "按 **⌘⇧F**，或点顶栏「专注」：整窗只留今天的主线",
            "在专注模式里点右侧大圆环即可完成；按 **Esc** 或右下角按钮退出",
            "切换日期时右页会横向翻入翻出，不想看动效可在系统里开启「减少动态效果」"
        ]),
        ("视图与命令", [
            "按 **⌘Y** 打开年视图：12 个小月历，点任意一天跳过去",
            "按 **⌘K** 打开命令面板：专注、年视图、导出海报、切换主题都可以搜到",
            "设置 → 数据 →「导出本月海报…」会把当前月存成一张 1200×1600 的 PNG"
        ]),
        ("未完成项目清单", [
            "只列**一级任务**、只收今天以前的；未来的事在自己的日历格子里",
            "范围按系统当天往回数：本周 7 天 / 本月 30 天 / 所有不限，默认「所有」",
            "「跳转」＝跳到它所在的那一天；「结束」＝这件事不做了，仍可在已结束清单里找回",
            "「重新执行」＝整棵树搬到今天，已经完成的步骤保持完成"
        ]),
        ("每一天", [
            "跨天**自动**完成：打开应用、每分钟、以及窗口重新激活时都会检查",
            "旧任务不会自动结转，会进入未完成项目清单"
        ])
    ]

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            WindowTagBar("FU TODO / HELP", trailing: "v\(AppVersion.current)")
            Hairline()

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    titleBlock
                    ForEach(Array(sections.enumerated()), id: \.offset) { index, section in
                        if index > 0 {
                            Hairline().padding(.top, 18)
                        }
                        group(index + 1, section.title, section.lines)
                            .padding(.top, index == 0 ? 0 : 14)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 20)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            Hairline()
            author
        }
        .frame(width: 470, height: 640)
        .background(Theme.canvas)
        .themeSynced()
    }

    // MARK: 页眉

    private var titleBlock: some View {
        HStack(alignment: .bottom, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text("使用说明")
                    .font(Theme.display(34))
                    .tracking(Theme.displayTracking(34))
                    .foregroundStyle(Theme.ink)
                Text("MANUAL · 主界面不写这些提示，需要时来这里查")
                    .font(Theme.mono(9))
                    .tracking(1.4)
                    .foregroundStyle(Theme.ink3)
            }
            Spacer(minLength: 12)
            SheetStamp(text: "MANUAL")
                .padding(.bottom, 5)
        }
        .padding(.top, 20)
        .padding(.bottom, 20)
    }

    // MARK: 分节

    /// 用 `LocalizedStringKey` 渲染，这样 `**加粗**` 会真的变成粗体
    /// （`Text(字符串变量)` 不会解析 Markdown，会原样显示星号）。
    private func bodyText(_ line: String) -> Text {
        Text(LocalizedStringKey(line))
    }

    private func group(_ index: Int, _ title: String, _ lines: [String]) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(alignment: .center, spacing: 8) {
                Text(String(format: "%02d", index))
                    .font(Theme.mono(8.5, .semibold))
                    .tracking(1.2)
                    .foregroundStyle(Theme.accentInk)
                Text(title)
                    .font(Theme.sans(12.5, .semibold))
                    .tracking(0.6)
                    .foregroundStyle(Theme.ink)
                Rectangle()
                    .fill(Theme.rule)
                    .frame(height: 0.8)
            }
            VStack(alignment: .leading, spacing: 6) {
                ForEach(lines, id: \.self) { line in
                    HStack(alignment: .top, spacing: 8) {
                        Rectangle()
                            .fill(Theme.ink3.opacity(0.5))
                            .frame(width: 7, height: 0.8)
                            .padding(.top, 7)
                        bodyText(line)
                            .font(Theme.sans(11.8))
                            .foregroundStyle(Theme.ink2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }

    // MARK: 版权脚注

    /// 作者署名：证件照 + 名称 + 版本与许可，排成一条页脚。
    private var author: some View {
        HStack(spacing: 10) {
            Group {
                if let image = Avatar.image {
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    Rectangle().fill(Theme.surfaceAlt)
                }
            }
            .frame(width: 32, height: 32)
            .clipShape(Circle())
            .overlay(Circle().strokeBorder(Theme.rule, lineWidth: 0.8))

            VStack(alignment: .leading, spacing: 2) {
                Text("FUFU（不想上班版）")
                    .font(Theme.sans(11.5, .medium))
                    .foregroundStyle(Theme.ink)
                Text("FU TODO \(AppVersion.current)  /  POLYFORM NONCOMMERCIAL 1.0.0")
                    .font(Theme.mono(7.5))
                    .tracking(0.8)
                    .foregroundStyle(Theme.ink3)
            }
            Spacer(minLength: 12)
            Text("COLOPHON")
                .font(Theme.mono(7.5))
                .tracking(1.4)
                .foregroundStyle(Theme.ink3)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
    }
}
