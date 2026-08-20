import AppKit
import SwiftUI

// MARK: - Screenshot Generator for Wallps
// Renders pixel-perfect macOS 26 retina UI screenshots for repository documentation.

@MainActor
func saveImage<Content: View>(view: Content, to path: String, width: CGFloat = 1120, height: CGFloat = 720) {
    let container = view
        .frame(width: width, height: height)
        .background(Color(red: 0.03, green: 0.03, blue: 0.04))

    let renderer = ImageRenderer(content: container)
    renderer.scale = 2.0 // Retina 2x

    if let nsImage = renderer.nsImage,
       let tiff = nsImage.tiffRepresentation,
       let bitmap = NSBitmapImageRep(data: tiff),
       let png = bitmap.representation(using: .png, properties: [:]) {
        let url = URL(fileURLWithPath: path)
        try? png.write(to: url)
        print("Generated screenshot: \(path) (\(Int(width))x\(Int(height)) @ 2x)")
    } else {
        print("Failed to render \(path)")
    }
}

// MARK: - Mock Models & Data

struct MockEntry: Identifiable {
    let id: String
    let title: String
    let category: String
    let resolution: String
    let mood: String
    let fps: String
    let size: String
    let credit: String
    let gradientColors: [Color]
    let colorHex: String
}

let mockWallpapers: [MockEntry] = [
    MockEntry(
        id: "1",
        title: "Gathering Storm",
        category: "Nature",
        resolution: "4K XDR",
        mood: "Misty Rain",
        fps: "60 FPS",
        size: "52 MB",
        credit: "Wallper Studios",
        gradientColors: [Color(red: 0.15, green: 0.20, blue: 0.28), Color(red: 0.05, green: 0.08, blue: 0.14)],
        colorHex: "#3B4252"
    ),
    MockEntry(
        id: "2",
        title: "NTE - Zankou Neon Tokyo",
        category: "Cyberpunk",
        resolution: "4K UHD",
        mood: "Neon Glow",
        fps: "60 FPS",
        size: "61 MB",
        credit: "Zankou Art",
        gradientColors: [Color(red: 0.35, green: 0.10, blue: 0.50), Color(red: 0.05, green: 0.30, blue: 0.55)],
        colorHex: "#81A1C1"
    ),
    MockEntry(
        id: "3",
        title: "Snow & Cherry Blossoms",
        category: "Minimalist",
        resolution: "8K Ultra",
        mood: "Chill Lofi",
        fps: "60 FPS",
        size: "44 MB",
        credit: "Kumo Design",
        gradientColors: [Color(red: 0.70, green: 0.40, blue: 0.55), Color(red: 0.15, green: 0.15, blue: 0.25)],
        colorHex: "#E5E9F0"
    ),
    MockEntry(
        id: "4",
        title: "BMW M3 GTR Night Drift",
        category: "Cars",
        resolution: "4K UHD",
        mood: "Neon Glow",
        fps: "60 FPS",
        size: "53 MB",
        credit: "NFS Garage",
        gradientColors: [Color(red: 0.10, green: 0.35, blue: 0.45), Color(red: 0.02, green: 0.05, blue: 0.12)],
        colorHex: "#88C0D0"
    ),
    MockEntry(
        id: "5",
        title: "Cosmic Odyssey & Nebulae",
        category: "Sci-Fi",
        resolution: "4K XDR",
        mood: "Cosmic Void",
        fps: "60 FPS",
        size: "73 MB",
        credit: "Cosmic Archive",
        gradientColors: [Color(red: 0.45, green: 0.15, blue: 0.40), Color(red: 0.08, green: 0.02, blue: 0.20)],
        colorHex: "#B48EAD"
    ),
    MockEntry(
        id: "6",
        title: "Rainy Night Window Cafe",
        category: "Rain & Atmosphere",
        resolution: "4K XDR",
        mood: "Misty Rain",
        fps: "60 FPS",
        size: "47 MB",
        credit: "Lofi Ambience Lab",
        gradientColors: [Color(red: 0.12, green: 0.18, blue: 0.25), Color(red: 0.04, green: 0.06, blue: 0.09)],
        colorHex: "#4C566A"
    )
]

