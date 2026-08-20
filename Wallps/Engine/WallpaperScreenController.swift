import AppKit
import AVFoundation

/// Owns the wallpaper window and player stack for a single display.
@MainActor
final class WallpaperScreenController {
    let displayKey: String
    private(set) var screen: NSScreen

    private let window: WallpaperWindow
    private let hostView: PlayerHostView
    private var player: AVQueuePlayer?
    private var looper: AVPlayerLooper?
    private var occlusionObserver: NSObjectProtocol?

    private(set) var currentItemID: UUID?
    /// True when the window server reports this window as not visible.
    private(set) var isOccluded = false
    var occlusionChanged: (() -> Void)?

    init(screen: NSScreen, displayKey: String) {
        self.screen = screen
        self.displayKey = displayKey
        hostView = PlayerHostView(frame: NSRect(origin: .zero, size: screen.frame.size))
        window = WallpaperWindow(contentRect: screen.frame)
        window.contentView = hostView

        occlusionObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didChangeOcclusionStateNotification,
            object: window,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                let occluded = !self.window.occlusionState.contains(.visible)
                guard occluded != self.isOccluded else { return }
                self.isOccluded = occluded
                self.occlusionChanged?()
            }
        }
    }

    func setWallpaper(
        url: URL,
        itemID: UUID,
        gravity: WallpaperGravity,
        muted: Bool,
        volume: Double
    ) {
        teardownPlayer()

        let asset = AVURLAsset(url: url)
        let item = AVPlayerItem(asset: asset)
        let queue = AVQueuePlayer()
        queue.isMuted = muted
        queue.volume = Float(volume)
        // A wallpaper must never keep the display awake.
        queue.preventsDisplaySleepDuringVideoPlayback = false
        queue.actionAtItemEnd = .advance
        looper = AVPlayerLooper(player: queue, templateItem: item)
        player = queue

        hostView.playerLayer.player = queue
        hostView.playerLayer.videoGravity = gravity.layerGravity
        currentItemID = itemID
        applyAudioTrackState(muted: muted)

        window.setFrame(screen.frame, display: true)
        window.orderFront(nil)
    }

    func clear() {
        teardownPlayer()
        currentItemID = nil
        window.orderOut(nil)
    }

    func setPlaying(_ playing: Bool) {
        guard let player else { return }
        if playing {
            if player.rate == 0 { player.play() }
        } else {
            player.pause()
        }
    }

    /// Playback rate and position, for diagnostics.
    var playbackSnapshot: (rate: Float, seconds: Double) {
        (player?.rate ?? -1, player?.currentTime().seconds ?? -1)
    }

    func update(muted: Bool, volume: Double, gravity: WallpaperGravity) {
        player?.isMuted = muted
        player?.volume = Float(volume)
        hostView.playerLayer.videoGravity = gravity.layerGravity
        applyAudioTrackState(muted: muted)
    }

    func updateScreen(_ screen: NSScreen) {
        self.screen = screen
        if window.isVisible {
            window.setFrame(screen.frame, display: true)
        }
    }

    /// Full teardown before the controller is discarded (display disconnected).
    func tearDown() {
        clear()
        if let occlusionObserver {
            NotificationCenter.default.removeObserver(occlusionObserver)
        }
        occlusionObserver = nil
        window.close()
    }

    /// Muting the player still decodes the audio track; disabling the track
    /// stops that work entirely.
    private func applyAudioTrackState(muted: Bool) {
        guard let currentItem = player?.currentItem else { return }
        for track in currentItem.tracks where track.assetTrack?.mediaType == .audio {
            track.isEnabled = !muted
        }
    }

    private func teardownPlayer() {
        // disableLooping() is one-way: switching videos means rebuilding the
        // looper, not reusing it.
        looper?.disableLooping()
        looper = nil
        player?.pause()
        player?.removeAllItems()
        player = nil
        hostView.playerLayer.player = nil
    }
}
