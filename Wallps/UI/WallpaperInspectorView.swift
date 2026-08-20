import AVFoundation
import AppKit
import SwiftUI

/// Futuristic Wallpaper Inspector HUD with live Desktop Simulator and detailed technical specs.
struct WallpaperInspectorView: View {
    @Environment(AppState.self) private var state
    let entry: CatalogEntry
    let onDismiss: () -> Void

    @State private var isSimulatorActive = false
    @State private var simulatorMode: SimulatorMode = .desktop
    @State private var isMuted = true
    @State private var isPlaying = true
    @State private var showAppliedToast = false

    enum SimulatorMode: String, CaseIterable {
        case desktop = "Desktop with Dock"
        case lockScreen = "Lock Screen"
        case clean = "Clean View"
    }

    var body: some View {
        ZStack {
            // Dark Backdrop
            Color.black.opacity(0.85)
                .ignoresSafeArea()
                .onTapGesture { onDismiss() }

            // Main Inspector Floating Window
            VStack(spacing: 0) {
                // Header Bar
                HStack {
                    HStack(spacing: 8) {
                        TechBadge(text: entry.displayResolution, color: Theme.cyberCyan)
                        TechBadge(text: entry.displayFPS, color: Theme.neonEmerald)
                        TechBadge(text: entry.displayMood.uppercased(), color: Theme.cyberPurple)
                    }

                    Spacer()

                    // Simulator Toggle
                    Picker("Preview Mode", selection: $simulatorMode) {
                        ForEach(SimulatorMode.allCases, id: \.self) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 320)

                    Spacer()

                    // Close Button
                    Button {
                        onDismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(Theme.inkSecondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
                .background(Theme.surfaceElevated)
                .overlay(alignment: .bottom) {
                    Divider().background(Theme.hairline)
                }

                // Center: Preview Stage & Simulator
                HStack(spacing: 0) {
                    // Stage View
                    ZStack {
                        // Wallpaper Artwork / Preview
                        AsyncImage(url: entry.preview) { phase in
                            switch phase {
                            case .success(let img):
                                img.resizable()
                                    .aspectRatio(contentMode: .fit)
                            default:
                                Rectangle().fill(Theme.mediaWell)
                                    .overlay(ProgressView().tint(.white))
                            }
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .shadow(color: Color.black.opacity(0.6), radius: 24, x: 0, y: 12)

                        // Simulator Overlay
                        if simulatorMode == .desktop {
                            DesktopMockupOverlay()
                        } else if simulatorMode == .lockScreen {
                            LockScreenMockupOverlay()
                        }

                        // Applied Success Notification Toast
                        if showAppliedToast {
                            VStack {
                                Spacer()
                                HStack(spacing: 8) {
                                    Image(systemName: "checkmark.seal.fill")
                                        .foregroundStyle(Theme.neonEmerald)
                                    Text("Wallpaper applied to your Mac!")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(.white)
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background(Color.black.opacity(0.88))
                                .clipShape(Capsule())
                                .overlay(Capsule().strokeBorder(Theme.neonEmerald.opacity(0.6), lineWidth: 1))
                                .padding(.bottom, 24)
                                .transition(.move(edge: .bottom).combined(with: .opacity))
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(20)
                    .background(Color(red: 0.02, green: 0.02, blue: 0.03))

                    // Right Side: Technical Specs & Action Sidebar
                    VStack(alignment: .leading, spacing: 18) {
                        // Title & Credit
                        VStack(alignment: .leading, spacing: 4) {
                            Text(entry.title)
                                .font(.system(size: 18, weight: .bold))
                                .foregroundStyle(Theme.ink)

                            if let credit = entry.credit {
                                Text("Artwork by \(credit)")
                                    .font(.system(size: 12, weight: .regular))
                                    .foregroundStyle(Theme.inkSecondary)
                            }
                        }

                        Divider().background(Theme.hairline)

                        // Specs Grid
                        VStack(alignment: .leading, spacing: 10) {
                            Text("TECHNICAL DIAGNOSTICS")
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundStyle(Theme.inkTertiary)

                            SpecRow(label: "Resolution", value: entry.displayResolution)
                            SpecRow(label: "Framerate", value: entry.displayFPS)
                            SpecRow(label: "Codec", value: "HEVC / Apple VideoToolbox")
                            SpecRow(label: "Color Profile", value: "Display P3 (Wide Color)")
                            SpecRow(label: "File Size", value: entry.formattedBytes)
                            SpecRow(label: "Hardware Decode", value: "Metal & VNE Accelerated")
                        }

                        // Color Palette Swatches
                        VStack(alignment: .leading, spacing: 8) {
                            Text("DYNAMIC COLOR PALETTE")
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundStyle(Theme.inkTertiary)

                            HStack(spacing: 8) {
                                ColorSwatch(hex: entry.colorHex ?? "#3b4252")
                                ColorSwatch(hex: "#1a1c23")
                                ColorSwatch(hex: "#88c0d0")
                                ColorSwatch(hex: "#ebcb8b")
                            }
                        }

                        Spacer()

                        // Action Buttons
                        VStack(spacing: 10) {
                            let isActive = state.isCatalogEntryActive(entry)
                            // Primary Set Wallpaper
                            Button {
                                state.applyCatalogEntry(entry)
                                withAnimation(Theme.Motion.springStandard) {
                                    showAppliedToast = true
                                }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                                    withAnimation { showAppliedToast = false }
                                }
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: isActive ? "checkmark.circle.fill" : "sparkles.rectangle.stack.fill")
                                    Text(isActive ? "Active on Desktop" : "Set as Live Wallpaper")
                                }
                                .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(FuturisticPrimaryButtonStyle())

                            // Download / Save to Library
                            Button {
                                state.download(entry)
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "arrow.down.circle")
                                    Text(state.library.containsCatalogItem(id: entry.id) ? "Saved in Library" : "Save to Library")
                                }
                                .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(FuturisticGhostButtonStyle())
                        }
                    }
                    .frame(width: 280)
                    .padding(20)
                    .background(Theme.surfaceElevated)
                    .overlay(alignment: .leading) {
                        Divider().background(Theme.hairline)
                    }
                }
            }
            .frame(width: 960, height: 620)
            .background(Theme.backgroundSecondary)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.cardLg, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: Theme.Radius.cardLg, style: .continuous)
                    .strokeBorder(Theme.hairlineStrong, lineWidth: 1)
            }
            .shadow(color: Color.black.opacity(0.8), radius: 40, x: 0, y: 20)
        }
    }
}

// MARK: - Specs & Color Swatches

struct SpecRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 12))
                .foregroundStyle(Theme.inkSecondary)
            Spacer()
            Text(value)
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundStyle(Theme.ink)
        }
    }
}