// MARK: - Screenshot Views

struct TopBarView: View {
    var activeTab: String = "Explore Gallery"

    var body: some View {
        HStack(spacing: 16) {
            HStack(spacing: 8) {
                Image(systemName: "photo.on.rectangle.angled")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Color(red: 0.20, green: 0.85, blue: 1.0))
                Text("WALLPS")
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white)
                Text("PRO")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(Color(red: 0.20, green: 0.85, blue: 1.0))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color(red: 0.20, green: 0.85, blue: 1.0).opacity(0.12))
                    .clipShape(Capsule())
            }

            Spacer()

            HStack(spacing: 4) {
                NavTabButton(title: "Explore Gallery", icon: "sparkles", isSelected: activeTab == "Explore Gallery")
                NavTabButton(title: "My Wallpapers", icon: "square.grid.2x2.fill", isSelected: activeTab == "My Wallpapers")
            }
            .padding(4)
            .background(Color.white.opacity(0.05))
            .clipShape(Capsule())
            .overlay(Capsule().strokeBorder(Color.white.opacity(0.1), lineWidth: 0.5))

            Spacer()

            HStack(spacing: 10) {
                HStack(spacing: 6) {
                    Image(systemName: "display.2")
                        .font(.system(size: 11, weight: .semibold))
                    Text("All Displays (2)")
                        .font(.system(size: 11, weight: .medium))
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 8))
                }
                .foregroundStyle(Color.white.opacity(0.65))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.white.opacity(0.05))
                .clipShape(Capsule())
                .overlay(Capsule().strokeBorder(Color.white.opacity(0.1), lineWidth: 0.5))

                HStack(spacing: 5) {
                    Circle()
                        .fill(Color(red: 0.20, green: 0.95, blue: 0.65))
                        .frame(width: 6, height: 6)
                    Text("60 FPS")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(Color(red: 0.20, green: 0.95, blue: 0.65))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(Color.white.opacity(0.05))
                .clipShape(Capsule())
                .overlay(Capsule().strokeBorder(Color.white.opacity(0.1), lineWidth: 0.5))
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
        .background(Color(red: 0.05, green: 0.05, blue: 0.07).opacity(0.95))
        .overlay(alignment: .bottom) {
            Divider().background(Color.white.opacity(0.09))
        }
    }
}

struct NavTabButton: View {
    let title: String
    let icon: String
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon).font(.system(size: 11, weight: .semibold))
            Text(title).font(.system(size: 12, weight: isSelected ? .semibold : .medium))
        }
        .foregroundStyle(isSelected ? .black : Color.white.opacity(0.65))
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
        .background(isSelected ? Color.white : Color.clear)
        .clipShape(Capsule())
    }
}

struct HeroSectionView: View {
    var body: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text("LIVE 4K GALLERY")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundStyle(Color(red: 0.20, green: 0.85, blue: 1.0))

                    HStack(spacing: 4) {
                        Circle().fill(Color(red: 0.20, green: 0.95, blue: 0.65)).frame(width: 6, height: 6)
                        Text("macOS 26 READY")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundStyle(Color(red: 0.20, green: 0.95, blue: 0.65))
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color(red: 0.20, green: 0.95, blue: 0.65).opacity(0.12))
                    .clipShape(Capsule())
                }

                Text("Curated 4K Live Wallpapers")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(.white)

                Text("Ultra-high definition video backgrounds optimized for Apple Silicon, Studio Display & Pro Display XDR.")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(Color.white.opacity(0.65))
                    .frame(maxWidth: 580, alignment: .leading)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text("2,719")
                    .font(.system(size: 26, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white)
                Text("CURATED ASSETS")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(Color.white.opacity(0.38))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color(red: 0.08, green: 0.08, blue: 0.11))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.1), lineWidth: 0.5)
            )
        }
    }
}

