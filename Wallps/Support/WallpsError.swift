import Foundation

enum WallpsError: LocalizedError {
    case notAVideo(URL)
    case noVideoTrack(URL)
    case tooShort(URL)
    case thumbnailFailed
    case libraryIO(String)
    case badCatalog
    case downloadFailed(String)

    var errorDescription: String? {
        switch self {
        case .notAVideo(let url):
            return "“\(url.lastPathComponent)” isn't a playable video file."
        case .noVideoTrack(let url):
            return "“\(url.lastPathComponent)” has no video track."
        case .tooShort(let url):
            return "“\(url.lastPathComponent)” is too short to loop as a wallpaper."
        case .thumbnailFailed:
            return "Couldn't generate a thumbnail for this video."
        case .libraryIO(let message):
            return "Library error: \(message)"
        case .badCatalog:
            return "The wallpaper catalog couldn't be read."
        case .downloadFailed(let title):
            return "Couldn't download “\(title)”."
        }
    }
}
