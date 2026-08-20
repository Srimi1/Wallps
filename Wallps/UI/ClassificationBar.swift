import SwiftUI

/// iOS 26 Multi-Dimensional Classification & Filter Matrix.
struct ClassificationBar: View {
    @Binding var selectedCategory: String?
    @Binding var selectedMood: String?
    @Binding var selectedResolution: String?
    @Binding var selectedSort: FilterSortOption
    @Binding var searchQuery: String
    @Binding var gridLayout: GridLayoutMode
    let totalCount: Int
    let categories: [String]
    let moods: [String]

    @State private var isFilterMatrixExpanded = false
    @Namespace private var categoryNamespace

    private let primaryCategories = [
        "All", "Cyberpunk", "Nature", "Anime", "Minimalist", "Gaming", "Cars", "Sci-Fi", "Rain & Atmosphere"
    ]

    var body: some View {
        VStack(spacing: 12) {
            // MARK: - Row 1: Search Bar, Category Track & View Mode Switcher
            HStack(spacing: 12) {
                // Search Field
                FuturisticSearchField(
                    placeholder: "Search 4K live wallpapers, tags…",
                    text: $searchQuery
                )
                .frame(width: 240)

                // Category Pills Track (Scrollable with smooth iOS 26 spring)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(primaryCategories, id: \.self) { cat in
                            let isSelected = (cat == "All" && selectedCategory == nil) || (selectedCategory == cat)
                            CategoryPill(
                                title: cat,
                                isSelected: isSelected,
                                namespace: categoryNamespace
                            ) {
                                withAnimation(Theme.Motion.springStandard) {
                                    selectedCategory = (cat == "All") ? nil : cat
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 2)
                    .padding(.vertical, 4)
                }

                Spacer(minLength: 8)

                // Filter Matrix Toggle & Grid Mode Switcher
                HStack(spacing: 8) {
                    // Filter Matrix Trigger
                    Button {
                        withAnimation(Theme.Motion.springStandard) {
                            isFilterMatrixExpanded.toggle()
                        }
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "slider.horizontal.3")
                                .font(.system(size: 11, weight: .semibold))
                            Text("Filters")
                                .font(.system(size: 12, weight: .medium))
                            if hasActiveSubFilters {
                                Circle()
                                    .fill(Theme.cyberCyan)
                                    .frame(width: 6, height: 6)
                            }
                        }
                        .foregroundStyle(isFilterMatrixExpanded || hasActiveSubFilters ? Theme.cyberCyan : Theme.inkSecondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(isFilterMatrixExpanded ? Theme.surfaceActive : Theme.surface)
                        )
                        .overlay {
                            Capsule()
                                .strokeBorder(
                                    isFilterMatrixExpanded ? Theme.cyberCyan.opacity(0.4) : Theme.hairline,
                                    lineWidth: Theme.hairlineWidth
                                )
                        }
                    }
                    .buttonStyle(.plain)

                    // Grid Layout Switcher
                    HStack(spacing: 2) {
                        GridModeButton(icon: "rectangle.grid.2x2", mode: .cinema, current: $gridLayout)
                        GridModeButton(icon: "square.grid.3x3", mode: .comfortable, current: $gridLayout)
                        GridModeButton(icon: "square.grid.4x3.fill", mode: .compact, current: $gridLayout)
                    }
                    .padding(3)
                    .background(Theme.surface)
                    .clipShape(Capsule())
                    .overlay(Capsule().strokeBorder(Theme.hairline, lineWidth: Theme.hairlineWidth))
                }
            }