struct ClassificationBarView: View {
    var selectedCat: String = "Cyberpunk"

    var body: some View {
        HStack(spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color(red: 0.20, green: 0.85, blue: 1.0))
                Text("Search 4K live wallpapers…")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(Color.white.opacity(0.35))
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .frame(width: 240)
            .background(Color.white.opacity(0.04))
            .clipShape(Capsule())
            .overlay(Capsule().strokeBorder(Color.white.opacity(0.09), lineWidth: 0.5))

            HStack(spacing: 8) {
                ForEach(["All", "Cyberpunk", "Nature", "Anime", "Minimalist", "Gaming", "Cars", "Sci-Fi"], id: \.self) { cat in
                    let isSel = (cat == selectedCat)
                    Text(cat)
                        .font(.system(size: 12, weight: isSel ? .semibold : .medium))
                        .foregroundStyle(isSel ? .black : .white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(isSel ? Color.white : Color.white.opacity(0.04))
                        .clipShape(Capsule())
                        .overlay(Capsule().strokeBorder(isSel ? Color.clear : Color.white.opacity(0.09), lineWidth: 0.5))
                }
            }

            Spacer()

            HStack(spacing: 8) {
                HStack(spacing: 5) {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 11, weight: .semibold))
                    Text("Filters")
                        .font(.system(size: 12, weight: .medium))
                    Circle()
                        .fill(Color(red: 0.20, green: 0.85, blue: 1.0))
                        .frame(width: 6, height: 6)
                }
                .foregroundStyle(Color(red: 0.20, green: 0.85, blue: 1.0))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.white.opacity(0.08))
                .clipShape(Capsule())
                .overlay(Capsule().strokeBorder(Color(red: 0.20, green: 0.85, blue: 1.0).opacity(0.4), lineWidth: 0.5))
            }
        }
    }
}

struct CardItemView: View {
    let item: MockEntry
    var isHovered: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack(alignment: .bottom) {
                ZStack(alignment: .topTrailing) {
                    LinearGradient(
                        colors: item.gradientColors,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .overlay {
                        Circle()
                            .fill(item.gradientColors[0].opacity(0.4))
                            .blur(radius: 40)
                            .offset(x: -40, y: -20)
                    }

                    HStack(spacing: 4) {
                        Text(item.resolution)
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundStyle(Color(red: 0.20, green: 0.85, blue: 1.0))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Color(red: 0.20, green: 0.85, blue: 1.0).opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: 4))

                        Text(item.fps)
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundStyle(Color(red: 0.20, green: 0.95, blue: 0.65))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Color(red: 0.20, green: 0.95, blue: 0.65).opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                    .padding(8)
                }
                .aspectRatio(16 / 9, contentMode: .fill)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                if isHovered {
                    HStack(spacing: 8) {
                        HStack(spacing: 5) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 11, weight: .bold))
                            Text("Set Wallpaper")
                                .font(.system(size: 11, weight: .semibold))
                        }
                        .foregroundStyle(.black)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(Color.white)
                        .clipShape(Capsule())

                        Image(systemName: "eye.fill")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(8)
                            .background(Color.white.opacity(0.08))
                            .clipShape(Capsule())
                            .overlay(Capsule().strokeBorder(Color.white.opacity(0.2), lineWidth: 0.5))
                    }
                    .padding(.horizontal, 10)
                    .padding(.bottom, 10)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                if isHovered {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(Color(red: 0.20, green: 0.85, blue: 1.0).opacity(0.8), lineWidth: 1.2)
                } else {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.09), lineWidth: 0.5)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(item.title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Spacer()
                    Text(item.mood)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.38))
                }

                HStack(spacing: 6) {
                    Text(item.category)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.65))
                    Text("·").foregroundStyle(Color.white.opacity(0.20))
                    Text(item.size)
                        .font(.system(size: 11, weight: .regular, design: .monospaced))
                        .foregroundStyle(Color.white.opacity(0.38))
                    Text("·").foregroundStyle(Color.white.opacity(0.20))
                    Text(item.credit)
                        .font(.system(size: 11, weight: .regular))
                        .foregroundStyle(Color.white.opacity(0.38))
                }
            }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(isHovered ? Color.white.opacity(0.08) : Color.white.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(isHovered ? Color.white.opacity(0.22) : Color.white.opacity(0.09), lineWidth: 0.5)
                )
        )
    }
}

