import AppKit
import AVFoundation

/// Borderless window pinned above the system wallpaper and below the desktop
/// icons, on every Space.
///
/// `.desktopWindow` is exactly the right slot, and the neighbours explain why:
/// the system wallpaper sits one level below it, the Dock's fullscreen backdrop
/// sits one level above, and the icons are 20 levels above that.
final class WallpaperWindow: NSWindow {
    init(contentRect: NSRect) {
        super.init(contentRect: contentRect, styleMask: [.borderless], backing: .buffered, defer: false)
        level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopWindow)))
        // .fullScreenNone keeps the wallpaper out of fullscreen Spaces, where it
        // would only burn power behind an opaque window.
        collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenNone]
        ignoresMouseEvents = true
        isOpaque = true
        hasShadow = false
        isExcludedFromWindowsMenu = true
        // Closing a window that is mid-animation over-releases it when this is
        // left at the default.
        isReleasedWhenClosed = false
        animationBehavior = .none
        canHide = false
        backgroundColor = .black
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

/// An NSView whose backing layer is an `AVPlayerLayer`, so the video resizes
/// with the window for free.
final class PlayerHostView: NSView {
    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func makeBackingLayer() -> CALayer {
        let layer = AVPlayerLayer()
        layer.videoGravity = .resizeAspectFill
        layer.backgroundColor = NSColor.black.cgColor
        return layer
    }

    var playerLayer: AVPlayerLayer {
        // Safe: `makeBackingLayer()` above is the only source of this layer.
        layer as! AVPlayerLayer
    }
}
