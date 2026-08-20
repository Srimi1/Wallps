import SwiftUI

struct MenuBarContent: View {
    @Environment(AppState.self) private var state
    @Environment(\.openWindow) private var openWindow
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        @Bindable var engine = state.engine

        Text(state.engine.statusDescription)

        if let reason = state.engine.pauseReason {
            Text(reason)
                .font(.caption)
        }

        Divider()

        Toggle("Pause Playback", isOn: $engine.userPaused)
            .keyboardShortcut("p")

        Button("Open Library…") {
            NSApp.activate(ignoringOtherApps: true)
            openWindow(id: WindowID.library)
        }
        .keyboardShortcut("l")

        if !recentItems.isEmpty {
            Divider()
            ForEach(recentItems) { item in
                Button {
                    state.apply(item)
                } label: {
                    if state.engine.activeItemIDs.contains(item.id) {
                        Label(item.title, systemImage: "checkmark")
                    } else {
                        Text(item.title)
                    }
                }
            }
        }

        Divider()

        // Not SettingsLink: this app is an accessory with no Dock icon, so the
        // settings window opens behind everything unless the app is activated
        // first.
        Button("Settings…") {
            NSApp.activate(ignoringOtherApps: true)
            openSettings()
        }
        .keyboardShortcut(",")

        Button("Quit Wallps") {
            NSApp.terminate(nil)
        }
        .keyboardShortcut("q")
    }

    private var recentItems: [WallpaperItem] {
        Array(state.library.items.sorted { $0.dateAdded > $1.dateAdded }.prefix(5))
    }
}
