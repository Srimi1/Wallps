import SwiftUI

/// Loads a thumbnail off the main thread and caches it in memory.
struct ThumbnailImage: View {
    let url: URL?
    @State private var image: NSImage?

    var body: some View {
        ZStack {
            Rectangle().fill(.quaternary)
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                Image(systemName: "film")
                    .font(.title2)
                    .foregroundStyle(.secondary)
            }
        }
        .task(id: url) { await load() }
    }

    private func load() async {
        guard let url else {
            image = nil
            return
        }
        if let cached = ThumbnailCache.shared.image(for: url) {
            image = cached
            return
        }
        let loaded = await Task.detached(priority: .userInitiated) {
            NSImage(contentsOf: url)
        }.value
        if let loaded {
            ThumbnailCache.shared.store(loaded, for: url)
        }
        image = loaded
    }
}

final class ThumbnailCache: @unchecked Sendable {
    static let shared = ThumbnailCache()
    private let cache = NSCache<NSURL, NSImage>()

    private init() {
        cache.countLimit = 300
    }

    func image(for url: URL) -> NSImage? {
        cache.object(forKey: url as NSURL)
    }

    func store(_ image: NSImage, for url: URL) {
        cache.setObject(image, forKey: url as NSURL)
    }
}
