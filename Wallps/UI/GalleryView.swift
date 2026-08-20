import SwiftUI

/// Browses a remote catalog of downloadable wallpapers.
struct GalleryView: View {
    @Environment(AppState.self) private var state
    @State private var search = ""
    @State private var category: String?

    private let columns = [GridItem(.adaptive(minimum: 220, maximum: 320), spacing: 16)]

    var body: some View {
        Group {
            switch state.catalog.state {
            case .idle, .loading:
                ProgressView("Loading gallery…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .failed(let message):
                ContentUnavailableView {
                    Label("Gallery Unavailable", systemImage: "wifi.exclamationmark")
                } description: {
                    Text(message)
                } actions: {
                    Button("Try Again") { state.refreshCatalog() }
                }
            case .loaded(let entries):
                let visible = filter(entries)
                if visible.isEmpty {
                    ContentUnavailableView.search(text: search)
                } else {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 16) {
                            ForEach(visible) { entry in
                                CatalogCard(entry: entry)
                            }
                        }
                        .padding(20)
                    }
                }
            }
        }
        .searchable(text: $search, prompt: "Search wallpapers")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Picker("Category", selection: $category) {
                    Text("All").tag(String?.none)
                    ForEach(state.catalog.categories, id: \.self) { name in
                        Text(name).tag(String?.some(name))
                    }
                }
                .pickerStyle(.menu)
            }
        }
        .navigationTitle("Gallery")
        .task {
            if case .idle = state.catalog.state { state.refreshCatalog() }
        }
    }

    private func filter(_ entries: [CatalogEntry]) -> [CatalogEntry] {
        entries.filter { entry in
            let matchesCategory = category == nil || entry.category == category
            let matchesSearch = search.isEmpty
                || entry.title.localizedCaseInsensitiveContains(search)
                || (entry.category ?? "").localizedCaseInsensitiveContains(search)
            return matchesCategory && matchesSearch
        }
    }
}

struct CatalogCard: View {
    @Environment(AppState.self) private var state
    let entry: CatalogEntry

    private var isDownloading: Bool { state.catalog.isDownloading(entry) }
    private var isDownloaded: Bool { state.library.containsCatalogItem(id: entry.id) }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack {
                AsyncImage(url: entry.preview) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().aspectRatio(contentMode: .fill)
                    case .failure:
                        Rectangle().fill(.quaternary)
                            .overlay(Image(systemName: "photo").foregroundStyle(.secondary))
                    default:
                        Rectangle().fill(.quaternary)
                            .overlay(ProgressView().controlSize(.small))
                    }
                }
                if isDownloading {
                    Color.black.opacity(0.4)
                    ProgressView().controlSize(.small).tint(.white)
                }
            }
            .aspectRatio(16 / 9, contentMode: .fill)
            .frame(maxWidth: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: 10))

            Text(entry.title)
                .font(.callout.weight(.medium))
                .lineLimit(1)

            HStack {
                Text([entry.category, entry.resolution].compactMap { $0 }.joined(separator: " · "))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button(isDownloaded ? "In Library" : "Download") {
                    state.download(entry)
                }
                .controlSize(.small)
                .disabled(isDownloading || isDownloaded)
            }
        }
        .help(entry.credit.map { "Credit: \($0)" } ?? entry.title)
    }
}
