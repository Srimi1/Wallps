import SwiftUI
import UniformTypeIdentifiers

enum LibraryTab: String, CaseIterable, Identifiable {
    case gallery = "Explore Gallery"
    case myWallpapers = "My Wallpapers"

    var id: String { rawValue }
    var systemImage: String {
        switch self {
        case .gallery: return "sparkles"
        case .myWallpapers: return "square.grid.2x2.fill"
        }
    }
}

struct LibraryWindow: View {
    @Environment(AppState.self) private var state
    @State private var tab: LibraryTab = .gallery
    @Namespace private var navNamespace

    var body: some View {
        VStack(spacing: 0) {
            // MARK: - Futuristic Top Bar (Wallper.app Floating Style)
            HStack(spacing: 16) {
                // App Brand & Futuristic Badge
                HStack(spacing: 8) {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Theme.cyberCyan)
                    
                    Text("WALLPS")
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundStyle(Theme.ink)

                    TechBadge(text: "PRO", color: Theme.cyberCyan)
                }

                Spacer()

                // Floating Navigation Tabs Pill
                HStack(spacing: 4) {
                    ForEach(LibraryTab.allCases) { item in
                        let isSelected = tab == item
                        Button {
                            withAnimation(Theme.Motion.springStandard) {
                                tab = item
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: item.systemImage)
                                    .font(.system(size: 11, weight: .semibold))
                                Text(item.rawValue)
                                    .font(.system(size: 12, weight: isSelected ? .semibold : .medium))
                            }
                            .foregroundStyle(isSelected ? Theme.inkInverted : Theme.inkSecondary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .background {
                                if isSelected {
                                    Capsule()
                                        .fill(Color.white)
                                        .matchedGeometryEffect(id: "mainNavCapsule", in: navNamespace)
                                        .beamBorder(cornerRadius: Theme.Radius.pill, lineWidth: 1.0, isActive: true, glowIntensity: 0.7)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(4)
                .background(Theme.surface)
                .clipShape(Capsule())
                .overlay(Capsule().strokeBorder(Theme.hairline, lineWidth: Theme.hairlineWidth))

                Spacer()

                // Display Target Selector & Engine HUD
                HStack(spacing: 10) {
                    DisplayTargetPicker()

                    // Engine Status Dot
                    HStack(spacing: 5) {
                        Circle()
                            .fill(state.engine.hasActiveWallpaper ? Theme.neonEmerald : Theme.inkTertiary)
                            .frame(width: 6, height: 6)
                        Text(state.engine.hasActiveWallpaper ? "ACTIVE" : "IDLE")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundStyle(state.engine.hasActiveWallpaper ? Theme.neonEmerald : Theme.inkTertiary)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(Theme.surface)
                    .clipShape(Capsule())
                    .overlay(Capsule().strokeBorder(Theme.hairline, lineWidth: Theme.hairlineWidth))
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(Theme.backgroundSecondary.opacity(0.95))
            .overlay(alignment: .bottom) {
                Divider().background(Theme.hairline)
            }

            // MARK: - Main Tab Content
            Group {
                switch tab {
                case .gallery: GalleryView()
                case .myWallpapers: MyWallpapersView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Theme.background)
        .frame(minWidth: 920, minHeight: 600)
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

/// Futuristic Display Target Selector
struct DisplayTargetPicker: View {
    @Environment(AppState.self) private var state

    var body: some View {
        @Bindable var bindableState = state
        let displays = state.engine.connectedDisplays

        if displays.count > 1 {
            Menu {
                Button {
                    bindableState.assignmentTarget = .allDisplays
                } label: {
                    HStack {
                        Text("All Displays (\(displays.count))")
                        if bindableState.assignmentTarget == .allDisplays {
                            Image(systemName: "checkmark")
                        }
                    }
                }

                Divider()

                ForEach(displays) { display in
                    Button {
                        bindableState.assignmentTarget = .display(key: display.key)
                    } label: {
                        HStack {
                            Text(display.name)
                            if case .display(let key) = bindableState.assignmentTarget, key == display.key {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "display.2")
                        .font(.system(size: 11, weight: .semibold))
                    Text(displayTargetTitle(displays: displays))
                        .font(.system(size: 11, weight: .medium))
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 8))
                }
                .foregroundStyle(Theme.inkSecondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Theme.surface)
                .clipShape(Capsule())
                .overlay(Capsule().strokeBorder(Theme.hairline, lineWidth: Theme.hairlineWidth))
            }
            .menuStyle(.borderlessButton)
        }
    }

    private func displayTargetTitle(displays: [WallpaperEngine.Display]) -> String {
        switch state.assignmentTarget {
        case .allDisplays:
            return "All Displays"
        case .display(let key):
            return displays.first(where: { $0.key == key })?.name ?? "Display"
        }
    }
}

struct MyWallpapersView: View {
    @Environment(AppState.self) private var state
    @State private var isImporting = false
    @State private var isDropTargeted = false

    private let columns = [GridItem(.adaptive(minimum: 260, maximum: 360), spacing: 18)]

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            if state.library.items.isEmpty {
                EmptyLibraryView(isImporting: $isImporting)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // Section Header
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("My Wallpaper Library")
                                    .font(Font.heroTitle)
                                    .foregroundStyle(Theme.ink)
                                Text("\(state.library.items.count) imported live wallpapers stored locally")
                                    .font(Font.cardSubtitle)
                                    .foregroundStyle(Theme.inkSecondary)
                            }

                            Spacer()

                            Button {
                                isImporting = true
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "plus.circle.fill")
                                    Text("Add Video…")
                                }
                            }
                            .buttonStyle(FuturisticPrimaryButtonStyle())
                        }

                        // Grid
                        LazyVGrid(columns: columns, spacing: 18) {
                            ForEach(sortedItems) { item in
                                FuturisticWallpaperCard(item: item)
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 20)
                }
            }
        }
        .overlay {
            if isDropTargeted {
                ZStack {
                    Color.black.opacity(0.7)
                    VStack(spacing: 12) {
                        Image(systemName: "arrow.down.doc.fill")
                            .font(.system(size: 44))
                            .foregroundStyle(Theme.cyberCyan)
                        Text("Drop video to add to library")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(.white)
                    }
                    .padding(40)
                    .background(Theme.surfaceElevated)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .beamBorder(cornerRadius: 20, lineWidth: 2, isActive: true, glowIntensity: 1.0)
                }
                .allowsHitTesting(false)
            }
        }
        .dropDestination(for: URL.self) { urls, _ in
            let videos = urls.filter(Self.isVideo)
            guard !videos.isEmpty else { return false }
            state.importVideos(from: videos)
            return true
        } isTargeted: { isDropTargeted = $0 }
        .fileImporter(
            isPresented: $isImporting,
            allowedContentTypes: WallpaperLibrary.allowedContentTypes,
            allowsMultipleSelection: true
        ) { result in
            if case .success(let urls) = result {
                state.importVideos(from: urls)
            }
        }
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
        VStack(spacing: 16) {
            Image(systemName: "film.stack")
                .font(.system(size: 48))
                .foregroundStyle(Theme.cyberCyan.opacity(0.6))

            Text("No Personal Wallpapers Yet")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(Theme.ink)

            Text("Drop any 4K/HEVC video here, or explore the Gallery for ready-made live wallpapers.")
                .font(.system(size: 13))
                .foregroundStyle(Theme.inkSecondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 400)

            Button("Add Video from Mac…") {
                isImporting = true
            }
            .buttonStyle(FuturisticPrimaryButtonStyle())
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
    }
}

struct FuturisticWallpaperCard: View {
    @Environment(AppState.self) private var state
    let item: WallpaperItem
    @State private var isHovering = false

    private var isActive: Bool { state.engine.activeItemIDs.contains(item.id) }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack(alignment: .bottom) {
                ZStack(alignment: .topTrailing) {
                    ThumbnailImage(url: state.library.thumbnailURL(for: item))
                        .aspectRatio(16 / 9, contentMode: .fill)
                        .frame(maxWidth: .infinity)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card))

                    // Active Wallpaper Pill
                    if isActive {
                        HStack(spacing: 4) {
                            Circle().fill(Theme.neonEmerald).frame(width: 6, height: 6)
                            Text("ACTIVE DESKTOP")
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .foregroundStyle(Theme.neonEmerald)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.black.opacity(0.75))
                        .clipShape(Capsule())
                        .overlay(Capsule().strokeBorder(Theme.neonEmerald.opacity(0.6), lineWidth: 1))
                        .padding(8)
                    }

                    // Resolution Tag
                    HStack(spacing: 4) {
                        TechBadge(text: item.resolutionLabel, color: Theme.cyberCyan)
                    }
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                }

                // Hover Actions
                if isHovering {
                    HStack(spacing: 8) {
                        Button {
                            state.apply(item)
                        } label: {
                            HStack(spacing: 5) {
                                Image(systemName: "sparkles")
                                Text(isActive ? "Re-apply" : "Set Wallpaper")
                            }
                        }
                        .buttonStyle(FuturisticPrimaryButtonStyle())

                        if isActive {
                            Button {
                                state.clearWallpaper()
                            } label: {
                                Image(systemName: "xmark.circle")
                            }
                            .buttonStyle(FuturisticGhostButtonStyle())
                            .help("Remove from Desktop")
                        }
                    }
                    .padding(10)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card))
            .beamBorder(cornerRadius: Theme.Radius.card, lineWidth: 1.2, isActive: isActive || isHovering, glowIntensity: isActive ? 0.9 : 0.6)
            .shadow(color: isActive ? Theme.neonEmerald.opacity(0.2) : (isHovering ? Theme.cyberCyan.opacity(0.15) : Color.black.opacity(0.3)), radius: 14)
            .scaleEffect(isHovering ? 1.025 : 1.0)

            // Details
            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(Font.cardTitle)
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    Text(item.durationLabel)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(Theme.inkSecondary)
                    if let size = item.fileSizeLabel {
                        Text("·").foregroundStyle(Theme.inkQuaternary)
                        Text(size)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(Theme.inkTertiary)
                    }
                }
            }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.cardLg)
                .fill(isHovering ? Theme.surfaceHover : Theme.surface)
                .overlay(RoundedRectangle(cornerRadius: Theme.Radius.cardLg).strokeBorder(Theme.hairline, lineWidth: Theme.hairlineWidth))
        )
        .onHover { isHovering = $0 }
        .onTapGesture(count: 2) { state.apply(item) }
        .animation(Theme.Motion.springQuick, value: isHovering)
        .contextMenu {
            Button("Set as Desktop Wallpaper") { state.apply(item) }
            if isActive {
                Button("Remove from Desktop") { state.clearWallpaper() }
            }
            Button("Reveal in Finder") {
                NSWorkspace.shared.activateFileViewerSelecting([state.library.videoURL(for: item)])
            }
            Divider()
            Button("Delete from Library", role: .destructive) { state.delete(item) }
        }
    }
}

