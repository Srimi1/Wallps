# Architecture

Why each piece works the way it does. If you only read one section, read
[Playback policy](#playback-policy) — it is where this app earns or loses its
reputation.

## The desktop window

macOS exposes no public API for setting a video as the wallpaper. What it does
expose is window levels, and there is a 20-level gap between the system wallpaper
and the desktop icons. Everything in this category lives in that gap.

Measured on macOS 26:

| Level | Occupant |
|---|---|
| -2147483624 | System wallpaper (drawn by the Dock process) |
| **-2147483623** | **`CGWindowLevelForKey(.desktopWindow)` — Wallps** |
| -2147483622 | Dock's fullscreen backdrop |
| -2147483603 | `.desktopIconWindow` — desktop icons |

`.desktopWindow` exactly is the right slot. One level higher collides with the
Dock's fullscreen backdrop; the system wallpaper is one level below, so there is
no tie to break.

`WallpaperWindow` configuration and the reason for each flag:

| Setting | Why |
|---|---|
| `styleMask: [.borderless]` | No title bar, no chrome |
| `ignoresMouseEvents = true` | Clicks reach the desktop, so icon selection and Show Desktop still work |
| `.canJoinAllSpaces` | The wallpaper is present on every Space |
| `.stationary` | Mission Control leaves it alone, like the real desktop |
| `.ignoresCycle` | Never appears in Cmd-Tab or the Window menu |
| `.fullScreenNone` | Doesn't follow apps into fullscreen Spaces, where it would decode video behind an opaque window |
| `isReleasedWhenClosed = false` | Closing a window mid-animation otherwise over-releases it |
| `canBecomeKey/Main = false` | Never steals focus |

The video is hosted by `PlayerHostView`, an `NSView` whose backing layer *is* an
`AVPlayerLayer`, so resizing the window resizes the video with no layout code.
It is a plain `NSView` rather than an `NSHostingView` subview on purpose: adding
subviews to `NSHostingView` is unsupported on macOS 26 and later.

## Playback policy

The whole point of this app is that it does nothing when nobody is looking.

`PlaybackPolicy.shouldPlay(given:)` is pure — no AppKit, no AVFoundation, no
clock — so every combination is unit-testable, and a battery-drain regression
shows up as a failing test instead of a support thread.

Inputs come from three monitors:

**`PowerMonitor`** — `IOPSNotificationCreateRunLoopSource` for AC-versus-battery
transitions, plus `NSProcessInfoPowerStateDidChange` for Low Power Mode. Both are
user-configurable pauses.

**`SystemStateMonitor`** — screen lock, screensaver, and display sleep. This
pause is *not* configurable: decoding video behind a locked screen has no upside.

Two things about this one are easy to get wrong. Lock and screensaver state are
only published as cross-process distributed notifications — registering them on
`NotificationCenter.default` silently never fires. And AppKit suspends
distributed delivery for inactive apps, which this app always is when the screen
locks, so they must be registered with `suspensionBehavior: .deliverImmediately`.
Fast user switching posts no lock notification at all, hence the
`sessionDidResignActive` observer, and `CGDisplayIsAsleep` is a backstop for a
missed wake notification.

**`OcclusionDetector`** — whether a window covers the desktop. Two signals, both
needed:

- `NSWindow.didChangeOcclusionStateNotification` is instant and free, but does
  not reliably fire for desktop-level windows covered by a fullscreen app.
- A 2-second `CGWindowListCopyWindowInfo` poll catches what the notification
  misses. It counts a display as covered when an opaque, layer-0 window from
  another app covers ≥90% of it, ignoring Finder, the Dock, Control Center, and
  friends.

The poll runs on a utility queue because it allocates a full window list, and it
reads only bounds, layer, PID, and alpha. It never reads window names or
contents, so it needs no Screen Recording permission — that distinction is the
whole reason this approach is acceptable.

While anything is playing, the engine holds a `beginActivity` token with
`.userInitiatedAllowingIdleSystemSleep`. That stops App Nap from throttling the
occlusion timer without ever preventing display or system sleep, which is also
why every player sets `preventsDisplaySleepDuringVideoPlayback = false`. A
wallpaper that keeps your Mac awake is a bug, not a feature.

## Multi-display

One `WallpaperScreenController` per display, keyed by
`CGDisplayCreateUUIDFromDisplayID`.

Never key by `NSScreen` identity. AppKit recreates `NSScreen` objects on every
display reconfiguration — sleep, wake, hot-plug, resolution change — so
object-keyed lookups silently miss afterwards. The UUID is also stable across
reboots, which is what lets per-display assignments persist.

`NSApplication.didChangeScreenParametersNotification` triggers reconciliation:
existing controllers get the new `NSScreen`, new displays get a controller,
disconnected displays get torn down. Mirrored displays report the same UUID, so
they collapse to one window.

Audio, when unmuted, plays only on `NSScreen.main`. Muted players additionally
get their audio tracks disabled (`track.isEnabled = false`) so the audio is not
decoded at all — muting alone still decodes it.

## Library

Videos are copied into the app container on import rather than referenced in
place. That costs disk, and it is the right trade:

- The library keeps working when the original is moved, renamed, or deleted.
- Under the sandbox it avoids persisting security-scoped bookmarks entirely; the
  scope is held only for the probe-and-copy.

Layout:

```
~/Library/Containers/app.wallps.Wallps/Data/Library/Application Support/Wallps/
  library.json        versioned index
  Videos/<uuid>.mp4
  Thumbnails/<uuid>.jpg
```

Filenames are UUIDs, so no title is ever a path, and the whole folder can be
moved or backed up as a unit. On load, entries whose video file has disappeared
are dropped rather than shown as broken tiles.

`VideoProber` rejects unplayable files and anything shorter than 0.5s (too short
to loop without stuttering), and records the codec and whether this Mac can
decode it in hardware via `VTIsHardwareDecodeSupported`. That last one matters:
10-bit HEVC needs a 2017-or-later Intel Mac, and on older hardware a 4K clip
falls back to software decode and burns a core.

`ThumbnailGenerator` sets `requestedTimeTolerance{Before,After} = .positiveInfinity`
so extraction snaps to the nearest keyframe — an order of magnitude faster, and
any nearby frame is an equally good thumbnail. It samples at 40% of the duration
because intros and fades make poor thumbnails.

## Catalog

A catalog is a plain JSON file at a URL — see [CATALOG.md](CATALOG.md). No
server, no account, no API. Anyone can host one; Settings takes any URL.

Downloads land in a temp file, get a real extension so AVFoundation can sniff the
container, and then go through the same import path as a local file. Catalog
entries record `catalogID` on the imported item so the gallery can mark what you
already have.

## Deliberately out of scope

**Lock screen and screensaver.** Both headline features of the commercial apps,
and both unavailable through public API. The two known techniques are dlopening
Apple's private `WallpaperExtensionKit`, or overwriting the system aerial files
under `com.apple.idleassetsd`. Each breaks on OS updates, and neither can ship
in the App Store. An open-source app that silently breaks every autumn is worse
than one that says no.

**A bundled video library.** Curated 4K libraries are the commercial products'
actual moat, and they cost real money in storage and CDN bandwidth. Wallps
ships an import path and an open catalog format instead.

## Testing

`PlaybackPolicy` and the library index are covered by unit tests. The window
layer, looping, and pause behaviour were verified empirically on macOS 26:
window level checked against `CGWindowLevelForKey`, and playback confirmed by
logging player rate and position with `WALLPS_DEBUG_PLAYBACK=1`.

Do not verify playback with screenshots. macOS serves a stale backing store for
a fully covered window, so consecutive captures are byte-identical whether the
player is running or paused — which reads as a pause bug that isn't there.
