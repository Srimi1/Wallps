import AppKit
import Foundation
import Observation

/// Where a wallpaper assignment applies.
enum AssignmentTarget: Hashable {
    case allDisplays
    case display(key: String)
}

/// Owns one desktop-level window per display and keeps playback in line with
/// user settings and system conditions (battery, occlusion, lock, sleep).
@MainActor
@Observable
final class WallpaperEngine {
    private(set) var controllers: [String: WallpaperScreenController] = [:]
    var userPaused = false {
        didSet { refreshPlayback() }
    }

    private let library: WallpaperLibrary
    private let prefs: Preferences
    let power = PowerMonitor()
    let systemState = SystemStateMonitor()
    private let occlusion = OcclusionDetector()

    @ObservationIgnored private var screenObserver: NSObjectProtocol?
    @ObservationIgnored private var activity: NSObjectProtocol?
    @ObservationIgnored private var debugTimer: Timer?

    init(library: WallpaperLibrary, prefs: Preferences) {
        self.library = library
        self.prefs = prefs
    }

    // MARK: - Derived state for UI

    struct Display: Identifiable, Hashable {
        var key: String
        var name: String
        var id: String { key }
    }

    /// Published rather than computed from `NSScreen.screens` on demand: AppKit
    /// screen state is not observable, so a computed version never triggers a
    /// SwiftUI update when a display is plugged in or removed.
    private(set) var connectedDisplays: [Display] = []

    /// Likewise published: `WallpaperScreenController` is not `@Observable`, so
    /// reading through it would never redraw the checkmark on a card.
    private(set) var activeItemIDs: Set<UUID> = []

    var hasActiveWallpaper: Bool { !activeItemIDs.isEmpty }

    var statusDescription: String {
        let ids = activeItemIDs
        if ids.isEmpty { return "No wallpaper set" }
        if userPaused { return "Paused" }
        if ids.count == 1, let first = ids.first, let item = library.item(withID: first) {
            return item.title
        }
        return "\(ids.count) wallpapers active"
    }

    /// Why playback is currently stopped, for the menu bar. Nil when playing.
    var pauseReason: String? {
        guard hasActiveWallpaper else { return nil }
        if userPaused { return "Paused by you" }
        if systemState.desktopHidden { return "Desktop not visible" }
        if prefs.pauseOnBattery && power.onBattery { return "On battery" }
        if prefs.pauseInLowPowerMode && power.lowPowerMode { return "Low Power Mode" }
        if prefs.pauseWhenHidden && controllers.values.allSatisfy({ isCovered($0) }) {
            return "Covered by a window"
        }
        return nil
    }

    // MARK: - Lifecycle

