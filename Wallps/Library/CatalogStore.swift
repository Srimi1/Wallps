import Foundation
import Observation

/// One downloadable wallpaper in a catalog.
struct CatalogEntry: Codable, Identifiable, Hashable, Sendable {
    var id: String
    var title: String
    var category: String?
    var preview: URL
    var video: URL
    var resolution: String?
    var credit: String?
    var license: String?
    var bytes: Int64?
    var tags: [String]?
    var mood: String?
    var fps: Int?
    var isFeatured: Bool?
    var aspect: String?
    var colorHex: String?

    var displayResolution: String {
        resolution ?? "4K"
    }

    var displayFPS: String {
        if let fps { return "\(fps) FPS" }
        return "60 FPS"
    }

    var displayMood: String {
        mood ?? "Atmospheric"
    }

    var formattedBytes: String {
        guard let bytes, bytes > 0 else { return "45 MB" }
        return ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }
}

/// Remote catalog manifest — a plain JSON file anyone can host.
struct Catalog: Codable, Sendable {
    var version: Int
    var wallpapers: [CatalogEntry]
}

/// Fetches a community catalog and downloads entries into the local library.
@MainActor
@Observable
final class CatalogStore {
    enum State {
        case idle
        case loading
        case loaded([CatalogEntry])
        case failed(String)
    }

    private(set) var state: State = .idle
    /// Catalog entry ID → download progress, 0...1.
    private(set) var progress: [String: Double] = [:]
    var lastError: String?

    var entries: [CatalogEntry] {
        if case .loaded(let items) = state { return items }
        return Self.curatedCatalog
    }

    var categories: [String] {
        let allCats = entries.compactMap(\.category)
        return Array(Set(allCats)).sorted()
    }

    var availableMoods: [String] {
        let allMoods = entries.compactMap(\.mood)
        return Array(Set(allMoods)).sorted()
    }

    func refresh(from urlString: String) async {
        guard let url = URL(string: urlString), url.scheme == "https" || url.scheme == "http" else {
            // Fallback to built-in curated catalog
            state = .loaded(Self.curatedCatalog)
            return
        }
        state = .loading
        do {
            var request = URLRequest(url: url)
            request.cachePolicy = .reloadRevalidatingCacheData
            request.timeoutInterval = 10
            let (data, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) {
                let catalog = try JSONDecoder().decode(Catalog.self, from: data)
                if !catalog.wallpapers.isEmpty {
                    state = .loaded(catalog.wallpapers)
                    return
                }
            }
            state = .loaded(Self.curatedCatalog)
        } catch {
            // Seamlessly fall back to rich built-in catalog so user always has wallpapers
            state = .loaded(Self.curatedCatalog)
        }
    }

    func isDownloading(_ entry: CatalogEntry) -> Bool {
        progress[entry.id] != nil
    }

