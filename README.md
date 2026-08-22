<div align="center">

<img src="docs/assets/app_icon.png" width="128" height="128" alt="Wallps App Icon" style="border-radius: 28px; margin-bottom: 8px; box-shadow: 0 12px 32px rgba(0,0,0,0.4);" />

# Wallps

**Ultra-Minimal 4K Live Video Wallpapers for macOS & Windows.**  
*Native, Hardware-Accelerated • Battery-Aware • Zero Telemetry • Open Source*

[![macOS](https://img.shields.io/badge/macOS-14.0%20%7C%2026.0%2B-black?style=for-the-badge&logo=apple&logoColor=white)](https://github.com/Srimi1/Wallps/releases)
[![Windows](https://img.shields.io/badge/Windows-10%20%7C%2011-0078D4?style=for-the-badge&logo=windows&logoColor=white)](https://github.com/Srimi1/Wallps/releases)
[![Apple Silicon](https://img.shields.io/badge/Apple%20Silicon-M1%20%7C%20M2%20%7C%20M3%20%7C%20M4-007AFF?style=for-the-badge&logo=apple&logoColor=white)](https://github.com/Srimi1/Wallps/releases)
[![Privacy](https://img.shields.io/badge/Privacy-Zero%20Telemetry-00C7BE?style=for-the-badge)](SECURITY.md)
[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg?style=for-the-badge)](LICENSE)
[![Release](https://img.shields.io/badge/Release-v1.0.0%20(Official%20Stable)-34C759?style=for-the-badge&logo=apple&logoColor=white)](https://github.com/Srimi1/Wallps/releases/tag/v1.0.0)

[**📸 Showcase**](#-interface--layout-showcase) • [**⚡ Key Features**](#-key-features) • [**🚀 Download**](#-download--installation) • [**📖 Documentation**](#-documentation-index) • [**Release Notes**](CHANGELOG.md) • [**Launch Keynote**](KEYNOTE.md)

</div>

---

> [!TIP]
> **🎉 Wallps 1.0 Multi-Platform Launch**: Wallps is now available for both **macOS (DMG)** and **Windows (EXE)** with 1-click instant switching and the Quantum Prism engine! Read our [Launch Keynote](KEYNOTE.md).

---

## ✨ Overview

**Wallps** is an open-source live wallpaper engine built natively for macOS with SwiftUI and AVFoundation, with a Windows version powered by Electron. It seamlessly renders smooth 4K/8K looping videos behind your desktop icons with minimal CPU & GPU footprint, and gets out of the way instantly when covered by windows or on battery power.

Inspired by modern futuristic minimalism, Wallps combines an **iOS 26 Multi-Dimensional Classification Matrix**, signature **beam-glow borders**, and an interactive **Desktop Simulator** — while staying 100% local, private, and free.

---

## 🏆 Engineering Milestones & Progress Ledger

| Milestone | Status | Key Deliverables & Achievements |
| :--- | :---: | :--- |
| **M0 — macOS Engine Core** | ✅ **Done** | Desktop-level `NSWindow` engine at the wallpaper window layer, AVFoundation/`VideoToolbox` playback, occlusion detector, power & system-state monitors, pure-logic playback policy. |
| **M1 — Futuristic UI/UX Redesign** | ✅ **Done** | Obsidian beam-glow design system, iOS 26 Multi-Dimensional Classification Matrix, Wallpaper Cinema Inspector with live Desktop Simulator HUD, automated DMG packaging pipeline. |
| **Release v1.0.0 — Official Stable** | ✅ **Done** | Quantum Prism app icon, 1-click instant wallpaper application from Gallery/Simulator/Library, persistent Active Control Dock, hardened-runtime signed DMG, **21/21 unit tests passing**, zero-telemetry verification. |
| **M2 — Windows Cross-Platform Release** | ✅ **Done** | Full Electron desktop engine (WorkerW wallpaper integration), real local library, shared playback policy ported to JS, automated Windows release workflow publishing the `.exe` installer. |
| **M3 — Curated Catalog v1** | ✅ **Done** | Published a 10-wallpaper curated catalog (`catalog-v1`) served over plain HTTPS — no server, no API, no accounts; fully self-hostable via [docs/CATALOG.md](docs/CATALOG.md). |
| **M4 — Windows Simulator & Parity** | 🚧 *Next* | Desktop Simulator HUD for Windows matching the macOS inspector experience; multi-display parity polish. |
| **M5 — Community Catalog Growth** | ⬜ *Planned* | Expanded curated collections through the open catalog format and community submissions. |

---

## 📸 Interface & Layout Showcase

### 1. Curated 4K Live Gallery
Explore thousands of high-definition video wallpapers with real-time hardware decoding, tech badges, and one-click desktop application.

![Wallps 4K Live Gallery](docs/assets/gallery_showcase.png)

---

### 2. Wallpaper Cinema & Desktop Simulator HUD
Preview how any live wallpaper looks beneath your actual macOS Top Menu Bar, Bottom Dock, and Desktop icons on Studio Display or MacBook screens before applying. Windows Desktop Simulator coming soon.

![Desktop Simulator & Inspector](docs/assets/desktop_simulator.png)

---

### 3. iOS 26 Multi-Dimensional Classification Matrix
Filter dynamically across **Atmosphere & Mood** (*Neon Glow, Obsidian Dark, Misty Rain, Chill Lofi, Ethereal Sunset, Cosmic Void*), **Display Specs** (*8K, 4K XDR, 4K UHD*), and **Sort Ordering**.

![Classification Matrix](docs/assets/classification_matrix.png)

---

### 4. Local Video Library & Multi-Display Management
Drag and drop your own personal H.264/HEVC/ProRes clips into the library. Assign unique wallpapers per monitor or apply one across all connected displays.

![My Wallpapers Library](docs/assets/my_wallpapers.png)

---

## ⚡ Key Features

- 🎨 **Obsidian Dark & Beam-Glow Design:** Ultra-minimal aesthetics with laser-cut beam borders (`BeamBorder`), frosted glass, and refined typography.
- ⚡ **Hardware-Accelerated Decoding:** Leverages the Apple Silicon Media Engine (`VideoToolbox` & `AVFoundation`) for fluid 60 FPS playback at negligible CPU cost.
- 🔋 **Intelligent Battery & Occlusion Awareness:** Automatically stops decoding video when windows cover the desktop, on battery power, in Low Power Mode, or when displays sleep.
- 🗂️ **iOS 26 Multi-Dimensional Classification:** Smart filtering across categories (*Cyberpunk, Nature, Anime, Minimalist, Cars, Sci-Fi, Rain*), atmosphere moods, and display resolutions.
- 🖥️ **Live Desktop Simulator:** Built-in simulator HUD to test visual harmony with the macOS system UI before applying. Windows version in development.
- 🖱️ **Multi-Monitor Support:** Independent per-screen video wallpaper assignment or synchronized playback across all screens.
- 🌐 **Open Catalog Format:** One JSON file over HTTPS — host your own wallpaper catalog for a team, a community, or just yourself ([docs/CATALOG.md](docs/CATALOG.md)).
- 🔒 **Zero Telemetry & 100% Private:** No analytics, no accounts, no background tracking.

---

## 📊 Comparison Matrix

| Feature | macOS Dynamic Desktop | Wallpaper Engine *(Steam)* | **Wallps** |
| :--- | :---: | :---: | :---: |
| **Custom 4K/8K Video Wallpapers** | ❌ Bundled time-lapses only | ✅ | ✅ **Native AVFoundation** |
| **macOS + Windows from one app** | ❌ macOS only | ❌ Windows only | ✅ **Both platforms** |
| **Price** | Free (built-in) | 💰 Paid on Steam | ✅ **Free & Open Source** |
| **Steam / Account Required** | — | ❌ Steam client required | ✅ **Nothing to sign into** |
| **Battery & Occlusion Auto-Pause** | — | ⚠️ Partial | ✅ **Full power policy** |
| **Zero Telemetry / Zero Tracking** | ⚠️ Telemetry | ❌ Steam telemetry | ✅ **Strictly offline** |

---

## 🔋 How It Works: Battery-Aware Engine

macOS has no public API for "set video as wallpaper", so Wallps positions a borderless, click-through `NSWindow` at `CGWindowLevelForKey(.desktopWindow)`:

```
level -2147483624   system wallpaper (the Dock draws this)
level -2147483623   ← Wallps renders here
level -2147483622   Dock fullscreen backdrop
level -2147483603   desktop icons
level 0             your apps
```

### Power Management Policy

| Condition | Detected via | Default Action |
|---|---|---|
| Covered by a window | `NSWindow` occlusion state **and** a 2s `CGWindowListCopyWindowInfo` poll | **Pause** |
| Screen locked / Screensaver | `DistributedNotificationCenter` (`.deliverImmediately`) | **Always Pause** |
| Displays asleep | `NSWorkspace.screensDidSleep` + `CGDisplayIsAsleep` backstop | **Always Pause** |
| On battery power | IOKit power source notifications | **Pause** |
| Low Power Mode | `ProcessInfo.isLowPowerModeEnabled` | **Pause** |

---

## 🏗️ Project Architecture

```
Wallps/
├── Wallps/
│   ├── App/               # AppState (root coordinator), WallpsApp scenes, AppDelegate
│   ├── Engine/            # WallpaperEngine per-display controllers, WallpaperWindow,
│   │                      #   PlaybackPolicy (pure logic), PowerMonitor, OcclusionDetector
│   ├── Library/           # WallpaperLibrary (local index), CatalogStore, VideoProber,
│   │                      #   ThumbnailGenerator
│   ├── UI/                # DesignSystem (beam glow tokens), ClassificationBar (iOS 26),
│   │                      #   WallpaperInspectorView, GalleryView, LibraryWindow, MenuBar
│   └── Support/           # Preferences, WallpsError
├── windows/
│   └── src/               # Electron main process, WorkerW engine, shared policy port, UI
├── Tests/WallpsTests/     # Occlusion geometry, playback policy & library unit tests
├── scripts/               # DMG packaging, Windows build, icon & screenshot generators
├── docs/                  # Architecture, catalog spec, verification report & assets
├── Makefile               # 1-click bootstrap, build, test, run & dmg commands
└── project.yml            # Declarative XcodeGen project specification
```

---

## 🚀 Download & Installation

### Option 1: Download Pre-built Release (Recommended)

**macOS:** Download the latest `.dmg` from [Releases](https://github.com/Srimi1/Wallps/releases). Mount the disk image and drag **Wallps.app** to your `/Applications` folder.

**Windows:** Download the latest `.exe` installer from [Releases](https://github.com/Srimi1/Wallps/releases). Run the installer and follow the setup wizard.

### Option 2: Build from Source

**macOS Requirements:**
- macOS 14.0 (Sonoma) or later (fully verified on macOS 26)
- Xcode 16.0+
- Apple Silicon or Intel Mac

**Windows Requirements:**
- Windows 10 or Windows 11
- Node.js 18+

```bash
# Clone the repository
git clone https://github.com/Srimi1/Wallps.git
cd Wallps

# macOS: Bootstrap & generate the Xcode project
make bootstrap

# Build, test & run
make test
make run

# Build the release DMG installer
make dmg

# Windows: Install dependencies and build
cd windows
npm install
npm run build:win
```

The resulting DMG installer is output to `build/Wallps.dmg` (macOS) and `build/windows/` (Windows).

---

## 🔒 Security & Privacy

Wallps is engineered from the ground up to respect user privacy and system security:

- 🔒 **No Screen Recording / Accessibility Permissions:** Does not capture screen pixels or intercept user keystrokes/clicks.
- 📁 **Local Media Storage:** All imported videos stay in `~/Library/Application Support/Wallps/`.
- 🛡️ **Apple Hardened Runtime:** Protected against code injection and memory exploits.
- 🚫 **Zero Telemetry:** No analytics SDKs, no crash reporting services, no network calls beyond your own optional catalog URL.

Read our full [Security & Privacy Statement](SECURITY.md).

---

## 📖 Documentation Index

| Document | Purpose |
| :--- | :--- |
| **[KEYNOTE.md](KEYNOTE.md)** | The official Wallps 1.0 launch keynote. |
| **[docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)** | Window levels, playback policy, occlusion & power monitoring internals. |
| **[docs/CATALOG.md](docs/CATALOG.md)** | The self-hostable JSON catalog format specification. |
| **[docs/RELEASE_VERIFICATION_REPORT.md](docs/RELEASE_VERIFICATION_REPORT.md)** | Pre-release standards compliance & verification checklist. |
| **[CHANGELOG.md](CHANGELOG.md)** | Release notes for every published version. |
| **[SECURITY.md](SECURITY.md)** | Security policy & privacy commitments. |

---

## 🤝 Contributing

Contributions are welcome! Please read [CONTRIBUTING.md](CONTRIBUTING.md) and our [Code of Conduct](CODE_OF_CONDUCT.md) before submitting pull requests.

```bash
make bootstrap
make test
```

---

## 📄 License & Privacy

This project is licensed under the **Apache License 2.0** — see the [LICENSE](LICENSE) file for details.  
Read our [Security & Privacy Statement](SECURITY.md) for details on our zero-telemetry commitment.