            // MARK: - Row 2: Expandable iOS 26 Multi-Dimensional Matrix
            if isFilterMatrixExpanded {
                VStack(alignment: .leading, spacing: 14) {
                    Divider().background(Theme.hairline)

                    HStack(alignment: .top, spacing: 24) {
                        // Dimension 1: Mood & Atmosphere
                        FilterDimensionColumn(
                            title: "ATMOSPHERE & MOOD",
                            icon: "sparkles"
                        ) {
                            FilterOptionPill(
                                label: "All Moods",
                                isSelected: selectedMood == nil
                            ) { selectedMood = nil }

                            ForEach(["Neon Glow", "Obsidian Dark", "Misty Rain", "Chill Lofi", "Ethereal Sunset", "Cosmic Void", "Solar Gold"], id: \.self) { mood in
                                FilterOptionPill(
                                    label: mood,
                                    isSelected: selectedMood == mood
                                ) {
                                    selectedMood = (selectedMood == mood) ? nil : mood
                                }
                            }
                        }

                        // Dimension 2: Resolution & Display Target
                        FilterDimensionColumn(
                            title: "DISPLAY & SPECS",
                            icon: "display"
                        ) {
                            FilterOptionPill(
                                label: "All Specs",
                                isSelected: selectedResolution == nil
                            ) { selectedResolution = nil }

                            ForEach(["8K Ultra", "4K XDR", "4K UHD"], id: \.self) { res in
                                FilterOptionPill(
                                    label: res,
                                    isSelected: selectedResolution == res
                                ) {
                                    selectedResolution = (selectedResolution == res) ? nil : res
                                }
                            }
                        }

                        // Dimension 3: Sort Ordering
                        FilterDimensionColumn(
                            title: "SORT & FLOW",
                            icon: "arrow.up.arrow.down"
                        ) {
                            ForEach(FilterSortOption.allCases, id: \.self) { opt in
                                FilterOptionPill(
                                    label: opt.rawValue,
                                    isSelected: selectedSort == opt
                                ) {
                                    selectedSort = opt
                                }
                            }
                        }
                    }

                    // Reset & Status Bar
                    HStack {
                        Text("\(totalCount) live wallpapers match current classification")
                            .font(.system(size: 11, weight: .regular))
                            .foregroundStyle(Theme.inkTertiary)

                        Spacer()

                        if hasActiveSubFilters || selectedCategory != nil || !searchQuery.isEmpty {
                            Button("Reset Filters") {
                                withAnimation(Theme.Motion.springQuick) {
                                    selectedCategory = nil
                                    selectedMood = nil
                                    selectedResolution = nil
                                    selectedSort = .trending
                                    searchQuery = ""
                                }
                            }
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(Theme.cyberCyan)
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                        .fill(Theme.surfaceElevated)
                        .overlay(
                            RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                                .strokeBorder(Theme.hairlineStrong, lineWidth: Theme.hairlineWidth)
                        )
                )
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .scale(scale: 0.98, anchor: .top)),
                    removal: .opacity.combined(with: .scale(scale: 0.98, anchor: .top))
                ))
            }

            // MARK: - Active Filter Tags Bar (if any subfilters active)
            if hasActiveSubFilters || !searchQuery.isEmpty {
                HStack(spacing: 8) {
                    Text("ACTIVE:")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(Theme.inkTertiary)

                    if let cat = selectedCategory {
                        ActiveTokenPill(title: cat) { selectedCategory = nil }
                    }
                    if let mood = selectedMood {
                        ActiveTokenPill(title: mood) { selectedMood = nil }
                    }
                    if let res = selectedResolution {
                        ActiveTokenPill(title: res) { selectedResolution = nil }
                    }
                    if !searchQuery.isEmpty {
                        ActiveTokenPill(title: "\"\(searchQuery)\"") { searchQuery = "" }
                    }

                    Spacer()
                }
                .padding(.top, 2)
            }
        }
    }

    private var hasActiveSubFilters: Bool {
        selectedMood != nil || selectedResolution != nil || selectedSort != .trending
    }
}

// MARK: - Subcomponents

enum GridLayoutMode {
    case cinema
    case comfortable
    case compact

    var minColumnWidth: CGFloat {
        switch self {
        case .cinema: return 380
        case .comfortable: return 270
        case .compact: return 200
        }
    }
}

