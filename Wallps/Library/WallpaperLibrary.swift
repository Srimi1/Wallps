import AVFoundation
import Foundation
import Observation
import UniformTypeIdentifiers

/// The user's wallpaper collection: video files, thumbnails, and a JSON index,
/// all stored in one folder under Application Support.
///
/// Videos are copied in on import rather than referenced in place. That costs
/// disk, but it means the library keeps working when the original is moved or
/// deleted, and it avoids persisting security-scoped bookmarks.
@MainActor
@Observable
final class WallpaperLibrary {
    private(set) var items: [WallpaperItem] = []
    var lastError: String?

    let rootURL: URL
    var videosURL: URL { rootURL.appendingPathComponent("Videos", isDirectory: true) }
    var thumbnailsURL: URL { rootURL.appendingPathComponent("Thumbnails", isDirectory: true) }
    private var indexURL: URL { rootURL.appendingPathComponent("library.json") }

    /// Codable envelope so the on-disk format can evolve.
    private struct Index: Codable {
        var version: Int
        var items: [WallpaperItem]
    }

    private static let currentVersion = 1

    init(rootURL: URL? = nil) {
        if let rootURL {
            self.rootURL = rootURL
        } else {
            let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            self.rootURL = appSupport.appendingPathComponent("Wallps", isDirectory: true)
        }
    }

    // MARK: - Persistence

    func load() {
        ensureFolders()
        guard let data = try? Data(contentsOf: indexURL) else { return }
        do {
            let index = try JSONDecoder().decode(Index.self, from: data)
            // Drop entries whose video file has disappeared, so a half-deleted
            // library doesn't show broken tiles forever.
            let (present, missing) = index.items.reduce(into: ([WallpaperItem](), 0)) { result, item in
                if FileManager.default.fileExists(atPath: videoURL(for: item).path) {
                    result.0.append(item)
                } else {
                    result.1 += 1
                }
            }
            items = present
            if missing > 0 { save() }
        } catch {
            lastError = "Couldn't read the library index: \(error.localizedDescription)"
        }
    }

    func save() {
        ensureFolders()
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(Index(version: Self.currentVersion, items: items))
            try data.write(to: indexURL, options: .atomic)
        } catch {
            lastError = "Couldn't save the library index: \(error.localizedDescription)"
        }
    }

    // MARK: - Lookup

    func item(withID id: UUID) -> WallpaperItem? {
        items.first { $0.id == id }
    }

    func item(withIDString idString: String?) -> WallpaperItem? {
        guard let idString, let id = UUID(uuidString: idString) else { return nil }
        return item(withID: id)
    }

    func containsCatalogItem(id catalogID: String) -> Bool {
        items.contains { $0.catalogID == catalogID }
    }

    func videoURL(for item: WallpaperItem) -> URL {
        videosURL.appendingPathComponent(item.videoFilename)
    }

    func thumbnailURL(for item: WallpaperItem) -> URL? {
        guard let filename = item.thumbnailFilename else { return nil }
        return thumbnailsURL.appendingPathComponent(filename)
    }

    var totalBytes: Int64 {
        items.compactMap(\.fileSize).reduce(0, +)
    }

    // MARK: - Import

    static let allowedContentTypes: [UTType] = [.movie, .video, .mpeg4Movie, .quickTimeMovie]

    /// Imports videos picked or dropped by the user, reporting any that failed.
    @discardableResult
    func importVideos(from urls: [URL]) async -> [WallpaperItem] {
        var imported: [WallpaperItem] = []
        var failures: [String] = []
        for url in urls {
            do {
                let item = try await importVideo(
                    from: url,
                    title: url.deletingPathExtension().lastPathComponent,
                    source: .local,
                    removeOriginal: false
                )
                imported.append(item)
            } catch {
                failures.append(error.localizedDescription)
            }
        }
        if !failures.isEmpty {
            lastError = failures.joined(separator: "\n")
        }
        return imported
    }

    /// Core import: probe, copy into the library, thumbnail, index.
    func importVideo(
        from url: URL,
        title: String,
        source: WallpaperItem.Source,
        removeOriginal: Bool,
        catalogID: String? = nil,
        credit: String? = nil,
        license: String? = nil
    ) async throws -> WallpaperItem {
        ensureFolders()
        // Files picked through the open panel arrive security-scoped under the
        // sandbox; the scope must be held for the whole probe-and-copy.
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }

        let probe = try await VideoProber.probe(url: url)

        let id = UUID()
        let ext = url.pathExtension.isEmpty ? "mp4" : url.pathExtension
        let videoFilename = "\(id.uuidString).\(ext)"
        let destination = videosURL.appendingPathComponent(videoFilename)
        try await Self.transferFile(from: url, to: destination, removeOriginal: removeOriginal)

        var thumbnailFilename: String? = "\(id.uuidString).jpg"
        do {
            try await ThumbnailGenerator.generate(
                from: destination,
                to: thumbnailsURL.appendingPathComponent(thumbnailFilename!)
            )
        } catch {
            // A missing thumbnail is cosmetic; the wallpaper still works.
            thumbnailFilename = nil
        }

        let size = (try? destination.resourceValues(forKeys: [.fileSizeKey]).fileSize).flatMap(Int64.init)

        let item = WallpaperItem(
            id: id,
            title: title,
            videoFilename: videoFilename,
            thumbnailFilename: thumbnailFilename,
            duration: probe.duration,
            pixelWidth: probe.pixelWidth,
            pixelHeight: probe.pixelHeight,
            source: source,
            dateAdded: Date(),
            catalogID: catalogID,
            codec: probe.codec,
            frameRate: Double(probe.nominalFrameRate),
            fileSize: size,
            hardwareDecodable: probe.hardwareDecodable,
            credit: credit,
            license: license
        )
        add(item)
        return item
    }

    /// Adds an item whose files are already in place and persists the index.
    func add(_ item: WallpaperItem) {
        items.append(item)
        save()
    }

    func delete(_ item: WallpaperItem) {
        try? FileManager.default.removeItem(at: videoURL(for: item))
        if let thumb = thumbnailURL(for: item) {
            try? FileManager.default.removeItem(at: thumb)
        }
        items.removeAll { $0.id == item.id }
        save()
    }

    func rename(_ item: WallpaperItem, to newTitle: String) {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        items[index].title = newTitle
        save()
    }

    // MARK: - Helpers

    private func ensureFolders() {
        let fm = FileManager.default
        for url in [rootURL, videosURL, thumbnailsURL] {
            try? fm.createDirectory(at: url, withIntermediateDirectories: true)
        }
    }

    /// Copies (or moves) a potentially multi-gigabyte file off the main thread.
    private nonisolated static func transferFile(
        from source: URL,
        to destination: URL,
        removeOriginal: Bool
    ) async throws {
        try await Task.detached(priority: .utility) {
            let fm = FileManager.default
            if fm.fileExists(atPath: destination.path) {
                try fm.removeItem(at: destination)
            }
            if removeOriginal {
                try fm.moveItem(at: source, to: destination)
            } else {
                try fm.copyItem(at: source, to: destination)
            }
        }.value
    }
}
