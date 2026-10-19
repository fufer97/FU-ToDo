import SwiftUI
import AppKit
import Core
import UI

/// 把真实界面离屏渲染成 PNG，用于设计评审（本机没有屏幕录制权限，无法截图）。
@main
struct RenderMain {
    @MainActor
    static func main() {
        let outDir = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "shots")
        try? FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)

        let seeded = makeStore(seeded: true)

        // --check-update：跑应用里真正的那段检查更新代码
        if CommandLine.arguments.contains("--check-update") {
            let updater = Updater()
            let done = DispatchSemaphore(value: 0)
            _Concurrency.Task { @MainActor in
                await updater.check()
                print("检查结果：\(updater.status.text)")
                if case .available(let v, let url) = updater.status {
                    print("  版本：\(v)\n  下载页：\(url.absoluteString)")
                }
                done.signal()
            }
            while done.wait(timeout: .now() + 0.1) == .timedOut {
                RunLoop.main.run(until: Date().addingTimeInterval(0.05))
            }
            return
        }

        // --bench：量一帧的渲染成本（拖动时每一帧都要走这条路径）
        if CommandLine.arguments.contains("--bench") {
            benchmark(seeded)
            return
        }

        // --cards：卡片家族（同一任务在四个浅色主题里的四种印刷品）
        if CommandLine.arguments.contains("--cards") {
            render(CardFamilyBoard(), size: CGSize(width: 1400, height: 1000),
                   to: outDir.appendingPathComponent("v7-card-family.png"))
            return
        }

        // --focus：专注模式样张
        if CommandLine.arguments.contains("--focus") {
            let focusStore = makeStore(seeded: true)
            Theme.apply(focusStore.settings)
            render(
                FocusModeView(onClose: {}).environmentObject(focusStore),
                size: CGSize(width: 1200, height: 760),
                to: outDir.appendingPathComponent("30-focus.png")
            )
            return
        }

        // --specimen：标本卡组件样张（Herbarium 风格的浅色版）
        if CommandLine.arguments.contains("--specimen") {
            render(SpecimenBoard(), size: CGSize(width: 1200, height: 760),
                   to: outDir.appendingPathComponent("v6-specimen-card.png"))
            return
        }

        // --themes：四套主题（器物 / 档案 / 天文台 / 酸纸），同一结构不同世界
        if CommandLine.arguments.contains("--themes") {
            for t in SpreadTheme.all {
                render(ThemeSpread(theme: t), size: CGSize(width: 1200, height: 760),
                       to: outDir.appendingPathComponent("v5-theme-\(t.id).png"))
            }
            return
        }

        // --radical：整窗色域 + 满高日页（工坊 / 档案）
        if CommandLine.arguments.contains("--radical") {
            render(RadicalSpread(night: false), size: CGSize(width: 1200, height: 760),
                   to: outDir.appendingPathComponent("v4-spread-day.png"))
            render(RadicalSpread(night: true), size: CGSize(width: 1200, height: 760),
                   to: outDir.appendingPathComponent("v4-spread-night.png"))
            render(RadicalSpread(night: false, mosaic: true), size: CGSize(width: 1200, height: 760),
                   to: outDir.appendingPathComponent("v4-mosaic-day.png"))
            render(RadicalSpread(night: true, mosaic: true), size: CGSize(width: 1200, height: 760),
                   to: outDir.appendingPathComponent("v4-mosaic-night.png"))
            return
        }

        // --frames：三张风格帧（标本室 / 酸纸 / 工坊），只用于选方向
        if CommandLine.arguments.contains("--frames") {
            render(FrameArchive(), size: CGSize(width: 900, height: 560),
                   to: outDir.appendingPathComponent("style-A-archive.png"))
            render(FrameAcid(), size: CGSize(width: 900, height: 560),
                   to: outDir.appendingPathComponent("style-B-acid.png"))
            render(FrameAtelier(), size: CGSize(width: 900, height: 560),
                   to: outDir.appendingPathComponent("style-C-atelier.png"))
            return
        }

        // --tokens：设计校准 A/B（画布 / 夜航），不写正式 shots
        if CommandLine.arguments.contains("--tokens") {
            render(TokenSheetView(dark: false), size: CGSize(width: 1400, height: 1000),
                   to: outDir.appendingPathComponent("00-tokens-light.png"))
            render(TokenSheetView(dark: true), size: CGSize(width: 1400, height: 1000),
                   to: outDir.appendingPathComponent("00-tokens-dark.png"))
            render(ConceptMainV2(dark: false), size: CGSize(width: 1200, height: 760),
                   to: outDir.appendingPathComponent("00-concept-main-light.png"))
            render(ConceptMainV2(dark: true), size: CGSize(width: 1200, height: 760),
                   to: outDir.appendingPathComponent("00-concept-main-dark.png"))
            return
        }
        let empty = makeStore(seeded: false)

        render(
            RootView().environmentObject(seeded).environmentObject(Updater()),
            size: CGSize(width: 1200, height: 760),
            to: outDir.appendingPathComponent("01-main-light.png")
        )
        render(
            RootView().environmentObject(empty).environmentObject(Updater()),
            size: CGSize(width: 1200, height: 760),
            to: outDir.appendingPathComponent("02-empty-day.png")
        )
        Theme.apply(seeded.settings)
        render(
            FocusModeView(onClose: {}).environmentObject(seeded),
            size: CGSize(width: 1200, height: 760),
            to: outDir.appendingPathComponent("30-focus.png")
        )
        let emptyFocus = makeStore(seeded: false)
        Theme.apply(emptyFocus.settings)
        render(
            FocusModeView(onClose: {}).environmentObject(emptyFocus),
            size: CGSize(width: 1200, height: 760),
            to: outDir.appendingPathComponent("30b-focus-empty.png")
        )

        render(
            YearView(onClose: {}).environmentObject(seeded),
            size: CGSize(width: 1200, height: 760),
            to: outDir.appendingPathComponent("31-year.png")
        )
        if let built = PosterBuilder.build(store: seeded) {
            render(
                MonthPosterView(year: built.year, month: built.month, days: built.days),
                size: CGSize(width: 1200, height: 1600),
                to: outDir.appendingPathComponent("33-poster.png")
            )
        }
        render(
            CommandPaletteView(actions: [
                PaletteAction(title: "专注模式", hint: "⌘⇧F") {},
                PaletteAction(title: "年视图", hint: "⌘Y") {},
                PaletteAction(title: "导出本月海报", hint: "PNG") {},
                PaletteAction(title: "主题：标本室", hint: "HERBARIUM") {}
            ], onClose: {}),
            size: CGSize(width: 1200, height: 760),
            to: outDir.appendingPathComponent("32-palette.png")
        )

        render(
            PoolSheetView(onClose: {}).environmentObject(seeded).environmentObject(DragController()),
            size: CGSize(width: 620, height: 560),
            to: outDir.appendingPathComponent("03-pool.png")
        )
        render(
            DoneSheetView(onClose: {}).environmentObject(seeded).environmentObject(DragController()),
            size: CGSize(width: 620, height: 560),
            to: outDir.appendingPathComponent("04-done.png")
        )

        render(
            SettingsView().environmentObject(seeded).environmentObject(Updater()),
            size: CGSize(width: 470, height: 650),
            to: outDir.appendingPathComponent("06-settings.png")
        )
        // 加高一张，方便看到设置页的全部内容（含使用说明）
        render(
            SettingsView().environmentObject(seeded).environmentObject(Updater()),
            size: CGSize(width: 470, height: 650),
            to: outDir.appendingPathComponent("09-settings-full.png")
        )

        // 器物主题
        seeded.updateSettings {
            $0.theme = .atelier
            $0.fontScale = .medium
        }
        Theme.apply(seeded.settings)
        render(
            RootView().environmentObject(seeded).environmentObject(Updater()),
            size: CGSize(width: 1200, height: 760),
            to: outDir.appendingPathComponent("07-main-atelier.png")
        )

        // 只有支线、没有主线的状态
        let branchesOnly = makeStore(seeded: false)
        branchesOnly.addTopLevel("回一封邮件", on: branchesOnly.currentDay)
        branchesOnly.addTopLevel("整理收件箱", on: branchesOnly.currentDay)
        Theme.apply(branchesOnly.settings)
        render(
            RootView().environmentObject(branchesOnly).environmentObject(Updater()),
            size: CGSize(width: 1200, height: 760),
            to: outDir.appendingPathComponent("08-no-main.png")
        )

        // 输入行单独看一眼（新建时的样子）
        let inputStore = makeStore(seeded: false)
        _ = inputStore.addMain("写完产品原型说明")
        let branch = inputStore.addTopLevel("回一封邮件")!
        let session = InputSession()
        session.startCreate(store: inputStore, at: branch.id, mode: .sibling)
        Theme.apply(inputStore.settings)
        render(
            VStack(spacing: 0) {
                TaskRowView(task: inputStore.roots(of: inputStore.currentDay)[0], level: 1, isMain: true)
                TaskRowView(task: branch, level: 1)
            }
            .padding(16)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(Theme.surface)
            .environmentObject(inputStore)
            .environmentObject(session)
            .environmentObject(DragController()),
            size: CGSize(width: 402, height: 220),
            to: outDir.appendingPathComponent("10-input-row.png")
        )

        // 拖动经过行时的两个投放区
        let dragStore = makeStore(seeded: false)
        let dragMain = dragStore.addMain("写完产品原型说明")!
        let dragBranch = dragStore.addTopLevel("回一封邮件")!
        let dragStep = dragStore.addChild(of: dragMain.id, title: "整理阶段 1 的规则条目")!
        let dragSession = InputSession()
        let dragCtl = DragController()
        Theme.apply(dragStore.settings)

        func dragView(_ zone: DropZone, _ name: String) {
            dragCtl.draggingId = dragBranch.id
            dragCtl.target = DragState(draggedId: dragBranch.id, targetId: dragStep.id, zone: zone)
            render(
                VStack(spacing: 0) {
                    TaskRowView(task: dragMain, level: 1, isMain: true)
                    TaskRowView(task: dragStep, level: 2)
                }
                .padding(16)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .background(Theme.surface)
                .environmentObject(dragStore)
                .environmentObject(dragSession)
                .environmentObject(dragCtl),
                size: CGSize(width: 402, height: 190),
                to: outDir.appendingPathComponent(name)
            )
        }
        dragView(.nest, "12-drop-right-nest.png")
        // 一级卡片：左上半＝排在它前面，左下半＝排在它后面（与子步骤同一套）
        dragCtl.draggingId = dragBranch.id
        dragCtl.target = DragState(draggedId: dragBranch.id, targetId: dragMain.id, zone: .before)
        render(
            VStack(spacing: 0) { TaskRowView(task: dragMain, level: 1, isMain: true) }
                .padding(16).frame(width: 402, height: 90, alignment: .topLeading)
                .background(Theme.paper)
                .environmentObject(dragStore).environmentObject(dragSession).environmentObject(dragCtl),
            size: CGSize(width: 402, height: 90),
            to: outDir.appendingPathComponent("24-card-before.png")
        )
        dragCtl.target = DragState(draggedId: dragBranch.id, targetId: dragMain.id, zone: .after)
        render(
            VStack(spacing: 0) { TaskRowView(task: dragMain, level: 1, isMain: true) }
                .padding(16).frame(width: 402, height: 90, alignment: .topLeading)
                .background(Theme.paper)
                .environmentObject(dragStore).environmentObject(dragSession).environmentObject(dragCtl),
            size: CGSize(width: 402, height: 90),
            to: outDir.appendingPathComponent("25-card-after.png")
        )
        dragView(.before, "13-drop-left-sibling.png")
        dragView(.after, "17-drop-left-sibling-after.png")

        // 一级卡片之间：顺序调整只有插入线，没有半区高亮
        dragCtl.draggingId = dragStep.id
        dragCtl.target = DragState(draggedId: dragStep.id, targetId: dragBranch.id, zone: .before)
        render(
            VStack(spacing: 9) {
                TaskRowView(task: dragMain, level: 1, isMain: true)
                TaskRowView(task: dragBranch, level: 1)
            }
            .padding(16)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(Theme.paper)
            .environmentObject(dragStore)
            .environmentObject(dragSession)
            .environmentObject(dragCtl),
            size: CGSize(width: 402, height: 170),
            to: outDir.appendingPathComponent("15-card-order.png")
        )
        dragCtl.end()

        // 用真实数据渲染一次，用于复现问题
        let userURL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/FU ToDo/data.json")
        if let userStore = TaskStore(storeURL: userURL) as TaskStore? {
            Theme.apply(userStore.settings)
            render(
                RootView().environmentObject(userStore).environmentObject(Updater()),
                size: CGSize(width: 1200, height: 760),
                to: outDir.appendingPathComponent("14-user-data.png")
            )
            print("用户数据里今日完成：", userStore.doneTasks(on: userStore.currentDay).map(\.title))
        }

        // 卡片提起 + 让位 + 插入线（直接渲染日页，便于注入拖动状态）
        let cardStore = makeStore(seeded: false)
        let cardMain = cardStore.addMain("写完产品原型说明")!
        _ = cardStore.addChild(of: cardMain.id, title: "整理阶段 1 的规则条目")
        let cardA = cardStore.addTopLevel("回一封邮件")!
        let cardB = cardStore.addTopLevel("整理本月会议记录")!
        _ = cardStore.addChild(of: cardB.id, title: "收集上个月的会议记录")
        _ = cardStore.addChild(of: cardB.id, title: "按项目归类")
        let cardC = cardStore.addTopLevel("预约体检")!
        Theme.apply(cardStore.settings)

        func cardView(_ name: String, configure: (DragController) -> Void) {
            let controller = DragController()
            configure(controller)
            render(
                DayPageView(day: cardStore.currentDay)
                    .frame(width: 402)
                    .background(Theme.paper)
                    .environmentObject(cardStore)
                    .environmentObject(InputSession())
                    .environmentObject(controller),
                size: CGSize(width: 402, height: 700),
                to: outDir.appendingPathComponent(name)
            )
        }

        print("支线顺序：", cardStore.branches(on: cardStore.currentDay).map(\.title))
        cardView("16-card-drag.png") { controller in
            controller.draggingId = cardC.id
            controller.target = DragState(draggedId: cardC.id, targetId: cardB.id, zone: .before)
        }
        cardView("18-card-insert.png") { controller in
            controller.draggingId = cardC.id
            controller.insertIndex = 0
        }
        // 不拖动时的常态（用于对比收起效果）
        cardView("19-card-expanded.png") { _ in }
        _ = cardA

        // 预设生效检查：墨蓝（冷纸 + 靛蓝）
        let presetStore = makeStore(seeded: true)
        presetStore.updateSettings { $0.theme = .blueprint }
        Theme.apply(presetStore.settings)
        print("蓝图主题：\(presetStore.settings.theme)")
        render(
            RootView().environmentObject(presetStore).environmentObject(Updater()),
            size: CGSize(width: 1200, height: 760),
            to: outDir.appendingPathComponent("20-main-blueprint.png")
        )

        // 首次引导（固定标本室主题）
        seeded.updateSettings { $0.theme = .herbarium; $0.fontScale = .medium }
        Theme.apply(seeded.settings)
        render(
            WelcomeSheet(onOpenHelp: {}, onClose: {})
                .environmentObject(seeded),
            size: CGSize(width: 420, height: 440),
            to: outDir.appendingPathComponent("23-welcome.png")
        )

        // 使用说明按真实窗口尺寸截
        render(
            HelpView().environmentObject(seeded),
            size: CGSize(width: 470, height: 640),
            to: outDir.appendingPathComponent("11-help.png")
        )

        // 恢复默认，避免影响后续
        seeded.updateSettings {
            $0.theme = .herbarium
            $0.fontScale = .medium
        }
        Theme.apply(seeded.settings)

        print("输出目录：\(outDir.path)")
    }

    @MainActor
    static func makeStore(seeded: Bool) -> TaskStore {
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("yrjy-shot-\(UUID().uuidString).json")
        let store = TaskStore(storeURL: url, today: DayKey.key())
        if seeded {
            SampleData.populate(store)
            store.selectDay(store.currentDay)
        }
        return store
    }

    /// 帧成本基准：宿主视图只建一次，之后反复变化状态，只量 SwiftUI 更新 + 布局。
    /// （离屏软件绘制有 ~470ms 固定成本，会盖住真正要看的增量。）
    @MainActor
    private static func benchmark(_ store: TaskStore) {
        func host(_ view: some View, _ size: CGSize) -> (NSHostingView<AnyView>, NSWindow, NSBitmapImageRep)? {
            let hosting = NSHostingView(rootView: AnyView(view.frame(width: size.width, height: size.height)))
            hosting.frame = NSRect(origin: .zero, size: size)
            let window = NSWindow(
                contentRect: NSRect(origin: .zero, size: size),
                styleMask: [.borderless],
                backing: .buffered,
                defer: false
            )
            window.contentView = hosting
            window.isReleasedWhenClosed = false
            window.orderBack(nil)
            hosting.layoutSubtreeIfNeeded()
            RunLoop.main.run(until: Date().addingTimeInterval(0.4))
            guard let rep = hosting.bitmapImageRepForCachingDisplay(in: hosting.bounds) else { return nil }
            return (hosting, window, rep)
        }

        func measureUpdate(_ label: String, _ hosting: NSHostingView<AnyView>, _ mutate: (Int) -> Void, rounds: Int = 60) {
            func cycle() -> Double {
                let t = CFAbsoluteTimeGetCurrent()
                RunLoop.main.run(until: Date().addingTimeInterval(0.002))
                hosting.layoutSubtreeIfNeeded()
                return CFAbsoluteTimeGetCurrent() - t
            }
            for i in 0..<6 { mutate(i); _ = cycle() }             // 预热
            var base = 0.0
            for _ in 0..<rounds { base += cycle() }
            var changed = 0.0
            for i in 0..<rounds { mutate(i); changed += cycle() }
            let delta = (changed - base) / Double(rounds) * 1000
            print(String(format: "%@：更新+布局 %.2f ms/帧（无变化基线 %.2f）→ 占 16.7ms 预算的 %.0f%%",
                         label, delta, base / Double(rounds) * 1000, max(0, delta) / 16.67 * 100))
        }

        // 0) 实时切换配色：同一个窗口里改设置，看像素有没有真的变
        let themeStore = makeStore(seeded: true)
        if let (hosting, window, rep) = host(
            RootView().environmentObject(themeStore).environmentObject(Updater()),
            CGSize(width: 1200, height: 760)
        ) {
            func panelPixel(_ label: String) {
                RunLoop.main.run(until: Date().addingTimeInterval(0.05))
                hosting.layoutSubtreeIfNeeded()
                hosting.cacheDisplay(in: hosting.bounds, to: rep)
                let px = rep.colorAt(x: 1160, y: 700) ?? .black      // 日页面板空白处
                let cal = rep.colorAt(x: 200, y: 700) ?? .black      // 日历空白处
                print(String(format: "%@：日页 rgb(%.0f,%.0f,%.0f)  日历 rgb(%.0f,%.0f,%.0f)",
                             label,
                             px.redComponent * 255, px.greenComponent * 255, px.blueComponent * 255,
                             cal.redComponent * 255, cal.greenComponent * 255, cal.blueComponent * 255))
            }
            panelPixel("切换前（暖纸）")
            themeStore.updateSettings { $0.theme = .blueprint }
            panelPixel("切到墨蓝后")
            window.orderOut(nil)
        }

        // 1) 整体界面：切换选中日期（最重的常规路径）
        if let (hosting, window, _) = host(
            RootView().environmentObject(store).environmentObject(Updater()),
            CGSize(width: 1200, height: 760)
        ) {
            let other = store.tasks.first(where: { $0.day != store.currentDay })?.day ?? store.currentDay
            measureUpdate("整体界面：切换日期", hosting) { i in
                store.selectDay(i % 2 == 0 ? store.currentDay : other)
            }
            window.orderOut(nil)
        }

        // 2) 拖动路径：直接驱动日页（RootView 内部有自己的 DragController）
        let controller = DragController()
        if let (hosting, window, _) = host(
            DayPageView(day: store.currentDay)
                .background(Theme.paper)
                .environmentObject(store)
                .environmentObject(InputSession())
                .environmentObject(controller),
            CGSize(width: 402, height: 700)
        ) {
            let branchCount = store.branches(on: store.currentDay).count
            controller.draggingId = store.branches(on: store.currentDay).first?.id
            measureUpdate("拖动中：插入位来回", hosting) { i in
                controller.insertIndex = branchCount > 1 ? (i % 2) : 0
            }
            controller.end()
            window.orderOut(nil)
        }
    }

    /// 建视图 + 布局 + 绘制到位图。基准测量只关心后面两步的耗时。
    @MainActor
    static func renderHost<V: View>(_ view: V, size: CGSize, settle: TimeInterval = 0.02) -> NSBitmapImageRep? {
        // 走真实 AppKit 渲染路径：ImageRenderer 不渲染 ScrollView 内容，也不渲染文本框。
        let hosting = NSHostingView(rootView: view.frame(width: size.width, height: size.height))
        hosting.frame = NSRect(origin: .zero, size: size)

        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.contentView = hosting
        window.isReleasedWhenClosed = false
        window.orderBack(nil)
        hosting.layoutSubtreeIfNeeded()
        if settle > 0 { RunLoop.main.run(until: Date().addingTimeInterval(settle)) }

        guard let rep = hosting.bitmapImageRepForCachingDisplay(in: hosting.bounds) else { return nil }
        hosting.cacheDisplay(in: hosting.bounds, to: rep)
        window.orderOut(nil)
        window.contentView = nil
        return rep
    }

    @MainActor
    static func render<V: View>(_ view: V, size: CGSize, to url: URL) {
        guard let rep = renderHost(view, size: size, settle: 0.45) else {
            print("✗ 无法创建位图：\(url.lastPathComponent)")
            return
        }
        guard let png = rep.representation(using: .png, properties: [:]) else {
            print("✗ 无法生成 PNG：\(url.lastPathComponent)")
            return
        }
        do {
            try png.write(to: url)
            print("✓ \(url.lastPathComponent)  \(Int(size.width))x\(Int(size.height))")
        } catch {
            print("✗ 写入失败 \(url.lastPathComponent): \(error)")
        }
    }
}
