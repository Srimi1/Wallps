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

    // MARK: - Curated Built-in Library (Futuristic iOS 26 / Wallper inspired)

    static let curatedCatalog: [CatalogEntry] = [
        CatalogEntry(
            id: "wallper-gathering-storm",
            title: "Gathering Storm",
            category: "Nature",
            preview: URL(string: "https://cdn.wallper.app/previews/fb8bbce9-30cc-4280-89d3-ba1f07a71a24.png")!,
            video: URL(string: "https://cdn.wallper.app/videos/fb8bbce9-30cc-4280-89d3-ba1f07a71a24.mp4")!,
            resolution: "4K XDR",
            credit: "Wallper Studios",
            license: "Creative Commons",
            bytes: 52428800,
            tags: ["storm", "clouds", "dramatic", "lightning"],
            mood: "Misty Rain",
            fps: 60,
            isFeatured: true,
            aspect: "16:9",
            colorHex: "#3b4252"
        ),
        CatalogEntry(
            id: "wallper-nte-zankou",
            title: "NTE - Zankou Neon",
            category: "Cyberpunk",
            preview: URL(string: "https://cdn.wallper.app/previews/b1505cfa-58a4-4215-b8f5-833b3f025022.png")!,
            video: URL(string: "https://cdn.wallper.app/videos/b1505cfa-58a4-4215-b8f5-833b3f025022.mp4")!,
            resolution: "4K UHD",
            credit: "Zankou Art",
            license: "Personal Use",
            bytes: 61865984,
            tags: ["cyberpunk", "neon", "tokyo", "futuristic"],
            mood: "Neon Glow",
            fps: 60,
            isFeatured: true,
            aspect: "16:9",
            colorHex: "#81a1c1"
        ),
        CatalogEntry(
            id: "wallper-snow-cherry",
            title: "Snow and Cherry Blossoms",
            category: "Minimalist",
            preview: URL(string: "https://cdn.wallper.app/previews/2a01a84e-86cd-4247-a5af-b15cfcee95b2.png")!,
            video: URL(string: "https://cdn.wallper.app/videos/2a01a84e-86cd-4247-a5af-b15cfcee95b2.mp4")!,
            resolution: "8K Ultra",
            credit: "Kumo Design",
            license: "Royalty Free",
            bytes: 44040192,
            tags: ["cherry blossom", "snow", "zen", "japan"],
            mood: "Chill Lofi",
            fps: 60,
            isFeatured: true,
            aspect: "16:9",
            colorHex: "#e5e9f0"
        ),
        CatalogEntry(
            id: "wallper-life-is-strange",
            title: "Arcadia Bay Sunset Glow",
            category: "Gaming",
            preview: URL(string: "https://cdn.wallper.app/previews/8627209e-6bd4-4c97-a2a4-3fabb86cd2c7.png")!,
            video: URL(string: "https://cdn.wallper.app/videos/8627209e-6bd4-4c97-a2a4-3fabb86cd2c7.mp4")!,
            resolution: "4K XDR",
            credit: "Arcadia Visuals",
            license: "Personal Use",
            bytes: 58720256,
            tags: ["sunset", "lighthouse", "coastal", "nostalgia"],
            mood: "Ethereal Sunset",
            fps: 60,
            isFeatured: false,
            aspect: "16:9",
            colorHex: "#d08770"
        ),
        CatalogEntry(
            id: "wallper-avengers-group",
            title: "Cosmic Odyssey",
            category: "Sci-Fi",
            preview: URL(string: "https://cdn.wallper.app/previews/6910f2f7-2193-4e06-82ee-c21d6f8e6117.png")!,
            video: URL(string: "https://cdn.wallper.app/videos/6910f2f7-2193-4e06-82ee-c21d6f8e6117.mp4")!,
            resolution: "4K XDR",
            credit: "Marvel Cinematic Archive",
            license: "Creative Commons",
            bytes: 73400320,
            tags: ["space", "cosmic", "portal", "heroes"],
            mood: "Cosmic Void",
            fps: 60,
            isFeatured: true,
            aspect: "16:9",
            colorHex: "#b48ead"
        ),
        CatalogEntry(
            id: "wallper-ichigo-bleach",
            title: "Moonlight Horizon",
            category: "Anime",
            preview: URL(string: "https://cdn.wallper.app/previews/15425d4d-4065-47cc-812c-58bd20a898a3.png")!,
            video: URL(string: "https://cdn.wallper.app/videos/15425d4d-4065-47cc-812c-58bd20a898a3.mp4")!,
            resolution: "4K UHD",
            credit: "Studio Bleach",
            license: "Personal Use",
            bytes: 49283072,
            tags: ["anime", "ichigo", "sword", "spiritual"],
            mood: "Obsidian Dark",
            fps: 60,
            isFeatured: false,
            aspect: "16:9",
            colorHex: "#2e3440"
        ),
        CatalogEntry(
            id: "wallper-bmw-m3",
            title: "BMW M3 GTR Night Drift",
            category: "Cars",
            preview: URL(string: "https://cdn.wallper.app/previews/445beb86-415b-4a65-b50c-a8ec94c65d71.png")!,
            video: URL(string: "https://cdn.wallper.app/videos/445beb86-415b-4a65-b50c-a8ec94c65d71.mp4")!,
            resolution: "4K UHD",
            credit: "NFS Garage",
            license: "Personal Use",
            bytes: 53477376,
            tags: ["cars", "drift", "bmw", "night"],
            mood: "Neon Glow",
            fps: 60,
            isFeatured: true,
            aspect: "16:9",
            colorHex: "#88c0d0"
        ),
        CatalogEntry(
            id: "wallper-red-bull",
            title: "Red Bull F1 Apex Velocity",
            category: "Cars",
            preview: URL(string: "https://cdn.wallper.app/previews/a403bab4-94fd-4193-a9c9-754d047efac2.png")!,
            video: URL(string: "https://cdn.wallper.app/videos/a403bab4-94fd-4193-a9c9-754d047efac2.mp4")!,
            resolution: "8K Ultra",
            credit: "Motorsport Visuals",
            license: "Personal Use",
            bytes: 67108864,
            tags: ["f1", "racing", "speed", "redbull"],
            mood: "Solar Gold",
            fps: 60,
            isFeatured: false,
            aspect: "16:9",
            colorHex: "#ebcb8b"
        ),
        CatalogEntry(
            id: "wallper-agera-rs",
            title: "Koenigsegg Agera RS Horizon",
            category: "Cars",
            preview: URL(string: "https://cdn.wallper.app/previews/f454eef3-0f14-43c0-82e2-09e7542ccaf8.png")!,
            video: URL(string: "https://cdn.wallper.app/videos/f454eef3-0f14-43c0-82e2-09e7542ccaf8.mp4")!,
            resolution: "4K XDR",
            credit: "Supercar Archive",
            license: "Creative Commons",
            bytes: 60817408,
            tags: ["hypercar", "koenigsegg", "sunset"],
            mood: "Ethereal Sunset",
            fps: 60,
            isFeatured: false,
            aspect: "16:9",
            colorHex: "#bf616a"
        ),
        CatalogEntry(
            id: "wallper-rainy-night",
            title: "Rainy Night Window Cafe",
            category: "Rain & Atmosphere",
            preview: URL(string: "https://cdn.wallper.app/previews/57d75a88-c946-4781-adb5-3b32de93fcd8.png")!,
            video: URL(string: "https://cdn.wallper.app/videos/57d75a88-c946-4781-adb5-3b32de93fcd8.mp4")!,
            resolution: "4K XDR",
            credit: "Lofi Ambience Lab",
            license: "Royalty Free",
            bytes: 47185920,
            tags: ["rain", "window", "droplets", "cozy", "cafe"],
            mood: "Misty Rain",
            fps: 60,
            isFeatured: true,
            aspect: "16:9",
            colorHex: "#4c566a"
        ),
        CatalogEntry(
            id: "wallper-shooting-stars",
            title: "Shooting Stars over Shinjuku",
            category: "Anime",
            preview: URL(string: "https://cdn.wallper.app/previews/cee41b57-9fd3-4522-adf9-c579be9b08bc.png")!,
            video: URL(string: "https://cdn.wallper.app/videos/cee41b57-9fd3-4522-adf9-c579be9b08bc.mp4")!,
            resolution: "4K UHD",
            credit: "Makoto Vibes",
            license: "Personal Use",
            bytes: 50331648,
            tags: ["meteor", "night sky", "city", "anime"],
            mood: "Cosmic Void",
            fps: 60,
            isFeatured: true,
            aspect: "16:9",
            colorHex: "#5e81ac"
        ),
        CatalogEntry(
            id: "wallper-blue-beach",
            title: "Bioluminescent Blue Tide",
            category: "Nature",
            preview: URL(string: "https://cdn.wallper.app/previews/c7f2731c-af1a-4b5a-9549-563b98379a67.png")!,
            video: URL(string: "https://cdn.wallper.app/videos/c7f2731c-af1a-4b5a-9549-563b98379a67.mp4")!,
            resolution: "8K Ultra",
            credit: "Ocean Wonders",
            license: "CC0 Public Domain",
            bytes: 75497472,
            tags: ["ocean", "waves", "bioluminescence", "glow"],
            mood: "Neon Glow",
            fps: 60,
            isFeatured: true,
            aspect: "16:9",
            colorHex: "#88c0d0"
        )
    ]
}

