import SwiftUI

/// Futuristic Live Wallpaper Catalog inspired by Wallper.app & iOS 26.
struct GalleryView: View {
    @Environment(AppState.self) private var state
    @State private var search = ""
    @State private var category: String?
    @State private var mood: String?
    @State private var resolution: String?
    @State private var sortOption: FilterSortOption = .trending
    @State private var gridLayout: GridLayoutMode = .comfortable
    @State private var inspectedEntry: CatalogEntry?

    private var columns: [GridItem] {
        [GridItem(.adaptive(minimum: gridLayout.minColumnWidth, maximum: gridLayout.minColumnWidth * 1.5), spacing: 18)]
    }

    var body: some View {
        ZStack {
            // Dark Background Canvas
            Theme.background.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // MARK: - Hero Header (Wallper.app Aesthetic)
                    HeroHeaderView(totalWallpapers: filteredEntries.count)

                    // MARK: - iOS 26 Multi-Dimensional Classification & Filter Matrix
                    ClassificationBar(
                        selectedCategory: $category,
                        selectedMood: $mood,
                        selectedResolution: $resolution,
                        selectedSort: $sortOption,
                        searchQuery: $search,
                        gridLayout: $gridLayout,
                        totalCount: filteredEntries.count,
                        categories: state.catalog.categories,
                        moods: state.catalog.availableMoods
                    )

                    // MARK: - Wallpapers Grid
                    if filteredEntries.isEmpty {
                        EmptySearchResultsView(query: search) {
                            category = nil
                            mood = nil
                            resolution = nil
                            search = ""
                        }
                        .frame(minHeight: 300)
                    } else {
                        LazyVGrid(columns: columns, spacing: 20) {
                            ForEach(filteredEntries) { entry in
                                FuturisticCatalogCard(
                                    entry: entry,
                                    onInspect: { inspectedEntry = entry }
                                )
                            }
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 20)
            }

            // MARK: - Wallpaper Inspector Modal
            if let inspectedEntry {
                WallpaperInspectorView(entry: inspectedEntry) {
                    self.inspectedEntry = nil
                }
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }
        }
        .animation(Theme.Motion.springStandard, value: inspectedEntry == nil)
        .task {
            if case .idle = state.catalog.state { state.refreshCatalog() }
        }
    }

    private var filteredEntries: [CatalogEntry] {
        var list = state.catalog.entries.filter { entry in
            // Category filter
            if let category, entry.category != category { return false }
            // Mood filter
            if let mood, entry.mood != mood { return false }
            // Resolution filter
            if let resolution, entry.displayResolution != resolution { return false }
            // Search query
            if !search.isEmpty {
                let q = search.localizedLowercase
                let titleMatch = entry.title.localizedLowercase.contains(q)
                let catMatch = entry.category?.localizedLowercase.contains(q) ?? false
                let tagMatch = entry.tags?.contains(where: { $0.localizedLowercase.contains(q) }) ?? false
                let creditMatch = entry.credit?.localizedLowercase.contains(q) ?? false
                if !titleMatch && !catMatch && !tagMatch && !creditMatch {
                    return false
                }
            }
            return true
        }

        switch sortOption {
        case .trending:
            list.sort { ($0.isFeatured ?? false) && !($1.isFeatured ?? false) }
        case .newest:
            list.sort { $0.id > $1.id }
        case .resolution:
            list.sort { $0.displayResolution > $1.displayResolution }
        }

        return list
    }
}

// MARK: - Hero Header

struct HeroHeaderView: View {
    let totalWallpapers: Int

    var body: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text("LIVE 4K GALLERY")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundStyle(Theme.cyberCyan)

                    // Futuristic animated badge
                    HStack(spacing: 4) {
                        Circle().fill(Theme.neonEmerald).frame(width: 6, height: 6)
                        Text("macOS 26 READY")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundStyle(Theme.neonEmerald)
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Theme.neonEmerald.opacity(0.12))
                    .clipShape(Capsule())
                }

                Text("Curated 4K Live Wallpapers")
                    .font(Font.heroTitle)
                    .foregroundStyle(Theme.ink)

                Text("Ultra-high definition video backgrounds optimized for Apple Silicon, Studio Display & Pro Display XDR.")
                    .font(Font.cardSubtitle)
                    .foregroundStyle(Theme.inkSecondary)
                    .frame(maxWidth: 580, alignment: .leading)
            }

            Spacer()

            // Quick Stats Counter HUD
            VStack(alignment: .trailing, spacing: 4) {
                Text("\(totalWallpapers)")
                    .font(.system(size: 28, weight: .bold, design: .monospaced))
                    .foregroundStyle(Theme.ink)
                Text("CURATED ASSETS")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(Theme.inkTertiary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Theme.surfaceElevated)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                    .strokeBorder(Theme.hairline, lineWidth: Theme.hairlineWidth)
            )
        }
        .padding(.bottom, 6)
    }
}

// MARK: - Futuristic Catalog Card

struct FuturisticCatalogCard: View {
    @Environment(AppState.self) private var state
    let entry: CatalogEntry
    let onInspect: () -> Void

    @State private var isHovering = false
    @State private var isApplying = false