    func start() {
        power.changed = { [weak self] in self?.refreshPlayback() }
        systemState.changed = { [weak self] in self?.refreshPlayback() }
        occlusion.changed = { [weak self] in self?.refreshPlayback() }
        power.start()
        systemState.start()
        systemState.refreshDisplaySleep()
        occlusion.start()

        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.syncControllers() }
        }

        observePreferences()
        syncControllers()

        startPlaybackLoggingIfRequested()
    }

    /// `WALLPS_DEBUG_PLAYBACK=1` logs each display's player rate and position
    /// once a second. Screenshots can't verify this: macOS serves a stale
    /// backing store for a fully covered window, so the picture looks frozen
    /// whether or not the player is running.
    private func startPlaybackLoggingIfRequested() {
        guard ProcessInfo.processInfo.environment["WALLPS_DEBUG_PLAYBACK"] != nil else { return }
        let timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                for (key, controller) in self.controllers {
                    let snap = controller.playbackSnapshot
                    let line = "[wallps] \(key.prefix(8)) rate=\(snap.rate) t=\(String(format: "%.2f", snap.seconds))\n"
                    FileHandle.standardError.write(Data(line.utf8))
                }
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        debugTimer = timer
    }

    func stop() {
        power.stop()
        systemState.stop()
        occlusion.stop()
        debugTimer?.invalidate()
        debugTimer = nil
        if let screenObserver {
            NotificationCenter.default.removeObserver(screenObserver)
        }
        screenObserver = nil
        controllers.values.forEach { $0.tearDown() }
        controllers = [:]
        updateActivity(anyPlaying: false)
    }

    // MARK: - Assignment

    func assign(_ item: WallpaperItem?, to target: AssignmentTarget) {
        switch target {
        case .allDisplays:
            prefs.defaultWallpaperID = item?.id.uuidString
            prefs.perDisplayWallpaperIDs = [:]
        case .display(let key):
            var map = prefs.perDisplayWallpaperIDs
            map[key] = item?.id.uuidString
            prefs.perDisplayWallpaperIDs = map
        }
        applyAssignments()
    }

    /// Called when an item is deleted from the library.
    func wallpaperRemoved(_ item: WallpaperItem) {
        let id = item.id.uuidString
        if prefs.defaultWallpaperID == id { prefs.defaultWallpaperID = nil }
        prefs.perDisplayWallpaperIDs = prefs.perDisplayWallpaperIDs.filter { $0.value != id }
        applyAssignments()
    }

    // MARK: - Windows

    /// Brings the set of controllers in line with the connected displays.
    /// Keyed by display UUID, never by `NSScreen` identity: AppKit recreates
    /// `NSScreen` objects on every display reconfiguration.
    func syncControllers() {
        var seen: Set<String> = []
        var displays: [Display] = []
        for screen in NSScreen.screens {
            let key = screen.wallpsDisplayKey
            // Mirrored displays report the same UUID; one window is enough.
            guard seen.insert(key).inserted else { continue }
            displays.append(Display(key: key, name: screen.localizedName))

            if let controller = controllers[key] {
                controller.updateScreen(screen)
            } else {
                let controller = WallpaperScreenController(screen: screen, displayKey: key)
                controller.occlusionChanged = { [weak self] in self?.refreshPlayback() }
                controllers[key] = controller
            }
        }
        for (key, controller) in controllers where !seen.contains(key) {
            controller.tearDown()
            controllers.removeValue(forKey: key)
        }
        connectedDisplays = displays
        applyAssignments()
    }

    func applyAssignments() {
        let mainKey = NSScreen.main?.wallpsDisplayKey
        for (key, controller) in controllers {
            let idString = prefs.perDisplayWallpaperIDs[key] ?? prefs.defaultWallpaperID
            if let item = library.item(withIDString: idString) {
                // Only the main display plays audio; duplicate soundtracks from
                // several displays are never what anyone wants.
                let muted = prefs.muted || key != mainKey
                if controller.currentItemID != item.id {
                    controller.setWallpaper(
                        url: library.videoURL(for: item),
                        itemID: item.id,
                        gravity: prefs.gravity,
                        muted: muted,
                        volume: prefs.volume
                    )
                } else {
                    controller.update(muted: muted, volume: prefs.volume, gravity: prefs.gravity)
                }
            } else {
                controller.clear()
            }
        }
        activeItemIDs = Set(controllers.values.compactMap(\.currentItemID))
        refreshPlayback()
    }

    // MARK: - Playback

    func refreshPlayback() {
        let policy = prefs.playbackPolicy
        var anyPlaying = false
        for controller in controllers.values {
            let conditions = PlaybackConditions(
                userPaused: userPaused,
                onBattery: power.onBattery,
                lowPowerMode: power.lowPowerMode,
                windowOccluded: isCovered(controller),
                desktopHidden: systemState.desktopHidden
            )
            let play = controller.currentItemID != nil && policy.shouldPlay(given: conditions)
            controller.setPlaying(play)
            if play { anyPlaying = true }
        }
        updateActivity(anyPlaying: anyPlaying)
    }

    /// A display counts as covered if either signal says so: the window-server
    /// occlusion state, or the window-list coverage poll (which catches
    /// fullscreen apps the occlusion notification misses).
    private func isCovered(_ controller: WallpaperScreenController) -> Bool {
        controller.isOccluded || occlusion.coveredDisplays.contains(controller.displayKey)
    }

    private func applyAudioAndLayout() {
        let mainKey = NSScreen.main?.wallpsDisplayKey
        for (key, controller) in controllers {
            controller.update(
                muted: prefs.muted || key != mainKey,
                volume: prefs.volume,
                gravity: prefs.gravity
            )
        }
    }

    /// Keeps App Nap from throttling playback and the occlusion timer while a
    /// wallpaper is active, without ever preventing display or system sleep.
    private func updateActivity(anyPlaying: Bool) {
        if anyPlaying, activity == nil {
            activity = ProcessInfo.processInfo.beginActivity(
                options: [.userInitiatedAllowingIdleSystemSleep],
                reason: "Wallpaper video playback"
            )
        } else if !anyPlaying, let activity {
            ProcessInfo.processInfo.endActivity(activity)
            self.activity = nil
        }
    }

    // MARK: - Preference observation

    private func observePreferences() {
        withObservationTracking {
            _ = prefs.muted
            _ = prefs.volume
            _ = prefs.gravity
            _ = prefs.pauseOnBattery
            _ = prefs.pauseInLowPowerMode
            _ = prefs.pauseWhenHidden
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.applyAudioAndLayout()
                self.refreshPlayback()
                self.observePreferences()
            }
        }
    }
}
