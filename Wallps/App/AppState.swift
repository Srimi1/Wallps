import AppKit
import Foundation
import Observation

/// Root object wiring the library, catalog, preferences, and engine together.
@MainActor
@Observable
final class AppState {
    static let shared = AppState()

    let prefs: Preferences
    let library: WallpaperLibrary
    let catalog = CatalogStore()
    let engine: WallpaperEngine

    /// Which display the library UI is assigning to.
    var assignmentTarget: AssignmentTarget = .allDisplays

    /// The most recent failure worth telling the user about. Reads from
    /// whichever subsystem last failed, so a single alert covers all of them.
    var errorMessage: String? {
        get { library.lastError ?? catalog.lastError }
        set {
            library.lastError = newValue
            catalog.lastError = newValue
        }
    }

    // Defaults are built inside the initializer: default argument expressions
    // are evaluated in a nonisolated context, which these @MainActor types
    // can't be constructed from.
    init(prefs: Preferences? = nil, library: WallpaperLibrary? = nil) {
        let prefs = prefs ?? Preferences()
        let library = library ?? WallpaperLibrary()
        self.prefs = prefs
        self.library = library
        self.engine = WallpaperEngine(library: library, prefs: prefs)
    }

    private var started = false

    func start() {
        guard !started else { return }
        started = true
        library.load()
        engine.start()
    }

    func stop() {
        engine.stop()
    }

    func apply(_ item: WallpaperItem) {
        engine.assign(item, to: assignmentTarget)
    }

    func clearWallpaper() {
        engine.assign(nil, to: assignmentTarget)
    }

    func delete(_ item: WallpaperItem) {
        engine.wallpaperRemoved(item)
        library.delete(item)
    }

    func importVideos(from urls: [URL]) {
        Task {
            let imported = await library.importVideos(from: urls)
            // Applying the first import immediately makes the app feel instant
            // for someone who just dragged in their first video.
            if let first = imported.first, !engine.hasActiveWallpaper {
                apply(first)
            }
        }
    }

    func refreshCatalog() {
        Task { await catalog.refresh(from: prefs.catalogURLString) }
    }

    func download(_ entry: CatalogEntry) {
        Task { await catalog.download(entry, into: library) }
    }
}
