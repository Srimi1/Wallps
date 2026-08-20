import AVFoundation
import Foundation
import Observation

/// How the video is scaled inside each screen.
enum WallpaperGravity: String, CaseIterable, Codable, Sendable {
    case fill
    case fit
    case stretch

    var label: String {
        switch self {
        case .fill: return "Fill"
        case .fit: return "Fit"
        case .stretch: return "Stretch"
        }
    }

    var layerGravity: AVLayerVideoGravity {
        switch self {
        case .fill: return .resizeAspectFill
        case .fit: return .resizeAspect
        case .stretch: return .resize
        }
    }
}

/// User settings, backed by `UserDefaults` and observable by SwiftUI.
@MainActor
@Observable
final class Preferences {
    private enum Keys {
        static let muted = "muted"
        static let volume = "volume"
        static let gravity = "gravity"
        static let pauseOnBattery = "pauseOnBattery"
        static let pauseInLowPowerMode = "pauseInLowPowerMode"
        static let pauseWhenHidden = "pauseWhenHidden"
        static let catalogURLString = "catalogURLString"
        static let defaultWallpaperID = "defaultWallpaperID"
        static let perDisplayWallpaperIDs = "perDisplayWallpaperIDs"
    }

    static let defaultCatalogURL = "https://raw.githubusercontent.com/wallps/catalog/main/catalog.json"

    private let defaults: UserDefaults

    var muted: Bool { didSet { defaults.set(muted, forKey: Keys.muted) } }
    var volume: Double { didSet { defaults.set(volume, forKey: Keys.volume) } }
    var gravity: WallpaperGravity { didSet { defaults.set(gravity.rawValue, forKey: Keys.gravity) } }
    var pauseOnBattery: Bool { didSet { defaults.set(pauseOnBattery, forKey: Keys.pauseOnBattery) } }
    var pauseInLowPowerMode: Bool { didSet { defaults.set(pauseInLowPowerMode, forKey: Keys.pauseInLowPowerMode) } }
    var pauseWhenHidden: Bool { didSet { defaults.set(pauseWhenHidden, forKey: Keys.pauseWhenHidden) } }
    var catalogURLString: String { didSet { defaults.set(catalogURLString, forKey: Keys.catalogURLString) } }

    /// Wallpaper used for any display without an explicit per-display choice.
    var defaultWallpaperID: String? {
        didSet { defaults.set(defaultWallpaperID, forKey: Keys.defaultWallpaperID) }
    }

    /// Stable display key (CGDisplay UUID) → wallpaper item UUID string.
    var perDisplayWallpaperIDs: [String: String] {
        didSet { defaults.set(perDisplayWallpaperIDs, forKey: Keys.perDisplayWallpaperIDs) }
    }

    var playbackPolicy: PlaybackPolicy {
        PlaybackPolicy(
            pauseOnBattery: pauseOnBattery,
            pauseInLowPowerMode: pauseInLowPowerMode,
            pauseWhenHidden: pauseWhenHidden
        )
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        muted = defaults.object(forKey: Keys.muted) as? Bool ?? true
        volume = defaults.object(forKey: Keys.volume) as? Double ?? 0.5
        gravity = (defaults.string(forKey: Keys.gravity)).flatMap(WallpaperGravity.init(rawValue:)) ?? .fill
        pauseOnBattery = defaults.object(forKey: Keys.pauseOnBattery) as? Bool ?? true
        pauseInLowPowerMode = defaults.object(forKey: Keys.pauseInLowPowerMode) as? Bool ?? true
        pauseWhenHidden = defaults.object(forKey: Keys.pauseWhenHidden) as? Bool ?? true
        catalogURLString = defaults.string(forKey: Keys.catalogURLString) ?? Self.defaultCatalogURL
        defaultWallpaperID = defaults.string(forKey: Keys.defaultWallpaperID)
        perDisplayWallpaperIDs = defaults.dictionary(forKey: Keys.perDisplayWallpaperIDs) as? [String: String] ?? [:]
    }
}
