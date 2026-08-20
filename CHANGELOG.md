# Changelog

All notable changes to **Wallps** are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [1.0.0] - 2026-08-20 (Official Stable Release)

### 🚀 Highlights
- **1-Click Instant Wallpaper Application**: Direct wallpaper switching from the Gallery, Desktop Simulator, and Library without extra steps or app restarts.
- **Quantum Prism App Icon**: Custom-crafted, futuristic obsidian glass & titanium app icon with 1024x1024 Retina support across all macOS display scales.
- **iOS 26 Multi-Dimensional Classification Matrix**: Dynamic filtering by Atmosphere & Mood, Resolution Specs (8K/4K XDR), and Sort Flow.
- **Wallpaper Cinema Inspector & Live Desktop Simulator**: Preview live video wallpapers beneath realistic macOS top Menu Bar, Dock, and Desktop icons.
- **Persistent Active Control Dock**: Bottom playback dock displaying active wallpaper thumbnail, live 60 FPS status, and immediate Pause/Resume/Clear actions.
- **Automated DMG Distribution Pipeline**: Production-ready, hardened-runtime signed `.dmg` installer with drag-and-drop `/Applications` symlink.

### 🛡️ Security & Privacy Standards
- **Zero Telemetry**: Completely free from tracking, analytics, and advertising SDKs.
- **No Screen Recording / Accessibility Requirements**: Geometry-based window occlusion checking via `CGWindowListCopyWindowInfo` with zero pixel capturing.
- **Apple Hardened Runtime**: Validated codesign with `app-sandbox`, `user-selected.read-only`, and `network.client` entitlements.

### 🧪 Verification & Quality Assurance
- **21/21 Unit Tests Passed** across `OcclusionGeometryTests`, `PlaybackPolicyTests`, `WallpaperItemFormattingTests`, and `WallpaperLibraryTests`.
- **DMG Verification Passed**: Strict signature validation (`valid on disk`, `satisfies Designated Requirement`) with zero extended-attribute detritus.
