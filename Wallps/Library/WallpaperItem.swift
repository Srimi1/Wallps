import Foundation

/// A single wallpaper in the user's library.
///
/// The video and thumbnail files live inside the library folder under
/// Application Support; only relative filenames are stored so the whole
/// library can be moved or backed up as one folder.
struct WallpaperItem: Identifiable, Codable, Hashable, Sendable {
    enum Source: String, Codable, Sendable {
        /// Imported from a file on disk.
        case local
        /// Downloaded from a remote catalog.
        case remote
    }

    var id: UUID
    var title: String
    var videoFilename: String
    var thumbnailFilename: String?
    var duration: TimeInterval
    var pixelWidth: Int
    var pixelHeight: Int
    var source: Source
    var dateAdded: Date
    /// Set for catalog downloads, so the gallery can mark them as owned.
    var catalogID: String?
    var codec: String?
    var frameRate: Double?
    var fileSize: Int64?
    /// False when this Mac must decode the video in software.
    var hardwareDecodable: Bool?
    var credit: String?
    var license: String?

    var resolutionLabel: String {
        guard pixelWidth > 0, pixelHeight > 0 else { return "—" }
        if min(pixelWidth, pixelHeight) >= 2160 { return "4K" }
        if min(pixelWidth, pixelHeight) >= 1080 { return "\(pixelHeight)p" }
        return "\(pixelWidth)×\(pixelHeight)"
    }

    var durationLabel: String {
        guard duration.isFinite, duration > 0 else { return "—" }
        let total = Int(duration.rounded())
        return String(format: "%d:%02d", total / 60, total % 60)
    }

    var fileSizeLabel: String? {
        guard let fileSize else { return nil }
        return ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file)
    }

    /// Shown as a warning: software decoding a 4K video is the one way this app
    /// can noticeably hurt a Mac's battery life.
    var needsSoftwareDecode: Bool {
        hardwareDecodable == false
    }
}
