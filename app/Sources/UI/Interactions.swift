import SwiftUI
import Core

/// 完成印章：同一个完成动作，在每套主题里盖自己的章。
struct CompletionStamp: View {
    let style: CardStyle
    let date: String

    var body: some View {
        content
            .rotationEffect(.degrees(-7))
            .shadow(color: Theme.ink.opacity(0.18), radius: 0, x: 3, y: 4)
    }

    @ViewBuilder
    private var content: some View {
        switch style {
        case .atelier:
            Text("已交付")
                .font(Theme.display(13))
                .foregroundStyle(Theme.canvas)
                .padding(.horizontal, 12).padding(.vertical, 6)
                .background(Circle().fill(Theme.stamp))
        case .herbarium:
            Text("DRIED & MOUNTED · \(date)")
                .font(Theme.mono(7)).tracking(0.6)
                .foregroundStyle(Theme.stamp)
                .padding(.horizontal, 10).padding(.vertical, 6)
                .overlay(Rectangle().strokeBorder(Theme.stamp, lineWidth: 1.1))
        case .acid:
            Text("DONE")
                .font(.system(size: 16, weight: .black))
                .foregroundStyle(Theme.cardBackground)
                .padding(.horizontal, 10).padding(.vertical, 3)
                .background(Rectangle().fill(Theme.stamp))
                .rotationEffect(.degrees(-4))
        case .blueprint:
            Text("REV. A")
                .font(.system(size: 15, weight: .black))
                .foregroundStyle(Theme.stamp)
                .padding(.horizontal, 8).padding(.vertical, 3)
                .overlay(Rectangle().strokeBorder(Theme.stamp, lineWidth: 1.2))
        }
    }
}

/// 专注模式：整窗只留今天的主线；可改标题、完成、加支线。
public struct FocusModeView: View {
    @EnvironmentObject var store: TaskStore
    let onClose: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(onClose: @escaping () -> Void) {
        self.onClose = onClose
    }

    private enum Field: Hashable { case main, newMain, branch }
    @State private var mainDraft = ""
    @State private var newBranch = ""
    @State private var editingMain = false
    @State private var showStamp = false
    @FocusState private var focus: Field?

    private var main: Task? { store.mainGoal(on: store.selectedDay) }
    private var branches: [Task] { store.branches(on: store.selectedDay) }
    private var finishedCount: Int { store.doneCount(on: store.selectedDay) }

    private var dayNumber: String {
        guard let date = DayKey.date(from: store.selectedDay) else { return "" }
        return String(Calendar(identifier: .gregorian).component(.day, from: date))
    }

    private var weekday: String {
        guard let date = DayKey.date(from: store.selectedDay) else { return "" }
        let w = Calendar(identifier: .gregorian).component(.weekday, from: date)
        return ["日", "一", "二", "三", "四", "五", "六"][max(0, min(6, w - 1))]
    }

    public var body: some View {
        ZStack(alignment: .topLeading) {
            Theme.canvas.ignoresSafeArea()
            Text(dayNumber)
                .font(Theme.display(360))
                .tracking(Theme.displayTracking(360))
                .foregroundStyle(Theme.ink.opacity(0.045))
                .offset(x: -10, y: 40)
                .allowsHitTesting(false)

            VStack(alignment: .leading, spacing: 0) {
                topBar
                Spacer(minLength: 0)
                mainBlock
                branchesBlock
                Spacer(minLength: 0)
                footer
            }
            .padding(52)

            if showStamp {
                CompletionStamp(style: Theme.cardStyle, date: store.selectedDay.replacingOccurrences(of: "-", with: "."))
                    .scaleEffect(1.5)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                    .transition(.scale(scale: 1.2).combined(with: .opacity))
                    .allowsHitTesting(false)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(reduceMotion ? nil : Motion.ring, value: showStamp)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                if main == nil { focus = .newMain }
            }
        }
        .onExitCommand(perform: onClose)
    }

    // MARK: 顶栏

