import SwiftUI
import AppKit
import Core
import UI

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    /// 从程序坞 / 访达再次打开时，如果没有可见窗口（比如只剩「设置」），
    /// 把主窗口叫到前面，避免出现"点了图标只看到设置"的情况。
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            for window in sender.windows where window.canBecomeMain {
                window.makeKeyAndOrderFront(nil)
                return true
            }
        }
        return true
    }
}

@main
struct YiRiYiJianApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var store: TaskStore
    @StateObject private var updater = Updater()

    init() {
        let demo = CommandLine.arguments.contains("--demo")
        let url: URL?
        if demo {
            if let base = TaskStore.defaultStoreURL()?.deletingLastPathComponent() {
                url = base.appendingPathComponent("demo.json")
            } else {
                url = nil
            }
        } else {
            url = TaskStore.defaultStoreURL()
        }
        let store = TaskStore(storeURL: url)
        if demo, store.tasks.isEmpty {
            SampleData.populate(store)
        }
        store.checkRollover()
        _store = StateObject(wrappedValue: store)
    }

    var body: some Scene {
        WindowGroup("FU ToDo") {
            RootView()
                .environmentObject(store)
                .environmentObject(updater)
                .frame(minWidth: 1040, minHeight: 660)
                .onAppear {
                    Theme.apply(store.settings)
                    store.startRolloverTimer()
                    NSApp.activate(ignoringOtherApps: true)
                }
        }
        .defaultSize(width: 1200, height: 760)
        .windowResizability(.contentMinSize)

        Window("使用说明", id: "help") {
            HelpView().environmentObject(store)
        }
        .windowResizability(.contentSize)
        .defaultPosition(.center)

        Settings {
            SettingsView()
                .environmentObject(store)
                .environmentObject(updater)
        }
    }
}
