import SwiftUI
import Core

/// 配色切换的**通知源**。
///
/// 之前的问题：`ThemeSync` 在 `onChange` 里调用 `Theme.apply`，而 `onChange` 是在
/// 渲染**之后**才跑的；`Theme.current` 又是普通静态值，改了不会触发重渲染
/// —— 于是换了配色，界面一直画的是旧色，只有重启才生效。
///
/// 现在改成：**先着色，再通知**。观察 `revision` 的视图会在通知后重渲染，
/// 那时 `Theme` 已经是新配色了。
@MainActor
public final class ThemeSource: ObservableObject {
    public static let shared = ThemeSource()

    /// 每次配色/字体/字号变化 +1；根视图用它做 `.id`，强制整棵子树重建。
    @Published public private(set) var revision: Int = 0
    /// 已生效的设置，用来跳过重复同步。
    public private(set) var applied: AppSettings?

    public init() {}

    public func sync(_ settings: AppSettings) {
        guard settings != applied else { return }
        Theme.apply(settings)      // 先着色
        applied = settings
        revision &+= 1             // 再通知
    }
}