    private var topBar: some View {
        HStack(alignment: .firstTextBaseline, spacing: 14) {
            Text("FU TODO  /  FOCUS").font(Theme.mono(9)).tracking(2.2).foregroundStyle(Theme.ink3)
            Text("\(dayNumber) · \(weekday)").font(Theme.mono(9)).tracking(1.6).foregroundStyle(Theme.ink3)
            Spacer()
            Button(action: onClose) {
                HStack(spacing: 6) {
                    Text("退出专注").font(Theme.mono(9, .semibold)).tracking(1)
                    Text("ESC").font(Theme.mono(7.5)).tracking(1).opacity(0.55)
                }
                .foregroundStyle(Theme.ink)
                .padding(.horizontal, 11).padding(.vertical, 6)
                .background(Rectangle().fill(Theme.surface.opacity(0.6)))
                .overlay(Rectangle().strokeBorder(Theme.ink.opacity(0.4), lineWidth: 0.8))
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.cancelAction)
        }
    }

    // MARK: 主线

    @ViewBuilder
    private var mainBlock: some View {
        Text("今天只做这一件").font(Theme.mono(9.5)).tracking(2).foregroundStyle(Theme.ink3)

        if let main {
            HStack(alignment: .bottom, spacing: 40) {
                VStack(alignment: .leading, spacing: 8) {
                    if editingMain {
                        TextField("", text: $mainDraft)
                            .textFieldStyle(.plain)
                            .font(Theme.display(56))
                            .tracking(Theme.displayTracking(56))
                            .foregroundStyle(Theme.ink)
                            .focused($focus, equals: .main)
                            .onSubmit(commitMain)
                            .padding(.horizontal, 6)
                            .overlay(alignment: .bottom) {
                                Rectangle().fill(Theme.ink.opacity(0.5)).frame(height: 1)
                            }
                    } else {
                        Text(main.title)
                            .font(Theme.display(64))
                            .tracking(Theme.displayTracking(64))
                            .foregroundStyle(Theme.ink)
                            .lineSpacing(-4)
                            .lineLimit(3)
                            .fixedSize(horizontal: false, vertical: true)
                            .onTapGesture {
                                mainDraft = main.title
                                editingMain = true
                                DispatchQueue.main.async { focus = .main }
                            }
                    }
                    Text(editingMain ? "回车保存 · Esc 放弃" : "点标题可直接改")
                        .font(Theme.mono(8)).tracking(0.8)
                        .foregroundStyle(Theme.ink3)
                }
                Spacer(minLength: 0)
                VStack(spacing: 8) {
                    BigRing(done: main.done) {
                        if main.done {
                            store.revert(main.id)
                        } else {
                            store.complete(main.id)
                            Feedback.complete()
                            if !reduceMotion {
                                showStamp = true
                                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { showStamp = false }
                            }
                        }
                    }
                    Text(main.done ? "恢复主线" : "完成主线")
                        .font(Theme.mono(7.5)).tracking(1)
                        .foregroundStyle(Theme.ink3)
                }
            }
        } else {
            VStack(alignment: .leading, spacing: 14) {
                Text("今天还没有主线").font(Theme.display(64))
                    .tracking(Theme.displayTracking(64))
                    .foregroundStyle(Theme.ink3)
                HStack(spacing: 10) {
                    TextField("写下今天最重要的一件事", text: $mainDraft)
                        .textFieldStyle(.plain)
                        .font(Theme.display(24))
                        .foregroundStyle(Theme.ink)
                        .focused($focus, equals: .newMain)
                        .onSubmit(addMain)
                        .padding(.horizontal, 12).padding(.vertical, 10)
                        .overlay(Rectangle().strokeBorder(Theme.ink.opacity(0.35), lineWidth: 0.9))
                    Button { addMain() } label: {
                        Text("写下来").font(Theme.mono(9, .semibold)).tracking(1)
                            .foregroundStyle(Theme.canvas)
                            .padding(.horizontal, 14).padding(.vertical, 10)
                            .background(Rectangle().fill(Theme.ink))
                    }
                    .buttonStyle(.plain)
                }
                Text("写好后按 ⏎；主线会立刻出现在这里").font(Theme.mono(8)).tracking(0.6).foregroundStyle(Theme.ink3)
            }
        }
    }

