import Foundation
import Observation

/// One downloadable wallpaper in a remote catalog.
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

    var categories: [String] {
        guard case .loaded(let entries) = state else { return [] }
        return Array(Set(entries.compactMap(\.category))).sorted()
    }

    func refresh(from urlString: String) async {
        guard let url = URL(string: urlString), url.scheme == "https" || url.scheme == "http" else {
            state = .failed("That doesn't look like a catalog URL.")
            return
        }
        state = .loading
        do {
            var request = URLRequest(url: url)
            request.cachePolicy = .reloadRevalidatingCacheData
            request.timeoutInterval = 20
            let (data, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
                throw WallpsError.badCatalog
            }
            let catalog = try JSONDecoder().decode(Catalog.self, from: data)
            state = .loaded(catalog.wallpapers)
        } catch {
            state = .failed("Couldn't load this catalog. Check the URL in Settings, or your connection.")
        }
    }

    func isDownloading(_ entry: CatalogEntry) -> Bool {
        progress[entry.id] != nil
    }

    /// Downloads a catalog entry and imports it into the library.
    func download(_ entry: CatalogEntry, into library: WallpaperLibrary) async {
        guard progress[entry.id] == nil else { return }
        progress[entry.id] = 0
        defer { progress[entry.id] = nil }

        do {
            let (tempURL, response) = try await URLSession.shared.download(from: entry.video)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                throw WallpsError.downloadFailed(entry.title)
            }
            // The temp file has no extension; AVFoundation needs one to sniff
            // the container.
            let ext = entry.video.pathExtension.isEmpty ? "mp4" : entry.video.pathExtension
            let renamed = tempURL.deletingLastPathComponent()
                .appendingPathComponent("\(UUID().uuidString).\(ext)")
            try FileManager.default.moveItem(at: tempURL, to: renamed)

            _ = try await library.importVideo(
                from: renamed,
                title: entry.title,
                source: .remote,
                removeOriginal: true,
                catalogID: entry.id,
                credit: entry.credit,
                license: entry.license
            )
        } catch {
            lastError = error.localizedDescription
        }
    }
}
