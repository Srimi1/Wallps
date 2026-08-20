# 🌌 Wallps 1.0 — The Official Launch Keynote

<div align="center">

<img src="docs/assets/app_icon.png" width="160" height="160" alt="Wallps 1.0 Icon" style="border-radius: 36px; margin-bottom: 12px; box-shadow: 0 20px 40px rgba(0,0,0,0.6);" />

# Introducing Wallps 1.0
### *The Next Generation 4K Live Wallpaper Experience for macOS*

**Universal Release · Native Apple Silicon & Intel · Zero Telemetry · Open Source**

[![Version](https://img.shields.io/badge/Version-1.0.0%20GA-34C759?style=for-the-badge&logo=apple&logoColor=white)](https://github.com/Srimi1/Wallps/releases/tag/v1.0.0)
[![macOS](https://img.shields.io/badge/macOS-14.0%20%7C%2026.0%2B-black?style=for-the-badge&logo=apple&logoColor=white)](https://github.com/Srimi1/Wallps/releases/tag/v1.0.0)
[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg?style=for-the-badge)](LICENSE)

[**Download Wallps 1.0 (.DMG)**](https://github.com/Srimi1/Wallps/releases/tag/v1.0.0) • [**Source Code**](https://github.com/Srimi1/Wallps) • [**Verification Report**](docs/RELEASE_VERIFICATION_REPORT.md)

</div>

---

## 🌟 The Vision

Your Mac desktop is the canvas you look at every single day. For too long, live wallpaper software on macOS has suffered from three major flaws: **high battery drain**, **bloated, complex interfaces**, and **invasive tracking**.

**Wallps 1.0** changes everything. 

Built strictly from the ground up for macOS using native **SwiftUI**, **Metal**, and **VideoToolbox**, Wallps delivers stunning 4K and 8K motion wallpapers that feel like a native part of macOS. It plays fluidly at 60 FPS when you are looking at it, and instantly vanishes to 0% CPU the moment your windows cover it or when you run on battery.

---

## 🚀 What Makes Wallps 1.0 Revolutionary

### 1. ⚡ Instant 1-Click Desktop Switching
No waiting, no hunting through folders, and no restarts. Single-click **"Set as Wallpaper"** or double-click any card in the gallery, and your desktop background transforms in real-time.

### 2. 🎛️ iOS 26 Multi-Dimensional Classification Matrix
Navigate through thousands of curated wallpapers effortlessly. Filter across three distinct dimensions:
- **Atmosphere & Mood**: *Neon Glow, Obsidian Dark, Misty Rain, Chill Lofi, Ethereal Sunset, Cosmic Void, Solar Gold*
- **Display Specs**: *8K Ultra, 4K XDR, 4K UHD, Studio Display 5K*
- **Sort & Flow**: *Trending, Newest Drops, Highest Resolution*

### 3. 🖥️ Wallpaper Cinema & Live Desktop Simulator
Never guess how a wallpaper will look beneath your apps again. The built-in **macOS Desktop Simulator** lets you preview any artwork underneath realistic macOS Menu Bars, Docks, and Desktop Icons before applying.

### 4. 🔋 Battery-Aware Occlusion Engine
Wallps places a transparent, click-through window at the desktop window level (`CGWindowLevelForKey(.desktopWindow)`). Using dual-signal occlusion detection, the engine pauses decoding whenever:
- Windows cover the screen
- Your Mac is on battery power or in Low Power Mode
- The screen locks or displays sleep

### 5. 💎 The Quantum Prism Icon
A custom icon rendered across all display resolutions ($16\times16$ to $1024\times1024$ Retina) that reflects the precision, depth, and futuristic spirit of Wallps.

---

## 📸 Interface Showcase

<div align="center">

| 4K Live Gallery & Classification | Wallpaper Cinema Inspector |
| :---: | :---: |
| ![Gallery](docs/assets/gallery_showcase.png) | ![Inspector](docs/assets/desktop_simulator.png) |

| Multi-Dimensional Filter Matrix | My Wallpapers Library |
| :---: | :---: |
| ![Matrix](docs/assets/classification_matrix.png) | ![Library](docs/assets/my_wallpapers.png) |

</div>

---

## 🔒 Security & Privacy by Design

- **Zero Telemetry**: No tracking, no user profiles, no network snooping.
- **Strict Hardened Runtime**: Sandboxed with minimal entitlements (`app-sandbox`, `user-selected.read-only`, `network.client`).
- **No Screen Recording Permissions Required**: Checks window geometry layers with zero pixel scraping.
- **Local-First Storage**: Your imported videos stay strictly on your Mac.

---

## 📥 Get Wallps 1.0 Today

### 1. Download DMG Installer
Download the verified, pre-built disk image from the [v1.0.0 Release Page](https://github.com/Srimi1/Wallps/releases/tag/v1.0.0).

### 2. Install & Run
Open `Wallps.dmg` and drag `Wallps.app` to your `/Applications` folder.

```sh
# Or build directly from source:
git clone https://github.com/Srimi1/Wallps.git
cd Wallps
make run
```

---

*Thank you to everyone who supported the creation of Wallps 1.0!*
