# Wallps

Live video wallpapers for macOS. Open source, no account, no telemetry.

Wallps plays a looping video behind your desktop icons and gets out of the way:
it stops decoding the moment nobody can see it, so an idle Mac stays idle.

An open-source alternative to commercial live-wallpaper apps. Unaffiliated with
any of them — all code and assets here are original.

## Status

Working, early. The wallpaper engine, library, power management, per-display
assignment, and the catalog gallery are implemented and verified on macOS 26.
See [Roadmap](#roadmap) for what isn't done.

## How it works

macOS has no public API for "set this video as the wallpaper", so every app in
this category does the same thing: it puts a window at the desktop window level.

```
level -2147483624   system wallpaper (the Dock draws this)
level -2147483623   ← Wallps renders here
level -2147483622   Dock fullscreen backdrop
level -2147483603   desktop icons
level 0             your apps
```

A borderless, click-through `NSWindow` at `CGWindowLevelForKey(.desktopWindow)`
sits above the system wallpaper and 20 levels below the icons, so icons, widgets,
and every app stay on top and clicks pass straight through to the desktop.

One window per display, each with an `AVQueuePlayer` driven by an
`AVPlayerLooper` for gapless looping. Video is hardware-decoded by the media
engine, so a 4K clip costs a few percent CPU rather than a core.

The part that matters for your battery is knowing when to stop:

| Condition | Detected via | Default |
|---|---|---|
| Covered by a window | `NSWindow` occlusion state **and** a 2s `CGWindowListCopyWindowInfo` coverage poll | pause |
| Screen locked, screensaver running | `DistributedNotificationCenter`, registered `.deliverImmediately` | always pause |
| Displays asleep | `NSWorkspace.screensDidSleep` + `CGDisplayIsAsleep` backstop | always pause |
| On battery | IOKit power source notifications | pause |
| Low Power Mode | `ProcessInfo.isLowPowerModeEnabled` | pause |

Both occlusion signals are needed: the window-server occlusion notification does
not fire reliably for desktop-level windows covered by a fullscreen app, and the
poll alone is 2 seconds late. Neither needs any TCC permission — only window
bounds, layer, and PID are read, never window contents or names.

`PlaybackPolicy` holds this decision as pure logic with no AppKit or AVFoundation
in sight, which is why it can be unit-tested exhaustively.

## Install

Requires macOS 14 (Sonoma) or later, Apple Silicon or Intel.

```sh
git clone <your-fork>
cd Wallps
make bootstrap   # installs XcodeGen if needed, generates Wallps.xcodeproj
make run
```

Wallps lives in the menu bar; it has no Dock icon. Open the library from the menu
bar icon, drop in a video, and double-click it.

> Building from a folder synced by iCloud Drive or Dropbox? Codesigning rejects
> the extended attributes those services attach. The Makefile already puts build
> output under `~/Library/Developer/Xcode/DerivedData`; keep it there.

## Using it

- **Add a video** — drag any H.264 or HEVC file onto the library window, or use
  Add Video. Files are copied into the app's container, so moving the original
  later doesn't break anything.
- **Multiple displays** — with more than one display connected, a picker appears
  in the toolbar. Assign a different video per display, or one for all.
- **Gallery** — browse a catalog of downloadable wallpapers. The default catalog
  URL is a plain JSON file; point Settings at any other one, including your own.
  See [docs/CATALOG.md](docs/CATALOG.md).
- **Audio** — muted by default. When unmuted, only the main display plays sound,
  and muted videos have their audio track disabled so it isn't decoded at all.

## Architecture

```
Wallps/
  App/        AppState (root object), WallpsApp (scenes), AppDelegate
  Engine/     WallpaperEngine ── one WallpaperScreenController per display
              WallpaperWindow (desktop-level NSWindow + AVPlayerLayer host)
              PlaybackPolicy (pure), PowerMonitor, SystemStateMonitor,
              OcclusionDetector
  Library/    WallpaperLibrary (files + JSON index), CatalogStore (remote),
              VideoProber, ThumbnailGenerator
  UI/         LibraryWindow, GalleryView, SettingsView, MenuBarContent
  Support/    Preferences, WallpsError
```

`WallpaperEngine` is the only object that talks to both preferences and the
system monitors. Everything it decides flows through `PlaybackPolicy`, so a bug
in the "when should this be playing" logic is a failing unit test rather than a
mystery battery drain.

Displays are keyed by `CGDisplayCreateUUIDFromDisplayID`, never by `NSScreen`
identity — AppKit recreates `NSScreen` objects on every display reconfiguration,
so object-keyed lookups go stale on sleep, hot-plug, or resolution change.

Details and the reasoning behind each choice: [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).

## Development

```sh
make generate   # regenerate the Xcode project after adding files
make build
make test
```

`project.yml` is the source of truth for the project; `Wallps.xcodeproj` is
generated and not checked in. Add a file to `Wallps/` and run `make generate`.

To watch what the engine is doing:

```sh
WALLPS_DEBUG_PLAYBACK=1 ./build/.../Wallps.app/Contents/MacOS/Wallps
```

It logs each display's player rate and position every second. Use this rather
than screenshots — macOS serves a stale backing store for a fully covered
window, so a screenshot looks frozen whether or not the player is running.

## Roadmap

Implemented: desktop rendering, looping, multi-display, per-display assignment,
power and occlusion management, local import, thumbnails, remote catalog,
launch at login, sandboxed.

Not yet:

- **Signing and notarization.** Releases need a Developer ID; without one,
  macOS Sequoia and later make users dig through System Settings to open the
  app, and Homebrew removed casks failing Gatekeeper checks on 1 Sept 2026.
- **Sparkle updates.** Depends on signing.
- **A real catalog.** The default URL is a placeholder. Needs CC0/CC-BY content
  and someone to host it.
- **Lock screen and screensaver.** Deliberately out of scope: every known method
  is either a private framework or overwriting system aerial files. Both break
  on OS updates and neither can ship in the App Store.
- **Disk budget.** The library has no size cap or eviction yet; 4K videos are
  large.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md). Bug reports that include the macOS
version, display setup, and whether you were on battery are the useful kind.

## License

Apache-2.0. See [LICENSE](LICENSE).