// 1. Gallery Screenshot
struct GalleryScreenshotView: View {
    var body: some View {
        VStack(spacing: 0) {
            TopBarView(activeTab: "Explore Gallery")

            VStack(alignment: .leading, spacing: 18) {
                HeroSectionView()
                ClassificationBarView(selectedCat: "Cyberpunk")

                LazyVGrid(columns: [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)], spacing: 16) {
                    CardItemView(item: mockWallpapers[0])
                    CardItemView(item: mockWallpapers[1], isHovered: true)
                    CardItemView(item: mockWallpapers[2])
                    CardItemView(item: mockWallpapers[3])
                    CardItemView(item: mockWallpapers[4])
                    CardItemView(item: mockWallpapers[5])
                }
            }
            .padding(24)

            Spacer()
        }
        .background(Color(red: 0.03, green: 0.03, blue: 0.04))
    }
}

// 2. Desktop Simulator Inspector Screenshot
struct InspectorScreenshotView: View {
    var body: some View {
        ZStack {
            GalleryScreenshotView()
                .blur(radius: 8)
                .overlay(Color.black.opacity(0.65))

            // Modal Floating HUD
            VStack(spacing: 0) {
                // Header Bar
                HStack {
                    HStack(spacing: 8) {
                        Text("4K XDR")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundStyle(Color(red: 0.20, green: 0.85, blue: 1.0))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Color(red: 0.20, green: 0.85, blue: 1.0).opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: 4))

                        Text("60 FPS")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundStyle(Color(red: 0.20, green: 0.95, blue: 0.65))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Color(red: 0.20, green: 0.95, blue: 0.65).opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: 4))

                        Text("NEON GLOW")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundStyle(Color(red: 0.65, green: 0.35, blue: 1.0))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Color(red: 0.65, green: 0.35, blue: 1.0).opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    }

                    Spacer()

