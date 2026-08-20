import SwiftUI
import UniformTypeIdentifiers

enum LibraryTab: String, CaseIterable, Identifiable {
    case myWallpapers = "My Wallpapers"
    case gallery = "Gallery"

    var id: String { rawValue }
    var systemImage: String {
        switch self {
        case .myWallpapers: return "square.grid.2x2"
        case .gallery: return "sparkles"
        }
    }
}

struct LibraryWindow: View {
    @Environment(AppState.self) private var state
    @State private var tab: LibraryTab = .myWallpapers

    var body: some View {
        NavigationSplitView {
            List(selection: $tab) {
                Section("Library") {
                    ForEach(LibraryTab.allCases) { tab in
                        Label(tab.rawValue, systemImage: tab.systemImage).tag(tab)
                    }
                }
            }
            .navigationSplitViewColumnWidth(min: 180, ideal: 200, max: 240)
        } detail: {
            Group {
                switch tab {
                case .myWallpapers: MyWallpapersView()
                case .gallery: GalleryView()
                }
            }
            .toolbar {
                ToolbarItem(placement: .principal) {
                    DisplayTargetPicker()
                }
            }
        }
        .frame(minWidth: 760, minHeight: 480)
        .alert(
            "Something went wrong",
            isPresented: Binding(
                get: { state.errorMessage != nil },
                set: { if !$0 { state.errorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) { state.errorMessage = nil }
        } message: {
            Text(state.errorMessage ?? "")
        }
    }
}

/// Chooses whether library actions apply to every display or just one.
struct DisplayTargetPicker: View {
    @Environment(AppState.self) private var state

    var body: some View {
        @Bindable var bindableState = state
        let displays = state.engine.connectedDisplays

        if displays.count > 1 {
            Picker("Apply to", selection: $bindableState.assignmentTarget) {
                Text("All Displays").tag(AssignmentTarget.allDisplays)
                ForEach(displays) { display in
                    Text(display.name).tag(AssignmentTarget.display(key: display.key))
                }
            }
            .pickerStyle(.menu)
            .frame(maxWidth: 260)
        }
    }
}

struct MyWallpapersView: View {
    @Environment(AppState.self) private var state
    @State private var isImporting = false
    @State private var isDropTargeted = false

    private let columns = [GridItem(.adaptive(minimum: 220, maximum: 320), spacing: 16)]

    var body: some View {
        Group {
            if state.library.items.isEmpty {
                EmptyLibraryView(isImporting: $isImporting)
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(sortedItems) { item in
                            WallpaperCard(item: item)
                        }
                    }
                    .padding(20)
                }
            }
        }
        .background(isDropTargeted ? Color.accentColor.opacity(0.12) : Color.clear)
        .dropDestination(for: URL.self) { urls, _ in
            let videos = urls.filter(Self.isVideo)
            guard !videos.isEmpty else { return false }
            state.importVideos(from: videos)
            return true
        } isTargeted: { isDropTargeted = $0 }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    isImporting = true
                } label: {
                    Label("Add Video", systemImage: "plus")
                }
            }
        }
        .fileImporter(
            isPresented: $isImporting,
            allowedContentTypes: WallpaperLibrary.allowedContentTypes,
            allowsMultipleSelection: true
        ) { result in
            if case .success(let urls) = result {
                state.importVideos(from: urls)
            }
        }
        .navigationTitle("My Wallpapers")
    }

    private var sortedItems: [WallpaperItem] {
        state.library.items.sorted { $0.dateAdded > $1.dateAdded }
    }

    static func isVideo(_ url: URL) -> Bool {
        guard let type = UTType(filenameExtension: url.pathExtension) else { return false }
        return type.conforms(to: .movie) || type.conforms(to: .video)
    }
}

struct EmptyLibraryView: View {
    @Binding var isImporting: Bool

    var body: some View {
        ContentUnavailableView {
            Label("No Wallpapers Yet", systemImage: "film.stack")
        } description: {
            Text("Drop a video here, or browse the Gallery for ready-made live wallpapers.")
        } actions: {
            Button("Add Video…") { isImporting = true }
                .buttonStyle(.borderedProminent)
        }
    }
}

struct WallpaperCard: View {
    @Environment(AppState.self) private var state
    let item: WallpaperItem
    @State private var isHovering = false

    private var isActive: Bool { state.engine.activeItemIDs.contains(item.id) }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .topTrailing) {
                ThumbnailImage(url: state.library.thumbnailURL(for: item))
                    .aspectRatio(16 / 9, contentMode: .fill)
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay {
                        RoundedRectangle(cornerRadius: 10)
                            .strokeBorder(isActive ? Color.accentColor : Color.clear, lineWidth: 3)
                    }

                if isActive {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.white, Color.accentColor)
                        .font(.title3)
                        .padding(8)
                }

                if isHovering {
                    Button("Set Wallpaper") { state.apply(item) }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                        .padding(8)
                        .offset(y: 30)
                }
            }

            Text(item.title)
                .font(.callout.weight(.medium))
                .lineLimit(1)
            Text("\(item.resolutionLabel) · \(item.durationLabel)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .onHover { isHovering = $0 }
        .onTapGesture(count: 2) { state.apply(item) }
        .contextMenu {
            Button("Set Wallpaper") { state.apply(item) }
            if isActive {
                Button("Remove From Desktop") { state.clearWallpaper() }
            }
            Button("Show in Finder") {
                NSWorkspace.shared.activateFileViewerSelecting([state.library.videoURL(for: item)])
            }
            Divider()
            Button("Delete", role: .destructive) { state.delete(item) }
        }
    }
}
