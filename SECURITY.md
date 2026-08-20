# Security & Privacy Policy

The **Wallps** project is committed to providing a secure, privacy-first live wallpaper experience for macOS and Windows.

---

## 🔒 Supported Versions

| Version | Supported          | Security Updates |
| ------- | ------------------ | ---------------- |
| 0.1.x / Latest Release | :white_check_mark: | Active           |
| macOS 14.0+ (Sonoma, Sequoia, macOS 26) | :white_check_mark: | Active           |
| Windows 10 / Windows 11 | :white_check_mark: | Active           |

---

## 🛡️ Security Architecture & Privacy Guarantee

Wallps operates under strict privacy and security principles:

1. **Zero Telemetry & Tracking**:
   - Wallps does not contain any analytics, tracking SDKs, or advertising libraries.
   - No user identity, IP address, browsing behavior, or hardware identifiers are logged or sent to any server.

2. **Local-First Storage**:
   - All imported video files and thumbnail caches are stored strictly locally on your machine inside:
     - **macOS:** `~/Library/Application Support/Wallps/`
     - **Windows:** `%APPDATA%\Wallps\`
   - Wallps never uploads your local files to the cloud.

3. **Restricted System Permissions**:
   - **No Screen Recording Permission Required**: Unlike screen-capture wallpaper tools, Wallps uses `CGWindowListCopyWindowInfo` exclusively for window geometry/layer bounds checking to pause playback when covered. It never captures screen pixels or window contents.
   - **No Accessibility Permissions Required**: Clicks pass through the transparent desktop-level window without requiring system accessibility interception.
   - **Hardened Runtime**: Wallps is built with Apple's Hardened Runtime enabled, preventing runtime code injection.

4. **Remote Catalog Safety**:
   - Wallps only downloads catalog metadata and media over secure HTTPS connections.
   - Remote video containers are verified with `AVFoundation` before decoding.

---

## 🚨 Reporting a Vulnerability

If you discover a security vulnerability in Wallps, please do **NOT** open a public issue.

Instead, please report it confidentially via GitHub Security Advisories or by emailing:
`security@wallps.app` (or opening a private security advisory on the GitHub repository).

Please include:
- A description of the issue and potential impact.
- Steps to reproduce the issue or proof-of-concept.
- Your OS version (macOS / Windows) and device architecture (Apple Silicon / Intel / x64).

We will acknowledge receipt within 48 hours and work with you on a responsible disclosure timeline.
