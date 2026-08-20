import ServiceManagement
import SwiftUI

struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralSettings()
                .tabItem { Label("General", systemImage: "gearshape") }
            PlaybackSettings()
                .tabItem { Label("Playback", systemImage: "play.circle") }
            GallerySettings()
                .tabItem { Label("Gallery", systemImage: "sparkles") }
        }
        .frame(width: 460)
    }
}

struct GeneralSettings: View {
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var launchError: String?

    var body: some View {
        Form {
            Toggle("Launch Wallps at login", isOn: $launchAtLogin)
                .onChange(of: launchAtLogin) { _, enabled in
                    do {
                        if enabled {
                            try SMAppService.mainApp.register()
                        } else {
                            try SMAppService.mainApp.unregister()
                        }
                        launchError = nil
                    } catch {
                        launchError = error.localizedDescription
                        launchAtLogin = SMAppService.mainApp.status == .enabled
                    }
                }
            if let launchError {
                Text(launchError)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .formStyle(.grouped)
        .padding(.vertical)
    }
}

struct PlaybackSettings: View {
    @Environment(AppState.self) private var state

    var body: some View {
        @Bindable var prefs = state.prefs

        Form {
            Section("Video") {
                Picker("Scaling", selection: $prefs.gravity) {
                    ForEach(WallpaperGravity.allCases, id: \.self) { gravity in
                        Text(gravity.label).tag(gravity)
                    }
                }
                Toggle("Mute audio", isOn: $prefs.muted)
                if !prefs.muted {
                    Slider(value: $prefs.volume, in: 0...1) { Text("Volume") }
                }
            }

            Section("Battery & performance") {
                Toggle("Pause on battery power", isOn: $prefs.pauseOnBattery)
                Toggle("Pause in Low Power Mode", isOn: $prefs.pauseInLowPowerMode)
                Toggle("Pause when covered by a window", isOn: $prefs.pauseWhenHidden)
                Text("Pausing when the desktop isn't visible is the single biggest saving — the video stops decoding entirely.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}

struct GallerySettings: View {
    @Environment(AppState.self) private var state

    var body: some View {
        @Bindable var prefs = state.prefs

        Form {
            Section("Catalog source") {
                TextField("Catalog URL", text: $prefs.catalogURLString, axis: .vertical)
                    .lineLimit(2...4)
                HStack {
                    Button("Reload Gallery") { state.refreshCatalog() }
                    Spacer()
                    Button("Restore Default") {
                        prefs.catalogURLString = Preferences.defaultCatalogURL
                        state.refreshCatalog()
                    }
                }
                Text("Any JSON file in the Wallps catalog format works — host your own, or point at a community list.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Storage") {
                LabeledContent("Library folder") {
                    Button("Show in Finder") {
                        NSWorkspace.shared.activateFileViewerSelecting([state.library.rootURL])
                    }
                }
            }
        }
        .formStyle(.grouped)
    }
}
