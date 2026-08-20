import AppKit
import SwiftUI

@main
struct WallpsApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    private let state = AppState.shared

    var body: some Scene {
        Window("Wallps", id: WindowID.library) {
            LibraryWindow()
                .environment(state)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 980, height: 640)
        .commands {
            CommandGroup(replacing: .newItem) {}
        }

        MenuBarExtra("Wallps", systemImage: "photo.on.rectangle.angled") {
            MenuBarContent()
                .environment(state)
        }

        Settings {
            SettingsView()
                .environment(state)
        }
    }
}

enum WindowID {
    static let library = "library"
}

/// The app lives in the menu bar, so the wallpaper engine must start at launch
/// rather than when a window appears — a window may never appear at all.
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        AppState.shared.start()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    func applicationWillTerminate(_ notification: Notification) {
        AppState.shared.stop()
    }
}
