import SwiftUI

public struct PaletteAction: Identifiable {
    public let id = UUID()
    public let title: String
    public let hint: String
    public let run: () -> Void

    public init(title: String, hint: String, run: @escaping () -> Void) {
        self.title = title
        self.hint = hint
        self.run = run
    }
}

/// ⌘K 命令面板：键盘优先，搜索后回车执行。
public struct CommandPaletteView: View {
    let actions: [PaletteAction]
    let onClose: () -> Void

    public init(actions: [PaletteAction], onClose: @escaping () -> Void) {
        self.actions = actions
        self.onClose = onClose
    }

    @State private var query = ""
    @State private var index = 0
    @FocusState private var focused: Bool

    private var filtered: [PaletteAction] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return actions }
        return actions.filter { $0.title.localizedCaseInsensitiveContains(q) || $0.hint.localizedCaseInsensitiveContains(q) }
    }

    public var body: some View {
        ZStack {
            Color.black.opacity(0.28).ignoresSafeArea().onTapGesture { onClose() }

            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 10) {
                    Text("⌘K").font(Theme.mono(8.5, .semibold)).tracking(1)
                        .foregroundStyle(Theme.canvas)
                        .padding(.horizontal, 6).padding(.vertical, 3)
                        .background(Rectangle().fill(Theme.ink))
                    TextField("搜索动作：专注、年视图、导出海报、主题…", text: $query)
                        .textFieldStyle(.plain)
                        .font(Theme.sans(15))
                        .foregroundStyle(Theme.ink)
                        .focused($focused)
                        .onSubmit { run() }
                        .onKeyPress(.downArrow) { move(1); return .handled }
                        .onKeyPress(.upArrow) { move(-1); return .handled }
                        .onKeyPress(.escape) { onClose(); return .handled }
                    Spacer()
                    Text("\(filtered.count)").font(Theme.mono(8.5)).foregroundStyle(Theme.ink3)
                }
                .padding(.horizontal, 16)
                .frame(height: 52)

                Rectangle().fill(Theme.rule).frame(height: 0.8)

                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(Array(filtered.enumerated()), id: \.element.id) { i, action in
                            Button {
                                index = i
                                run()
                            } label: {
                                HStack(alignment: .firstTextBaseline, spacing: 12) {
                                    Text(String(format: "%02d", i + 1))
                                        .font(Theme.mono(8)).foregroundStyle(i == index ? Theme.canvas.opacity(0.6) : Theme.ink3)
                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(action.title).font(Theme.sans(13.5, .medium))
                                            .foregroundStyle(i == index ? Theme.canvas : Theme.ink)
                                        Text(action.hint).font(Theme.mono(8)).tracking(0.6)
                                            .foregroundStyle(i == index ? Theme.canvas.opacity(0.6) : Theme.ink3)
                                    }
                                    Spacer()
                                    if i == index {
                                        Text("⏎").font(Theme.mono(9)).foregroundStyle(Theme.canvas.opacity(0.7))
                                    }
                                }
                                .padding(.horizontal, 16)
                                .frame(height: 44)
                                .background(i == index ? Theme.ink : Color.clear)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                        if filtered.isEmpty {
                            Text("没有匹配的动作").font(Theme.sans(12)).foregroundStyle(Theme.ink3)
                                .frame(maxWidth: .infinity).padding(.vertical, 24)
                        }
                    }
                }
                .frame(maxHeight: 320)

                Rectangle().fill(Theme.rule).frame(height: 0.8)
                HStack {
                    Text("↑↓ 选择 · ⏎ 执行 · Esc 关闭").font(Theme.mono(8)).tracking(1).foregroundStyle(Theme.ink3)
                    Spacer()
                    Text("FU TODO  /  COMMAND").font(Theme.mono(8)).tracking(1.4).foregroundStyle(Theme.ink3)
                }
                .padding(.horizontal, 16).frame(height: 34)
            }
            .frame(width: 590)
            .background(Theme.surface)
            .overlay(Rectangle().strokeBorder(Theme.ink, lineWidth: 1.2))
        }
        .onAppear { focused = true }
    }

    private func move(_ delta: Int) {
        guard !filtered.isEmpty else { return }
        index = (index + delta + filtered.count) % filtered.count
    }

    private func run() {
        guard filtered.indices.contains(index) else { return }
        let action = filtered[index]
        onClose()
        action.run()
    }
}