struct ColorSwatch: View {
    let hex: String

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(Color(hex: hex))
                .frame(width: 14, height: 14)
            Text(hex.uppercased())
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(Theme.inkSecondary)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background(Theme.surface)
        .clipShape(Capsule())
        .overlay(Capsule().strokeBorder(Theme.hairline, lineWidth: 0.5))
    }
}

// MARK: - Simulator Overlays (Realistic macOS Interface)

struct DesktopMockupOverlay: View {
    var body: some View {
        VStack(spacing: 0) {
            // macOS Menu Bar
            HStack(spacing: 12) {
                Image(systemName: "apple.logo")
                    .font(.system(size: 11, weight: .semibold))
                Text("Finder").font(.system(size: 11, weight: .bold))
                Text("File").font(.system(size: 11, weight: .regular))
                Text("Edit").font(.system(size: 11, weight: .regular))
                Text("View").font(.system(size: 11, weight: .regular))
                Text("Window").font(.system(size: 11, weight: .regular))
                Text("Help").font(.system(size: 11, weight: .regular))

                Spacer()

                Image(systemName: "wifi").font(.system(size: 10))
                Image(systemName: "battery.100").font(.system(size: 10))
                Image(systemName: "magnifyingglass").font(.system(size: 10))
                Image(systemName: "switch.2").font(.system(size: 10))
                Text("Thu 10:42 PM").font(.system(size: 11, weight: .medium))
            }
            .foregroundStyle(.white.opacity(0.85))
            .padding(.horizontal, 14)
            .padding(.vertical, 4)
            .background(Color.black.opacity(0.4).background(.ultraThinMaterial))

            // Desktop Area with Sample Icons
            HStack {
                Spacer()
                VStack(spacing: 16) {
                    DesktopIcon(title: "Macintosh HD", icon: "internaldrive.fill")
                    DesktopIcon(title: "Wallpapers", icon: "folder.fill")
                    DesktopIcon(title: "Projects", icon: "folder.fill")
                }
                .padding(.trailing, 16)
                .padding(.top, 16)
            }

            Spacer()

            // macOS Dock
            HStack(spacing: 8) {
                DockIcon(icon: "finder", isSystem: false)
                DockIcon(icon: "safari", isSystem: false)
                DockIcon(icon: "terminal.fill", isSystem: true)
                DockIcon(icon: "hammer.fill", isSystem: true)
                DockIcon(icon: "photo.on.rectangle.angled", isSystem: true)
                DockIcon(icon: "gearshape.fill", isSystem: true)
                Divider().frame(height: 24).background(Color.white.opacity(0.2))
                DockIcon(icon: "trash.fill", isSystem: true)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.black.opacity(0.5).background(.ultraThinMaterial))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Color.white.opacity(0.2), lineWidth: 0.5))
            .padding(.bottom, 8)
        }
        .allowsHitTesting(false)
    }
}

struct LockScreenMockupOverlay: View {
    var body: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "lock.fill")
                .font(.system(size: 18))
                .foregroundStyle(.white.opacity(0.8))
            Text("Thursday, August 20")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.white.opacity(0.9))
            Text("10:42")
                .font(.system(size: 64, weight: .thin, design: .rounded))
                .foregroundStyle(.white)
            Spacer()
            HStack(spacing: 12) {
                Image(systemName: "person.crop.circle.fill")
                    .font(.system(size: 38))
                    .foregroundStyle(.white.opacity(0.8))
                Text("MacBook Pro")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white)
            }
            .padding(.bottom, 28)
        }
        .allowsHitTesting(false)
    }
}

struct DesktopIcon: View {
    let title: String
    let icon: String

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 26))
                .foregroundStyle(Theme.cyberCyan)
            Text(title)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.white)
                .shadow(color: .black, radius: 2)
        }
    }
}

struct DockIcon: View {
    let icon: String
    let isSystem: Bool

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.white.opacity(0.15))
                .frame(width: 32, height: 32)
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(.white)
        }
    }
}

// MARK: - Color Hex Helper

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 128, 128, 128)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