                    HStack(spacing: 4) {
                        Text("Desktop Simulator")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.black)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 5)
                            .background(Color.white)
                            .clipShape(Capsule())

                        Text("Clean View")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(Color.white.opacity(0.65))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 5)
                    }
                    .padding(3)
                    .background(Color.white.opacity(0.06))
                    .clipShape(Capsule())

                    Spacer()

                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(Color.white.opacity(0.5))
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(Color(red: 0.08, green: 0.08, blue: 0.11))

                Divider().background(Color.white.opacity(0.09))

                // Center Stage + Sidebar
                HStack(spacing: 0) {
                    // Simulated macOS Desktop Stage
                    ZStack {
                        LinearGradient(
                            colors: [Color(red: 0.35, green: 0.10, blue: 0.50), Color(red: 0.05, green: 0.30, blue: 0.55)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )

                        // Top Menu Bar Simulation
                        VStack(spacing: 0) {
                            HStack(spacing: 12) {
                                Image(systemName: "apple.logo").font(.system(size: 11, weight: .semibold))
                                Text("Finder").font(.system(size: 11, weight: .bold))
                                Text("File").font(.system(size: 11, weight: .regular))
                                Text("Edit").font(.system(size: 11, weight: .regular))
                                Text("View").font(.system(size: 11, weight: .regular))
                                Text("Window").font(.system(size: 11, weight: .regular))
                                Spacer()
                                Image(systemName: "wifi").font(.system(size: 10))
                                Image(systemName: "battery.100").font(.system(size: 10))
                                Image(systemName: "switch.2").font(.system(size: 10))
                                Text("Thu 10:42 PM").font(.system(size: 11, weight: .medium))
                            }
                            .foregroundStyle(.white.opacity(0.9))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 4)
                            .background(Color.black.opacity(0.4))

                            Spacer()

                            // Desktop Icons
                            HStack {
                                Spacer()
                                VStack(spacing: 14) {
                                    VStack(spacing: 3) {
                                        Image(systemName: "internaldrive.fill")
                                            .font(.system(size: 24))
                                            .foregroundStyle(Color(red: 0.20, green: 0.85, blue: 1.0))
                                        Text("Macintosh HD").font(.system(size: 9, weight: .medium)).foregroundStyle(.white)
                                    }
                                    VStack(spacing: 3) {
                                        Image(systemName: "folder.fill")
                                            .font(.system(size: 24))
                                            .foregroundStyle(Color(red: 0.20, green: 0.85, blue: 1.0))
                                        Text("Wallpapers").font(.system(size: 9, weight: .medium)).foregroundStyle(.white)
                                    }
                                }
                                .padding(.trailing, 16)
                            }

                            Spacer()

                            // macOS Dock Simulation
                            HStack(spacing: 8) {
                                Image(systemName: "finder").frame(width: 28, height: 28).background(Color.white.opacity(0.2)).clipShape(RoundedRectangle(cornerRadius: 6))
                                Image(systemName: "safari").frame(width: 28, height: 28).background(Color.white.opacity(0.2)).clipShape(RoundedRectangle(cornerRadius: 6))
                                Image(systemName: "terminal.fill").frame(width: 28, height: 28).background(Color.white.opacity(0.2)).clipShape(RoundedRectangle(cornerRadius: 6))
                                Image(systemName: "photo.on.rectangle.angled").frame(width: 28, height: 28).background(Color.white.opacity(0.2)).clipShape(RoundedRectangle(cornerRadius: 6))
                                Image(systemName: "gearshape.fill").frame(width: 28, height: 28).background(Color.white.opacity(0.2)).clipShape(RoundedRectangle(cornerRadius: 6))
                            }
                            .foregroundStyle(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color.black.opacity(0.55))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .padding(.bottom, 8)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .padding(14)
                    .background(Color(red: 0.02, green: 0.02, blue: 0.03))

                    // Sidebar
                    VStack(alignment: .leading, spacing: 16) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("NTE - Zankou Neon Tokyo")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(.white)
                            Text("Artwork by Zankou Art")
                                .font(.system(size: 12, weight: .regular))
                                .foregroundStyle(Color.white.opacity(0.65))
                        }

                        Divider().background(Color.white.opacity(0.09))

                        VStack(alignment: .leading, spacing: 8) {
                            Text("TECHNICAL DIAGNOSTICS")
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .foregroundStyle(Color.white.opacity(0.38))

                            HStack { Text("Resolution").font(.system(size: 11)).foregroundStyle(Color.white.opacity(0.65)); Spacer(); Text("3840×2160 (4K XDR)").font(.system(size: 11, weight: .medium, design: .monospaced)).foregroundStyle(.white) }
                            HStack { Text("Framerate").font(.system(size: 11)).foregroundStyle(Color.white.opacity(0.65)); Spacer(); Text("60.0 FPS Smooth").font(.system(size: 11, weight: .medium, design: .monospaced)).foregroundStyle(.white) }
                            HStack { Text("Codec").font(.system(size: 11)).foregroundStyle(Color.white.opacity(0.65)); Spacer(); Text("HEVC VideoToolbox").font(.system(size: 11, weight: .medium, design: .monospaced)).foregroundStyle(.white) }
                            HStack { Text("Color Space").font(.system(size: 11)).foregroundStyle(Color.white.opacity(0.65)); Spacer(); Text("Display P3 Wide").font(.system(size: 11, weight: .medium, design: .monospaced)).foregroundStyle(.white) }
                            HStack { Text("File Size").font(.system(size: 11)).foregroundStyle(Color.white.opacity(0.65)); Spacer(); Text("61.8 MB").font(.system(size: 11, weight: .medium, design: .monospaced)).foregroundStyle(.white) }
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            Text("COLOR PALETTE")
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .foregroundStyle(Color.white.opacity(0.38))

                            HStack(spacing: 6) {
                                ForEach(["#81A1C1", "#3B4252", "#B48EAD", "#E5E9F0"], id: \.self) { hex in
                                    Text(hex)
                                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                                        .foregroundStyle(.white)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 3)
                                        .background(Color.white.opacity(0.08))
                                        .clipShape(Capsule())
                                }
                            }
                        }

                        Spacer()

                        VStack(spacing: 8) {
                            HStack(spacing: 6) {
                                Image(systemName: "sparkles.rectangle.stack.fill")
                                Text("Set as Live Wallpaper")
                            }
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(Color.white)
                            .clipShape(Capsule())

                            HStack(spacing: 6) {
                                Image(systemName: "arrow.down.circle")
                                Text("Save to Library")
                            }
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 7)
                            .background(Color.white.opacity(0.06))
                            .clipShape(Capsule())
                            .overlay(Capsule().strokeBorder(Color.white.opacity(0.12), lineWidth: 0.5))
                        }
                    }
                    .frame(width: 250)
                    .padding(18)
                    .background(Color(red: 0.08, green: 0.08, blue: 0.11))
                }
            }
            .frame(width: 860, height: 520)
            .background(Color(red: 0.05, green: 0.05, blue: 0.07))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(Color.white.opacity(0.2), lineWidth: 1))
            .shadow(color: Color.black.opacity(0.9), radius: 40, x: 0, y: 20)
        }
    }
}

