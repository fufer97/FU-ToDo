import SwiftUI
import AppKit
import UniformTypeIdentifiers
import Core

/// 设置窗口：外观（深浅色 / 强调色 / 纸面色调 / 字号）与数据（备份、位置、清空）。
public struct SettingsView: View {
    @EnvironmentObject var store: TaskStore

    @EnvironmentObject var updater: Updater
    @State private var message: String?
    @State private var pendingImport: Data?
    @State private var showClearConfirm = false

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    appearanceSection
                    previewSection
                    dataSection
                }
                .padding(22)
            }
            if let message {
                Rectangle().fill(Theme.hairline).frame(height: 1)
                Text(message)
                    .font(Theme.sans(11.5))
                    .foregroundStyle(Theme.ink3)
                    .padding(.horizontal, 22)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(width: 470, height: 650)
        .background(Theme.paper)
        .themeSynced()
        .alert("导入备份", isPresented: Binding(
            get: { pendingImport != nil },
            set: { if !$0 { pendingImport = nil } }
        )) {
            Button("取消", role: .cancel) { pendingImport = nil }
            Button("替换现有数据", role: .destructive) {
                if let data = pendingImport {
                    do {
                        try store.importData(data)
                        message = "已导入备份：\(store.tasks.count) 条任务"
                    } catch {
                        message = "导入失败：\(error.localizedDescription)"
                    }
                }
                pendingImport = nil
            }
        } message: {
            Text("导入会替换当前所有任务与外观设置，且不可撤销。")
        }
        .alert("清空所有数据", isPresented: $showClearConfirm) {
            Button("取消", role: .cancel) {}
            Button("清空", role: .destructive) {
                store.clearAllTasks()
                message = "已清空所有任务（可以在窗口底部的提示条上撤销）"
            }
        } message: {
            Text("会删除全部任务与历史记录，无法找回。")
        }
    }

    // MARK: 外观

    private var appearanceSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionTitle("外观")

            row("深浅色") {
                Picker("", selection: binding(\.appearance)) {
                    ForEach(AppearanceMode.allCases, id: \.self) { mode in
                        Text(mode.label).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 240)
            }

            presetGrid

            row("更新") {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 10) {
                        Toggle("", isOn: binding(\.autoCheckUpdates))
                            .labelsHidden()
                            .toggleStyle(.switch)
                            .controlSize(.small)
                        Text("启动时自动检查")
                            .font(Theme.sans(12))
                            .foregroundStyle(Theme.ink2)
                        Spacer()
                        TextButton("检查更新") {
                            _Concurrency.Task { await updater.check() }
                        }
                    }
                    if !updater.status.text.isEmpty {
                        HStack(spacing: 8) {
                            Text(updater.status.text)
                                .font(Theme.sans(11))
                                .foregroundStyle(Theme.ink3)
                            if case .available(_, let url) = updater.status {
                                TextButton("打开下载页") { NSWorkspace.shared.open(url) }
                            }
                        }
                    } else {
                        Text("当前版本 \(AppVersion.current)")
                            .font(Theme.sans(11))
                            .foregroundStyle(Theme.ink3)
                    }
                }
            }
            row("引导") {
                TextButton("重新看一次首次引导", prominent: false) {
                    store.resetWelcome()
                    message = "关闭设置窗口后重新打开应用，就会再次看到引导。"
                }
            }
            row("字体") {
                Picker("", selection: binding(\.font)) {
                    ForEach(FontChoice.allCases, id: \.self) { choice in
                        Text(choice.label).tag(choice)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 190)
            }
            row("字号") {
                Picker("", selection: binding(\.fontScale)) {
                    ForEach(FontScale.allCases, id: \.self) { scale in
                        Text(scale.label).tag(scale)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 160)
            }
        }
    }

    /// 配色方案卡片：每张带小预览、说明，命中的那张标「当前」。
    private var presetGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
            ForEach(ThemePreset.all) { preset in
                presetCard(preset)
            }
        }
    }

    private func presetCard(_ preset: ThemePreset) -> some View {
        let isCurrent = preset.matches(store.settings)
        return Button {
            store.updateSettings {
                $0.paper = preset.paper
                $0.accent = preset.accent
            }
        } label: {
            HStack(alignment: .top, spacing: 12) {
                presetThumbnail(preset)
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(preset.name)
                            .font(Theme.sans(13, .semibold))
                            .foregroundStyle(Theme.ink)
                        if isCurrent {
                            Text("当前")
                                .font(Theme.sans(10, .semibold))
                                .foregroundStyle(Theme.accent)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1)
                                .background(Capsule().fill(Theme.accentSoft))
                        }
                    }
                    Text(preset.note)
                        .font(Theme.sans(11))
                        .foregroundStyle(Theme.ink3)
                        .fixedSize(horizontal: false, vertical: true)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 0)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isCurrent ? Theme.surfaceAlt : Theme.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(isCurrent ? Theme.accent.opacity(0.6) : Theme.hairline, lineWidth: isCurrent ? 1.4 : 1)
            )
        }
        .buttonStyle(.plain)
    }

    /// 小预览：纸底 + 一条标题线 + 一个强调色圆点 + 两条内容线。
    private func presetThumbnail(_ preset: ThemePreset) -> some View {
        let paperColor = paperSwatch(preset.paper)
        let accentColor = accentSwatch(preset.accent)
        return VStack(alignment: .leading, spacing: 4) {
            RoundedRectangle(cornerRadius: 1).fill(Theme.ink2.opacity(0.85)).frame(width: 26, height: 3)
            Spacer(minLength: 0)
            HStack(spacing: 4) {
                Circle().fill(accentColor).frame(width: 6, height: 6)
                RoundedRectangle(cornerRadius: 1).fill(Theme.ink2.opacity(0.5)).frame(width: 22, height: 2.5)
            }
            RoundedRectangle(cornerRadius: 1).fill(Theme.ink3.opacity(0.45)).frame(width: 32, height: 2.5)
        }
        .padding(7)
        .frame(width: 62, height: 52, alignment: .topLeading)
        .background(paperColor)
        .overlay(
            RoundedRectangle(cornerRadius: 6, style: .continuous).strokeBorder(Theme.hairline, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
    }

    private var previewSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionTitle("预览")
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 9) {
                    RingView(level: 1, done: false) {}
                    Text("写完产品原型说明")
                        .font(Theme.titleFont(1, isMain: true))
                        .foregroundStyle(Theme.ink)
                    Spacer()
                }
                .frame(height: Theme.rowHeight(1))

                HStack(spacing: 0) {
                    TreeRails(level: 2)
                    HStack(spacing: 9) {
                        RingView(level: 2, done: true) {}
                        Text("整理阶段 1 的规则条目")
                            .font(Theme.titleFont(2))
                            .foregroundStyle(Theme.doneInk)
                            .strikethrough(true, color: Theme.doneInk)
                    }
                }
                .frame(height: Theme.rowHeight(2))

                HStack(spacing: 0) {
                    TreeRails(level: 3)
                    HStack(spacing: 9) {
                        RingView(level: 3, done: false) {}
                        Text("第三级：细节")
                            .font(Theme.titleFont(3))
                            .foregroundStyle(Theme.titleColor(3))
                    }
                }
                .frame(height: Theme.rowHeight(3))
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Theme.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(Theme.hairline, lineWidth: 1)
            )
        }
    }

    // MARK: 数据

    private var dataSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("数据")
            HStack(spacing: 10) {
                plainButton("导出备份…") { exportBackup() }
                plainButton("从备份导入…") { importBackup() }
                plainButton("打开数据文件夹") { openDataFolder() }
            }
            HStack(spacing: 10) {
                plainButton("清空所有数据", danger: true) { showClearConfirm = true }
                Spacer()
            }
            Text("数据存在本地，不上传任何地方。备份是一个 JSON 文件，可以自己打开看。")
                .font(Theme.sans(11))
                .foregroundStyle(Theme.faint)
        }
    }

    // MARK: 组件

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(Theme.sans(11.5, .semibold))
            .foregroundStyle(Theme.ink3)
            .tracking(1.2)
    }

    private func row<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        HStack(alignment: .center, spacing: 14) {
            Text(label)
                .font(Theme.sans(12.5))
                .foregroundStyle(Theme.ink2)
                .frame(width: 66, alignment: .leading)
            content()
            Spacer()
        }
    }

    private func swatch(label: String, color: Color, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Circle()
                    .fill(color)
                    .frame(width: 14, height: 14)
                    .overlay(
                        Circle().strokeBorder(Theme.hairline, lineWidth: selected ? 0 : 1)
                    )
                Text(label)
                    .font(Theme.sans(12))
                    .foregroundStyle(selected ? Theme.ink : Theme.ink3)
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 7)
                    .fill(selected ? Theme.surfaceAlt : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 7)
                    .strokeBorder(selected ? Theme.accent.opacity(0.55) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func plainButton(_ title: String, danger: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(Theme.sans(12.5, .medium))
                .foregroundStyle(danger ? Theme.accent : Theme.ink2)
                .padding(.horizontal, 11)
                .padding(.vertical, 6)
                .background(RoundedRectangle(cornerRadius: 7).fill(Theme.surface))
                .overlay(
                    RoundedRectangle(cornerRadius: 7).strokeBorder(Theme.hairline, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }

    private func binding<T>(_ keyPath: WritableKeyPath<AppSettings, T>) -> Binding<T> {
        Binding(
            get: { store.settings[keyPath: keyPath] },
            set: { value in store.updateSettings { $0[keyPath: keyPath] = value } }
        )
    }

    private func accentSwatch(_ choice: AccentChoice) -> Color {
        switch choice {
        case .blue: return Color(light: 0x3370FF, dark: 0x4E83FD)
        case .vermilion: return Color(light: 0xC4462B, dark: 0xCE5B3E)
        case .indigo: return Color(light: 0x3D5C99, dark: 0x7396D8)
        case .pine: return Color(light: 0x2F6F5E, dark: 0x5FA98F)
        case .graphite: return Color(light: 0x4C4C50, dark: 0xA6A6AD)
        }
    }

    private func paperSwatch(_ tone: PaperTone) -> Color {
        switch tone {
        case .front: return Color(light: 0xF5F6F7, dark: 0x17171A)
        case .blue: return Color(light: 0xEAF1F7, dark: 0x14181C)
        case .warm: return Color(light: 0xF3F0E7, dark: 0x171614)
        case .cool: return Color(light: 0xEEF1F1, dark: 0x15181A)
        case .plain: return Color(light: 0xF6F6F4, dark: 0x1A1A1A)
        }
    }

    // MARK: 数据动作

    private func exportBackup() {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "FU ToDo 备份-\(store.currentDay).json"
        panel.allowedContentTypes = [.json]
        panel.canCreateDirectories = true
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try store.exportData().write(to: url, options: .atomic)
            message = "已导出备份：\(url.lastPathComponent)"
        } catch {
            message = "导出失败：\(error.localizedDescription)"
        }
    }

    private func importBackup() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let data = try Data(contentsOf: url)
            pendingImport = data
            message = nil
        } catch {
            message = "读取失败：\(error.localizedDescription)"
        }
    }

    private func openDataFolder() {
        guard let url = store.dataFileURL else {
            message = "还没有数据文件（写下一件事之后就会出现）"
            return
        }
        if FileManager.default.fileExists(atPath: url.path) {
            NSWorkspace.shared.activateFileViewerSelecting([url])
        } else {
            NSWorkspace.shared.open(url.deletingLastPathComponent())
        }
    }
}

/// 让视图跟随设置刷新外观。
private struct ThemeSync: ViewModifier {
    @EnvironmentObject var store: TaskStore
    @ObservedObject private var theme = ThemeSource.shared

    func body(content: Content) -> some View {
        content
            // 配色一变整棵子树重建：配色切换很少发生，重建代价可以忽略
            .id(theme.revision)
            .onAppear { theme.sync(store.settings) }
            .onChange(of: store.settings) { _, newValue in theme.sync(newValue) }
    }
}

extension View {
    public func themeSynced() -> some View { modifier(ThemeSync()) }
}
