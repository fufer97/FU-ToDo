import SwiftUI
import AppKit
import UniformTypeIdentifiers
import Core

/// 设置窗口：主题（四选一）、字号、更新、引导与数据。
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
                VStack(alignment: .leading, spacing: 24) {
                    themeSection
                    optionsSection
                    previewSection
                    dataSection
                }
                .padding(22)
            }
            if let message {
                Rectangle().fill(Theme.rule).frame(height: 0.8)
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

    // MARK: 主题

    private var themeSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("主题")
            ForEach(ThemeChoice.available, id: \.self) { theme in
                themeRow(theme)
            }
            Text("日课是纸，夜之城是夜晚；切换后立即生效（夜之城会切换系统深浅色外观）。")
                .font(Theme.sans(10.5))
                .foregroundStyle(Theme.ink3)
        }
    }

    private func themeRow(_ theme: ThemeChoice) -> some View {
        let current = store.settings.theme == theme
        return Button {
            store.updateSettings { $0.theme = theme }
        } label: {
            HStack(spacing: 12) {
                themeThumbnail(theme).frame(width: 96, height: 58)
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 7) {
                        Text(theme.label)
                            .font(Theme.sans(13, .semibold))
                            .foregroundStyle(Theme.ink)
                        Text(theme.en)
                            .font(Theme.mono(7.5))
                            .tracking(1)
                            .foregroundStyle(Theme.ink3)
                        if current {
                            Text("当前")
                                .font(Theme.sans(9.5, .semibold))
                                .foregroundStyle(Theme.accent)
                                .padding(.horizontal, 5).padding(.vertical, 1)
                                .overlay(Capsule().strokeBorder(Theme.accent.opacity(0.6), lineWidth: 0.8))
                        }
                    }
                    Text(theme.note)
                        .font(Theme.sans(10.5))
                        .foregroundStyle(Theme.ink3)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 0)
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.surface)
            .overlay(
                Rectangle().strokeBorder(current ? Theme.accent : Theme.rule, lineWidth: current ? 1.4 : 0.8)
            )
        }
        .buttonStyle(.plain)
    }

    private func themeThumbnail(_ theme: ThemeChoice) -> some View {
        ZStack(alignment: .topLeading) {
            Rectangle().fill(themeCanvas(theme))
            HStack(alignment: .top, spacing: 6) {
                Text("十月")
                    .font(Theme.previewDisplay(theme, 18))
                    .foregroundStyle(themeInk(theme))
                Spacer(minLength: 0)
                Rectangle()
                    .fill(themeFill(theme))
                    .frame(width: 20, height: 20)
            }
            .padding(7)
            VStack(alignment: .leading, spacing: 3) {
                Spacer()
                Rectangle().fill(themeInk(theme).opacity(0.45)).frame(width: 34, height: 2)
                Rectangle().fill(themeCard(theme)).frame(width: 52, height: 14)
                    .overlay(Rectangle().strokeBorder(themeInk(theme).opacity(0.3), lineWidth: 0.6))
            }
            .padding(7)
        }
        .frame(height: 54)
        .overlay(Rectangle().strokeBorder(Theme.rule, lineWidth: 0.6))
    }

    private func themeCanvas(_ t: ThemeChoice) -> Color {
        switch t {
        case .rike: return Color(.sRGB, red: 0.980, green: 0.976, blue: 0.961, opacity: 1)
        case .night: return Color(.sRGB, red: 0.047, green: 0.051, blue: 0.067, opacity: 1)
        }
    }
    private func themeInk(_ t: ThemeChoice) -> Color {
        switch t {
        case .rike: return Color(.sRGB, red: 0.102, green: 0.102, blue: 0.094, opacity: 1)
        case .night: return Color(.sRGB, red: 0.910, green: 0.902, blue: 0.875, opacity: 1)
        }
    }
    private func themeFill(_ t: ThemeChoice) -> Color {
        switch t {
        case .rike: return Color(.sRGB, red: 0.765, green: 0.251, blue: 0.169, opacity: 1)
        case .night: return Color(.sRGB, red: 0.988, green: 0.933, blue: 0.039, opacity: 1)
        }
    }
    private func themeCard(_ t: ThemeChoice) -> Color {
        switch t {
        case .rike: return Color(.sRGB, red: 0.980, green: 0.976, blue: 0.961, opacity: 1)
        case .night: return Color(.sRGB, red: 0.075, green: 0.082, blue: 0.106, opacity: 1)
        }
    }

    // MARK: 其他选项

    private var optionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
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
            row("更新") {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 10) {
                        Toggle("", isOn: binding(\.autoCheckUpdates))
                            .labelsHidden()
                            .toggleStyle(.switch)
                            .controlSize(.small)
                        Text("启动时自动检查").font(Theme.sans(12)).foregroundStyle(Theme.ink2)
                        Spacer()
                        TextButton("检查更新") { _Concurrency.Task { await updater.check() } }
                    }
                    Text(updater.status.text.isEmpty ? "当前版本 \(AppVersion.current)" : updater.status.text)
                        .font(Theme.sans(11)).foregroundStyle(Theme.ink3)
                }
            }
            row("音效") {
                Toggle("", isOn: binding(\.soundEnabled))
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .controlSize(.small)
                Text("完成与翻页的轻音效 / 触感").font(Theme.sans(12)).foregroundStyle(Theme.ink2)
            }
            row("引导") {
                TextButton("重新看一次首次引导") {
                    store.resetWelcome()
                    message = "关闭设置窗口后重新打开应用，就会再次看到引导。"
                }
            }
        }
    }

    // MARK: 预览

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
            }
            .padding(12)
            .background(Theme.surface)
            .overlay(Rectangle().strokeBorder(Theme.rule, lineWidth: 0.8))
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
                .font(Theme.sans(11)).foregroundStyle(Theme.ink3)
        }
    }

    // MARK: 组件

    private func sectionTitle(_ text: String) -> some View {
        Text(text).font(Theme.mono(9.5, .semibold)).tracking(1.4).foregroundStyle(Theme.ink3)
    }

    private func row<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        HStack(alignment: .center, spacing: 14) {
            Text(label).font(Theme.sans(12.5)).foregroundStyle(Theme.ink2)
                .frame(width: 52, alignment: .leading)
            content()
            Spacer()
        }
    }

    private func plainButton(_ title: String, danger: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(Theme.sans(12, .medium))
                .foregroundStyle(danger ? Theme.accent : Theme.ink)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Theme.surface)
                .overlay(Rectangle().strokeBorder(danger ? Theme.accent.opacity(0.6) : Theme.rule, lineWidth: 0.8))
        }
        .buttonStyle(.plain)
    }

    private func binding<T>(_ keyPath: WritableKeyPath<AppSettings, T>) -> Binding<T> {
        Binding(
            get: { store.settings[keyPath: keyPath] },
            set: { value in store.updateSettings { $0[keyPath: keyPath] = value } }
        )
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
            pendingImport = try Data(contentsOf: url)
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
            .id(theme.revision)
            .onAppear { theme.sync(store.settings) }
            .onChange(of: store.settings) { _, newValue in theme.sync(newValue) }
    }
}

extension View {
    public func themeSynced() -> some View { modifier(ThemeSync()) }
}