// 3. Classification Matrix Expanded Screenshot
struct MatrixScreenshotView: View {
    var body: some View {
        VStack(spacing: 0) {
            TopBarView(activeTab: "Explore Gallery")

            VStack(alignment: .leading, spacing: 16) {
                ClassificationBarView(selectedCat: "All")

                // Expanded iOS 26 Matrix
                VStack(alignment: .leading, spacing: 14) {
                    HStack(alignment: .top, spacing: 32) {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 4) {
                                Image(systemName: "sparkles").font(.system(size: 9, weight: .bold))
                                Text("ATMOSPHERE & MOOD").font(.system(size: 10, weight: .bold, design: .monospaced))
                            }
                            .foregroundStyle(Color.white.opacity(0.38))

                            HStack(spacing: 6) {
                                ForEach(["Neon Glow", "Obsidian Dark", "Misty Rain", "Chill Lofi", "Ethereal Sunset", "Cosmic Void"], id: \.self) { mood in
                                    Text(mood)
                                        .font(.system(size: 11))
                                        .foregroundStyle(mood == "Neon Glow" ? Color(red: 0.20, green: 0.85, blue: 1.0) : Color.white.opacity(0.65))
                                        .padding(.horizontal, 9)
                                        .padding(.vertical, 4)
                                        .background(mood == "Neon Glow" ? Color(red: 0.20, green: 0.85, blue: 1.0).opacity(0.15) : Color.white.opacity(0.04))
                                        .clipShape(RoundedRectangle(cornerRadius: 6))
                                }
                            }
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 4) {
                                Image(systemName: "display").font(.system(size: 9, weight: .bold))
                                Text("DISPLAY & SPECS").font(.system(size: 10, weight: .bold, design: .monospaced))
                            }
                            .foregroundStyle(Color.white.opacity(0.38))

                            HStack(spacing: 6) {
                                ForEach(["8K Ultra", "4K XDR", "4K UHD"], id: \.self) { res in
                                    Text(res)
                                        .font(.system(size: 11))
                                        .foregroundStyle(res == "4K XDR" ? Color(red: 0.20, green: 0.85, blue: 1.0) : Color.white.opacity(0.65))
                                        .padding(.horizontal, 9)
                                        .padding(.vertical, 4)
                                        .background(res == "4K XDR" ? Color(red: 0.20, green: 0.85, blue: 1.0).opacity(0.15) : Color.white.opacity(0.04))
                                        .clipShape(RoundedRectangle(cornerRadius: 6))
                                }
                            }
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.up.arrow.down").font(.system(size: 9, weight: .bold))
                                Text("SORT & FLOW").font(.system(size: 10, weight: .bold, design: .monospaced))
                            }
                            .foregroundStyle(Color.white.opacity(0.38))

                            HStack(spacing: 6) {
                                ForEach(["Trending", "Newest Drops", "Highest Resolution"], id: \.self) { sort in
                                    Text(sort)
                                        .font(.system(size: 11))
                                        .foregroundStyle(sort == "Trending" ? Color(red: 0.20, green: 0.85, blue: 1.0) : Color.white.opacity(0.65))
                                        .padding(.horizontal, 9)
                                        .padding(.vertical, 4)
                                        .background(sort == "Trending" ? Color(red: 0.20, green: 0.85, blue: 1.0).opacity(0.15) : Color.white.opacity(0.04))
                                        .clipShape(RoundedRectangle(cornerRadius: 6))
                                }
                            }
                        }
                    }
                }
                .padding(16)
                .background(Color(red: 0.08, green: 0.08, blue: 0.11))
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.white.opacity(0.15), lineWidth: 0.5))

                // Cards Preview
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)], spacing: 16) {
                    CardItemView(item: mockWallpapers[1], isHovered: true)
                    CardItemView(item: mockWallpapers[0])
                    CardItemView(item: mockWallpapers[4])
                }
            }
            .padding(24)
        }
        .background(Color(red: 0.03, green: 0.03, blue: 0.04))
    }
}

