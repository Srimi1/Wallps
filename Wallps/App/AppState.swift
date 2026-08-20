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

    var activeWallpaperItem: WallpaperItem? {
        guard let firstID = engine.activeItemIDs.first else { return nil }
        return library.item(withID: firstID)
    }

    var isPaused: Bool {
        engine.userPaused
    }

    func togglePause() {
        engine.userPaused.toggle()
    }

    func isItemActive(_ item: WallpaperItem) -> Bool {
        engine.activeItemIDs.contains(item.id)
    }

    func isCatalogEntryActive(_ entry: CatalogEntry) -> Bool {
        guard let item = library.items.first(where: { $0.catalogID == entry.id }) else { return false }
        return engine.activeItemIDs.contains(item.id)
    }

    func applyCatalogEntry(_ entry: CatalogEntry) {
        // If already downloaded in library, apply immediately!
        if let existing = library.items.first(where: { $0.catalogID == entry.id }) {
            apply(existing)
            return
        }

        // Otherwise, download and apply immediately upon completion
        Task {
            if let item = await catalog.download(entry, into: library) {
                apply(item)
            }
        }
    }

    func download(_ entry: CatalogEntry) {
        Task { _ = await catalog.download(entry, into: library) }
    }
}
