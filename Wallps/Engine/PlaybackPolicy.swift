import Foundation

/// Everything that can force playback to pause, gathered in one place.
struct PlaybackConditions: Sendable, Equatable {
    var userPaused = false
    var onBattery = false
    var lowPowerMode = false
    /// The wallpaper window for this display is covered by another window.
    var windowOccluded = false
    /// Screen locked, screensaver running, or displays asleep.
    var desktopHidden = false
}

/// Pure decision logic for whether a wallpaper window should be playing.
/// Kept free of AppKit and AVFoundation so it is trivially unit-testable —
/// this is the one piece of behaviour users notice on their battery meter.
struct PlaybackPolicy: Sendable, Equatable {
    var pauseOnBattery: Bool
    var pauseInLowPowerMode: Bool
    var pauseWhenHidden: Bool

    func shouldPlay(given conditions: PlaybackConditions) -> Bool {
        if conditions.userPaused { return false }
        // Never configurable: decoding video nobody can see is pure waste.
        if conditions.desktopHidden { return false }
        if pauseOnBattery && conditions.onBattery { return false }
        if pauseInLowPowerMode && conditions.lowPowerMode { return false }
        if pauseWhenHidden && conditions.windowOccluded { return false }
        return true
    }
}