// 4. My Wallpapers Screenshot
struct MyWallpapersScreenshotView: View {
    var body: some View {
        VStack(spacing: 0) {
            TopBarView(activeTab: "My Wallpapers")

            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("My Wallpaper Library")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundStyle(.white)
                        Text("4 imported live wallpapers stored locally in Application Support")
                            .font(.system(size: 13))
                            .foregroundStyle(Color.white.opacity(0.65))
                    }

                    Spacer()

                    HStack(spacing: 6) {
                        Image(systemName: "plus.circle.fill")
                        Text("Add Video…")
                    }
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.white)
                    .clipShape(Capsule())
                }

                LazyVGrid(columns: [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)], spacing: 16) {
                    CardItemView(item: mockWallpapers[0], isHovered: false)
                    CardItemView(item: mockWallpapers[1], isHovered: false)
                    CardItemView(item: mockWallpapers[2], isHovered: false)
                    CardItemView(item: mockWallpapers[3], isHovered: false)
                }

                Spacer()
            }
            .padding(24)
        }
        .background(Color(red: 0.03, green: 0.03, blue: 0.04))
    }
}

// MARK: - Main Execution

Task { @MainActor in
    let assetsDir = "docs/assets"
    try? FileManager.default.createDirectory(atPath: assetsDir, withIntermediateDirectories: true)

    saveImage(view: GalleryScreenshotView(), to: "\(assetsDir)/gallery_showcase.png")
    saveImage(view: InspectorScreenshotView(), to: "\(assetsDir)/desktop_simulator.png")
    saveImage(view: MatrixScreenshotView(), to: "\(assetsDir)/classification_matrix.png")
    saveImage(view: MyWallpapersScreenshotView(), to: "\(assetsDir)/my_wallpapers.png")

    print("All screenshots generated successfully in \(assetsDir)/")
    exit(0)
}

RunLoop.main.run()