    /// Downloads a catalog entry and imports it into the library.
    @discardableResult
    func download(_ entry: CatalogEntry, into library: WallpaperLibrary) async -> WallpaperItem? {
        if let existing = library.items.first(where: { $0.catalogID == entry.id }) {
            return existing
        }
        guard progress[entry.id] == nil else { return nil }
        progress[entry.id] = 0.1
        defer { progress[entry.id] = nil }

        do {
            let (tempURL, response) = try await URLSession.shared.download(from: entry.video)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                throw WallpsError.downloadFailed(entry.title)
            }
            progress[entry.id] = 0.8
            let ext = entry.video.pathExtension.isEmpty ? "mp4" : entry.video.pathExtension
            let renamed = tempURL.deletingLastPathComponent()
                .appendingPathComponent("\(UUID().uuidString).\(ext)")
            try FileManager.default.moveItem(at: tempURL, to: renamed)

            let item = try await library.importVideo(
                from: renamed,
                title: entry.title,
                source: .remote,
                removeOriginal: true,
                catalogID: entry.id,
                credit: entry.credit,
                license: entry.license
            )
            progress[entry.id] = 1.0
            return item
        } catch {
            lastError = error.localizedDescription
            return nil
        }
    }

    // MARK: - Built-in catalog
    //
    // Mirrors `docs/catalog.json` — the same ten wallpapers the official catalog serves, so a
    // failed or unreachable network fetch shows the user exactly what a successful one would.
    // Every asset is our own: CC0-1.0, credited to Wallps, previews on GitHub Pages and video
    // on GitHub Releases. Nothing here reaches a third-party CDN.
    //
    // Generated from docs/catalog.json. When that file changes, regenerate rather than
    // hand-editing, so the two cannot drift.
    static let curatedCatalog: [CatalogEntry] = [
        CatalogEntry(
            id: "wallps-seed-obsidian-drift",
            title: "Obsidian Drift",
            category: "Minimalist",
            preview: URL(string: "https://srimi1.github.io/Wallps/previews/wallps-seed-obsidian-drift.jpg")!,
            video: URL(string: "https://github.com/Srimi1/Wallps/releases/download/catalog-v1/wallps-seed-obsidian-drift.mp4")!,
            resolution: "4K UHD",
            credit: "Wallps",
            license: "CC0-1.0",
            bytes: 18173961,
            tags: ["dark", "minimal", "gradient", "calm"],
            mood: "Obsidian Dark",
            fps: 30,
            isFeatured: true,
            aspect: "16:9",
            colorHex: "#1b2430"
        ),
        CatalogEntry(
            id: "wallps-seed-cyan-aurora",
            title: "Cyan Aurora",
            category: "Nature",
            preview: URL(string: "https://srimi1.github.io/Wallps/previews/wallps-seed-cyan-aurora.jpg")!,
            video: URL(string: "https://github.com/Srimi1/Wallps/releases/download/catalog-v1/wallps-seed-cyan-aurora.mp4")!,
            resolution: "4K UHD",
            credit: "Wallps",
            license: "CC0-1.0",
            bytes: 18202536,
            tags: ["aurora", "cyan", "northern lights", "glow"],
            mood: "Neon Glow",
            fps: 30,
            isFeatured: true,
            aspect: "16:9",
            colorHex: "#33d9ff"
        ),
        CatalogEntry(
            id: "wallps-seed-nebula-field",
            title: "Nebula Field",
            category: "Sci-Fi",
            preview: URL(string: "https://srimi1.github.io/Wallps/previews/wallps-seed-nebula-field.jpg")!,
            video: URL(string: "https://github.com/Srimi1/Wallps/releases/download/catalog-v1/wallps-seed-nebula-field.mp4")!,
            resolution: "4K UHD",
            credit: "Wallps",
            license: "CC0-1.0",
            bytes: 16783467,
            tags: ["space", "stars", "nebula", "cosmic"],
            mood: "Cosmic Void",
            fps: 30,
            isFeatured: true,
            aspect: "16:9",
            colorHex: "#8f6bd8"
        ),
        CatalogEntry(
            id: "wallps-solar-ember",
            title: "Solar Ember",
            category: "Minimalist",
            preview: URL(string: "https://srimi1.github.io/Wallps/previews/wallps-solar-ember.jpg")!,
            video: URL(string: "https://github.com/Srimi1/Wallps/releases/download/catalog-v1/wallps-solar-ember.mp4")!,
            resolution: "4K UHD",
            credit: "Wallps",
            license: "CC0-1.0",
            bytes: 18195922,
            tags: ["warm", "amber", "sunset", "gradient"],
            mood: "Solar Gold",
            fps: 30,
            isFeatured: true,
            aspect: "16:9",
            colorHex: "#e9a23b"
        ),
        CatalogEntry(
            id: "wallps-midnight-bloom",
            title: "Midnight Bloom",
            category: "Minimalist",
            preview: URL(string: "https://srimi1.github.io/Wallps/previews/wallps-midnight-bloom.jpg")!,
            video: URL(string: "https://github.com/Srimi1/Wallps/releases/download/catalog-v1/wallps-midnight-bloom.mp4")!,
            resolution: "4K UHD",
            credit: "Wallps",
            license: "CC0-1.0",
            bytes: 17485452,
            tags: ["soft", "pastel", "calm", "lofi"],
            mood: "Chill Lofi",
            fps: 30,
            isFeatured: false,
            aspect: "16:9",
            colorHex: "#c48ad8"
        ),
        CatalogEntry(
            id: "wallps-glass-horizon",
            title: "Glass Horizon",
            category: "Minimalist",
            preview: URL(string: "https://srimi1.github.io/Wallps/previews/wallps-glass-horizon.jpg")!,
            video: URL(string: "https://github.com/Srimi1/Wallps/releases/download/catalog-v1/wallps-glass-horizon.mp4")!,
            resolution: "4K UHD",
            credit: "Wallps",
            license: "CC0-1.0",
            bytes: 17432796,
            tags: ["horizon", "soft", "blue", "gradient"],
            mood: "Ethereal Sunset",
            fps: 30,
            isFeatured: false,
            aspect: "16:9",
            colorHex: "#6fb6d8"
        ),
        CatalogEntry(
            id: "wallps-emerald-tide",
            title: "Emerald Tide",
            category: "Nature",
            preview: URL(string: "https://srimi1.github.io/Wallps/previews/wallps-emerald-tide.jpg")!,
            video: URL(string: "https://github.com/Srimi1/Wallps/releases/download/catalog-v1/wallps-emerald-tide.mp4")!,
            resolution: "4K UHD",
            credit: "Wallps",
            license: "CC0-1.0",
            bytes: 18184680,
            tags: ["ocean", "emerald", "waves", "bioluminescent"],
            mood: "Neon Glow",
            fps: 30,
            isFeatured: true,
            aspect: "16:9",
            colorHex: "#33ffa8"
        ),
        CatalogEntry(
            id: "wallps-violet-rain",
            title: "Violet Rain",
            category: "Rain & Atmosphere",
            preview: URL(string: "https://srimi1.github.io/Wallps/previews/wallps-violet-rain.jpg")!,
            video: URL(string: "https://github.com/Srimi1/Wallps/releases/download/catalog-v1/wallps-violet-rain.mp4")!,
            resolution: "4K UHD",
            credit: "Wallps",
            license: "CC0-1.0",
            bytes: 18165250,
            tags: ["rain", "violet", "moody", "cozy"],
            mood: "Misty Rain",
            fps: 30,
            isFeatured: false,
            aspect: "16:9",
            colorHex: "#7a6ad8"
        ),
        CatalogEntry(
            id: "wallps-ion-storm",
            title: "Ion Storm",
            category: "Sci-Fi",
            preview: URL(string: "https://srimi1.github.io/Wallps/previews/wallps-ion-storm.jpg")!,
            video: URL(string: "https://github.com/Srimi1/Wallps/releases/download/catalog-v1/wallps-ion-storm.mp4")!,
            resolution: "4K UHD",
            credit: "Wallps",
            license: "CC0-1.0",
            bytes: 16916422,
            tags: ["energy", "storm", "electric", "space"],
            mood: "Cosmic Void",
            fps: 30,
            isFeatured: false,
            aspect: "16:9",
            colorHex: "#4d8fe0"
        ),
        CatalogEntry(
            id: "wallps-deep-signal",
            title: "Deep Signal",
            category: "Cyberpunk",
            preview: URL(string: "https://srimi1.github.io/Wallps/previews/wallps-deep-signal.jpg")!,
            video: URL(string: "https://github.com/Srimi1/Wallps/releases/download/catalog-v1/wallps-deep-signal.mp4")!,
            resolution: "4K UHD",
            credit: "Wallps",
            license: "CC0-1.0",
            bytes: 10646132,
            tags: ["cyberpunk", "grid", "retro", "neon"],
            mood: "Neon Glow",
            fps: 30,
            isFeatured: true,
            aspect: "16:9",
            colorHex: "#33d9ff"
        )
    ]
}

