import AppKit
import CoreGraphics
import Foundation

/// Detects when a normal window covers essentially all of a screen, so playback
/// for that display can stop.
///
/// `NSWindow.didChangeOcclusionStateNotification` does not reliably fire for
/// desktop-level windows when a fullscreen app covers them, so this polls the
/// window list as well. Only bounds/layer/PID are read, which needs no
/// Screen Recording permission.
@MainActor
final class OcclusionDetector {
    /// Fraction of a screen a window must cover to count as hiding the wallpaper.
    private nonisolated static let coverageThreshold = 0.9
    private nonisolated static let interval: TimeInterval = 2

    /// Display key → covered.
    private(set) var coveredDisplays: Set<String> = []
    var changed: (() -> Void)?

    private var timer: Timer?
    private var spaceObserver: NSObjectProtocol?

    /// Windows that belong to the desktop furniture rather than to an app that
    /// would actually hide the wallpaper.
    private static let ignoredBundleIDs: Set<String> = [
        Bundle.main.bundleIdentifier ?? "app.wallps.Wallps",
        "com.apple.finder",
        "com.apple.dock",
        "com.apple.systemuiserver",
        "com.apple.controlcenter",
        "com.apple.notificationcenterui",
        "com.apple.WindowManager",
    ]

    func start() {
        let timer = Timer.scheduledTimer(withTimeInterval: Self.interval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in await self?.sample() }
        }
        timer.tolerance = Self.interval / 4
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer

        // Entering a fullscreen Space is the moment coverage changes.
        spaceObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.activeSpaceDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in await self?.sample() }
        }

        Task { await sample() }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        if let spaceObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(spaceObserver)
        }
        spaceObserver = nil
    }

    /// Samples the window list off the main thread and diffs the result.
    func sample() async {
        let screens = NSScreen.screens.map { (key: $0.wallpsDisplayKey, frame: $0.frame) }
        guard !screens.isEmpty else { return }

        let ownPID = ProcessInfo.processInfo.processIdentifier
        let ignoredPIDs = Set(
            NSWorkspace.shared.runningApplications
                .filter { Self.ignoredBundleIDs.contains($0.bundleIdentifier ?? "") }
                .map(\.processIdentifier)
        ).union([ownPID])

        // CGWindowList reports bounds in a flipped space whose origin is the
        // TOP-LEFT of the primary display; AppKit frames are bottom-left origin.
        // The pivot is the primary screen's own maxY — not the tallest point of
        // the whole arrangement, which would shift every rect once a second
        // display sits above the primary one.
        let flipped = screens.map { screen in
            (key: screen.key, rect: Self.flip(screen.frame, primaryMaxY: primaryMaxY))
        }

        let covered = await Task.detached(priority: .utility) {
            Self.coveredDisplays(screens: flipped, ignoredPIDs: ignoredPIDs)
        }.value

        guard covered != coveredDisplays else { return }
        coveredDisplays = covered
        changed?()
    }

    /// The primary display is `NSScreen.screens[0]` — the one whose frame
    /// origin is (0, 0) and which carries the menu bar.
    private var primaryMaxY: CGFloat {
        NSScreen.screens.first?.frame.maxY ?? 0
    }

    /// Converts a bottom-left-origin AppKit rect into the top-left-origin space
    /// that `CGWindowListCopyWindowInfo` reports bounds in.
    nonisolated static func flip(_ rect: CGRect, primaryMaxY: CGFloat) -> CGRect {
        CGRect(x: rect.minX, y: primaryMaxY - rect.maxY, width: rect.width, height: rect.height)
    }

    private nonisolated static func coveredDisplays(
        screens: [(key: String, rect: CGRect)],
        ignoredPIDs: Set<pid_t>
    ) -> Set<String> {
        guard let windows = CGWindowListCopyWindowInfo(.optionOnScreenOnly, kCGNullWindowID) as? [[String: Any]] else {
            return []
        }

        var covered: Set<String> = []
        for window in windows {
            // Layer 0 is the normal application window layer; menus, the Dock,
            // and the desktop all live on other layers.
            guard let layer = window[kCGWindowLayer as String] as? Int, layer == 0,
                  let pid = (window[kCGWindowOwnerPID as String] as? NSNumber)?.int32Value,
                  !ignoredPIDs.contains(pid),
                  let boundsDict = window[kCGWindowBounds as String] as? [String: Any],
                  let bounds = CGRect(dictionaryRepresentation: boundsDict as CFDictionary),
                  let alpha = window[kCGWindowAlpha as String] as? Double, alpha > 0.9
            else { continue }

            for screen in screens where !covered.contains(screen.key) {
                let overlap = bounds.intersection(screen.rect)
                guard !overlap.isNull else { continue }
                let screenArea = screen.rect.width * screen.rect.height
                guard screenArea > 0 else { continue }
                if (overlap.width * overlap.height) / screenArea >= coverageThreshold {
                    covered.insert(screen.key)
                }
            }
        }
        return covered
    }
}