    private var isDownloading: Bool { state.catalog.isDownloading(entry) }
    private var isDownloaded: Bool { state.library.containsCatalogItem(id: entry.id) }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Artwork Container with 16:9 Aspect Ratio
            ZStack(alignment: .bottom) {
                ZStack(alignment: .topTrailing) {
                    // Async Preview Artwork
                    AsyncImage(url: entry.preview) { phase in
                        switch phase {
                        case .success(let image):
                            image.resizable()
                                .aspectRatio(contentMode: .fill)
                                .transition(.opacity)
                        case .failure:
                            Rectangle().fill(Theme.mediaWell)
                                .overlay(Image(systemName: "photo").foregroundStyle(Theme.inkTertiary))
                        default:
                            FuturisticShimmer()
                        }
                    }

                    // Tech Badges Overlay (Top Right)
                    HStack(spacing: 4) {
                        TechBadge(text: entry.displayResolution, color: Theme.cyberCyan)
                        TechBadge(text: entry.displayFPS, color: Theme.neonEmerald)
                    }
                    .padding(8)

                    // Download Progress Overlay
                    if isDownloading {
                        Color.black.opacity(0.6)
                        VStack(spacing: 8) {
                            ProgressView().tint(.white)
                            Text("Downloading 4K…")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(.white)
                        }
                    }
                }
                .aspectRatio(16 / 9, contentMode: .fill)
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))

                // Hover Actions Overlay (Bottom)
                if isHovering && !isDownloading {
                    HStack(spacing: 8) {
                        // Quick Apply Button
                        Button {
                            state.download(entry)
                        } label: {
                            HStack(spacing: 5) {
                                Image(systemName: isDownloaded ? "checkmark.circle.fill" : "sparkles")
                                    .font(.system(size: 11, weight: .bold))
                                Text(isDownloaded ? "In Library" : "Set Wallpaper")
                                    .font(.system(size: 11, weight: .semibold))
                            }
                        }
                        .buttonStyle(FuturisticPrimaryButtonStyle())
                        .disabled(isDownloading)

                        // Quick Inspect / Simulator Button
                        Button(action: onInspect) {
                            Image(systemName: "eye.fill")
                                .font(.system(size: 11, weight: .semibold))
                                .padding(8)
                        }
                        .buttonStyle(FuturisticGhostButtonStyle())
                        .help("Inspect & Desktop Simulator")
                    }
                    .padding(.horizontal, 10)
                    .padding(.bottom, 10)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
            .beamBorder(cornerRadius: Theme.Radius.card, lineWidth: 1.2, isActive: isHovering, glowIntensity: 0.8)
            .shadow(color: isHovering ? Theme.cyberCyan.opacity(0.18) : Color.black.opacity(0.3), radius: isHovering ? 18 : 6, x: 0, y: isHovering ? 6 : 2)
            .scaleEffect(isHovering ? 1.025 : 1.0)

            // Card Metadata Footer
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(entry.title)
                        .font(Font.cardTitle)
                        .foregroundStyle(Theme.ink)
                        .lineLimit(1)

                    Spacer()

                    if let mood = entry.mood {
                        Text(mood)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(Theme.inkTertiary)
                    }
                }

                HStack(spacing: 6) {
                    if let cat = entry.category {
                        Text(cat)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(Theme.inkSecondary)
                    }
                    Text("·").foregroundStyle(Theme.inkQuaternary)
                    Text(entry.formattedBytes)
                        .font(.system(size: 11, weight: .regular, design: .monospaced))
                        .foregroundStyle(Theme.inkTertiary)

                    if let credit = entry.credit {
                        Text("·").foregroundStyle(Theme.inkQuaternary)
                        Text(credit)
                            .font(.system(size: 11, weight: .regular))
                            .foregroundStyle(Theme.inkTertiary)
                            .lineLimit(1)
                    }
                }
            }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.cardLg, style: .continuous)
                .fill(isHovering ? Theme.surfaceHover : Theme.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Radius.cardLg, style: .continuous)
                        .strokeBorder(isHovering ? Theme.hairlineStrong : Theme.hairline, lineWidth: Theme.hairlineWidth)
                )
        )
        .onHover { isHovering = $0 }
        .onTapGesture(count: 2) { onInspect() }
        .animation(Theme.Motion.springQuick, value: isHovering)
        .contextMenu {
            Button("Inspect in Cinema HUD") { onInspect() }
            Button(isDownloaded ? "Apply to Desktop" : "Download & Apply") { state.download(entry) }
            Divider()
            if let credit = entry.credit {
                Text("Credit: \(credit)")
            }
        }
    }
}

// MARK: - Empty State

struct EmptySearchResultsView: View {
    let query: String
    let onReset: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "sparkle.magnifyingglass")
                .font(.system(size: 40))
                .foregroundStyle(Theme.cyberCyan.opacity(0.7))

            Text("No wallpapers found")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Theme.ink)

            Text("Try searching for different keywords, or reset active classifications.")
                .font(.system(size: 13))
                .foregroundStyle(Theme.inkSecondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 360)

            Button("Reset All Filters", action: onReset)
                .buttonStyle(FuturisticPrimaryButtonStyle())
                .padding(.top, 6)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
    }
}