enum FilterSortOption: String, CaseIterable, Sendable {
    case trending = "Trending"
    case newest = "Newest Drops"
    case resolution = "Highest Resolution"
}

struct CategoryPill: View {
    let title: String
    let isSelected: Bool
    var namespace: Namespace.ID
    let action: () -> Void
    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            ZStack {
                if isSelected {
                    Capsule()
                        .fill(Color.white)
                        .matchedGeometryEffect(id: "activeCategoryCapsule", in: namespace)
                        .beamBorder(cornerRadius: Theme.Radius.pill, lineWidth: 1.0, isActive: true, glowIntensity: 0.8)
                } else {
                    Capsule()
                        .fill(isHovering ? Theme.surfaceHover : Theme.surface)
                        .overlay(Capsule().strokeBorder(Theme.hairline, lineWidth: Theme.hairlineWidth))
                }

                Text(title)
                    .font(.system(size: 12, weight: isSelected ? .semibold : .medium))
                    .foregroundStyle(isSelected ? Theme.inkInverted : Theme.ink)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
            }
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
        .scaleEffect(isHovering && !isSelected ? 1.03 : 1.0)
        .animation(Theme.Motion.springQuick, value: isHovering)
    }
}

struct FilterDimensionColumn<Content: View>: View {
    let title: String
    let icon: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 9, weight: .bold))
                Text(title)
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
            }
            .foregroundStyle(Theme.inkTertiary)

            FlowLayout(spacing: 6) {
                content()
            }
        }
    }
}

struct FilterOptionPill: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void
    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 11, weight: isSelected ? .semibold : .regular))
                .foregroundStyle(isSelected ? Theme.cyberCyan : Theme.inkSecondary)
                .padding(.horizontal, 9)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(isSelected ? Theme.cyberCyan.opacity(0.15) : (isHovering ? Theme.surfaceHover : Theme.surface))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .strokeBorder(isSelected ? Theme.cyberCyan.opacity(0.4) : Theme.hairline, lineWidth: Theme.hairlineWidth)
                )
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
    }
}

struct ActiveTokenPill: View {
    let title: String
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            Text(title)
                .font(.system(size: 11, weight: .medium))
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .bold))
            }
            .buttonStyle(.plain)
        }
        .foregroundStyle(Theme.cyberCyan)
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(Theme.cyberCyan.opacity(0.12))
        .clipShape(Capsule())
        .overlay(Capsule().strokeBorder(Theme.cyberCyan.opacity(0.3), lineWidth: 0.5))
    }
}

struct GridModeButton: View {
    let icon: String
    let mode: GridLayoutMode
    @Binding var current: GridLayoutMode

    var isSelected: Bool { current == mode }

    var body: some View {
        Button {
            withAnimation(Theme.Motion.springQuick) { current = mode }
        } label: {
            Image(systemName: icon)
                .font(.system(size: 11, weight: isSelected ? .bold : .regular))
                .foregroundStyle(isSelected ? Theme.ink : Theme.inkTertiary)
                .frame(width: 24, height: 22)
                .background(isSelected ? Theme.surfaceActive : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
    }
}

/// Simple flow layout helper for wrapping filter chips horizontally.
struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 300
        var height: CGFloat = 0
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var maxHeightInRow: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentX + size.width > width && currentX > 0 {
                currentX = 0
                currentY += maxHeightInRow + spacing
                maxHeightInRow = 0
            }
            maxHeightInRow = max(maxHeightInRow, size.height)
            currentX += size.width + spacing
        }
        height = currentY + maxHeightInRow
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var currentX = bounds.minX
        var currentY = bounds.minY
        var maxHeightInRow: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentX + size.width > bounds.maxX && currentX > bounds.minX {
                currentX = bounds.minX
                currentY += maxHeightInRow + spacing
                maxHeightInRow = 0
            }
            subview.place(at: CGPoint(x: currentX, y: currentY), proposal: ProposedViewSize(size))
            maxHeightInRow = max(maxHeightInRow, size.height)
            currentX += size.width + spacing
        }
    }
}