    private func commitMain() {
        guard let main else { return }
        let text = mainDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        if !text.isEmpty { store.rename(main.id, to: text) }
        editingMain = false
        focus = nil
    }

    private func addMain() {
        let text = mainDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        store.addMain(text, on: store.selectedDay)
        mainDraft = ""
        Feedback.complete()
        focus = nil
    }

    // MARK: 支线

    private var branchesBlock: some View {
        VStack(alignment: .leading, spacing: 0) {
            Rectangle().fill(Theme.rule).frame(height: 0.8).padding(.top, 28)
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("今日支线").font(Theme.mono(9)).tracking(2).foregroundStyle(Theme.ink3)
                Text("\(branches.count)").font(Theme.mono(8)).foregroundStyle(Theme.ink3)
                Spacer()
                Text("点圆环完成 · 点标题改").font(Theme.mono(7.5)).foregroundStyle(Theme.ink3)
            }
            .padding(.top, 10)

            if branches.isEmpty {
                Text("还没有支线，下面直接加一条").font(Theme.sans(12)).foregroundStyle(Theme.ink3)
                    .padding(.top, 10)
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(branches.prefix(8)) { task in
                            branchRow(task)
                        }
                        if branches.count > 8 {
                            Text("+\(branches.count - 8) 条支线，回今日页看全部")
                                .font(Theme.mono(8)).foregroundStyle(Theme.ink3)
                                .padding(.top, 8)
                        }
                    }
                }
                .frame(maxHeight: 190)
            }

            HStack(spacing: 10) {
                TextField("＋ 加一条支线", text: $newBranch)
                    .textFieldStyle(.plain)
                    .font(Theme.sans(13))
                    .foregroundStyle(Theme.ink)
                    .focused($focus, equals: .branch)
                    .onSubmit(addBranch)
                    .padding(.horizontal, 10).padding(.vertical, 8)
                    .overlay(Rectangle().strokeBorder(Theme.rule, lineWidth: 0.8))
                Button { addBranch() } label: {
                    Text("添加").font(Theme.mono(8.5, .semibold)).tracking(1)
                        .foregroundStyle(Theme.ink)
                        .padding(.horizontal, 12).padding(.vertical, 8)
                        .overlay(Rectangle().strokeBorder(Theme.ink.opacity(0.4), lineWidth: 0.8))
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 10)
        }
    }

    private func branchRow(_ task: Task) -> some View {
        HStack(spacing: 10) {
            RingView(level: 2, done: task.done, tint: Theme.ink) {
                if task.done { store.revert(task.id) } else { store.complete(task.id); Feedback.complete() }
            }
            Text(task.title)
                .font(Theme.sans(14))
                .foregroundStyle(task.done ? Theme.ink3 : Theme.ink2)
                .strikethrough(task.done, color: Theme.ink3)
            Spacer()
        }
        .frame(height: 38)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Theme.rule.opacity(0.6)).frame(height: 0.6)
        }
    }

    private func addBranch() {
        let text = newBranch.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        store.addTopLevel(text, on: store.selectedDay)
        newBranch = ""
        Feedback.complete()
    }

    // MARK: 页脚

    private var footer: some View {
        HStack {
            Text(footerHint).font(Theme.mono(8.5)).tracking(0.8).foregroundStyle(Theme.ink3)
            Spacer()
            if finishedCount > 0 {
                Text("今日已完成 \(finishedCount) 件").font(Theme.mono(8.5)).foregroundStyle(Theme.ink3)
            }
        }
    }

    private var footerHint: String {
        if main == nil { return "写下主线后按 ⏎ · 退出后回到今日页" }
        return "点大圆环完成主线 · Esc 退出 · 标题可直接改"
    }
}

private struct BigRing: View {
    let done: Bool
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle().strokeBorder(hovering ? Theme.ink : Theme.control, lineWidth: 2)
                    .frame(width: 56, height: 56)
                if done {
                    Circle().fill(Theme.accent).frame(width: 56, height: 56)
                    Image(systemName: "checkmark")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(Theme.canvas)
                }
            }
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .help(done ? "恢复这条主线" : "完成今天的主线")
    }
}
