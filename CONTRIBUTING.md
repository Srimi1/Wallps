# Contributing

## Setup

```sh
make bootstrap   # installs XcodeGen if needed, generates the project
make test
```

`project.yml` is the source of truth. `Wallps.xcodeproj` is generated and not
checked in — add a file under `Wallps/` and run `make generate`.

Build output goes to `~/Library/Developer/Xcode/DerivedData`, deliberately: if
the repo lives in iCloud Drive or Dropbox, codesigning fails on the extended
attributes those services attach to build products.

## What's useful

Good first contributions, roughly in order of how much they'd help:

- **Catalog content.** The gallery needs a real CC0/CC-BY catalog. See
  [docs/CATALOG.md](docs/CATALOG.md).
- **Disk budget.** The library has no size cap or eviction policy. 4K videos
  are large and nothing currently stops the folder growing forever.
- **Display edge cases.** Portrait monitors, ultrawides, mixed scale factors,
  a laptop notch. If a video is mapped wrongly on your setup, a screenshot and
  your display arrangement is a complete bug report.
- **Localization.** All user-facing strings are inline English today.

## Testing changes to playback behaviour

`PlaybackPolicy` is pure logic and every pause condition it handles has a test.
If you add a reason to pause, add it there first — that's what keeps "does this
drain my battery" answerable without a Mac in front of you.

To watch the running engine:

```sh
WALLPS_DEBUG_PLAYBACK=1 <path>/Wallps.app/Contents/MacOS/Wallps
```

Each display logs its player rate and position once a second.

**Do not verify playback with screenshots.** macOS serves a stale backing store
for a fully covered window, so consecutive captures are byte-identical whether
the player is running or paused. This looks exactly like a pause bug and isn't
one — it cost an afternoon once already.

## Style

Match the surrounding code. A few conventions worth knowing:

- Everything touching AppKit or the engine is `@MainActor`. The only work moved
  off the main thread is file copying, thumbnail decoding, and the window-list
  poll — all things that would otherwise stutter the UI.
- Comments explain *why*, not what. If a line looks wrong but is deliberate, say
  what breaks without it.
- Displays are keyed by their `CGDisplay` UUID, never by `NSScreen` identity.
  AppKit recreates `NSScreen` objects on reconfiguration.

## Reporting bugs

Include your macOS version, your display setup (how many, resolutions, scale
factors), and whether you were on battery. Most of this app's interesting bugs
live in the interaction between those three.

## Scope

Lock-screen and screensaver support are out of scope — see the reasoning in
[docs/ARCHITECTURE.md](docs/ARCHITECTURE.md#deliberately-out-of-scope). If you
have found a *public* API that does either, that's a very welcome issue.

## Legal

Contributions are accepted under Apache-2.0. Don't contribute code, video, or
artwork you don't have the rights to — including anything extracted from a
commercial wallpaper app.
