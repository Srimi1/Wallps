import SwiftUI

/// Futuristic Minimal design tokens inspired by Wallper.app & iOS 26.
/// Monochrome obsidian foundation with laser-cut beam borders, ultra-thin
/// frosted glass, and refined typography.
enum Theme {
    // MARK: - Surface

    /// Deep Obsidian black background.
    static let background = Color(red: 0.03, green: 0.03, blue: 0.04)
    static let backgroundSecondary = Color(red: 0.06, green: 0.06, blue: 0.08)
    
    /// Ultra-thin frosted glass fills.
    static let surface = Color.white.opacity(0.04)
    static let surfaceHover = Color.white.opacity(0.08)
    static let surfaceActive = Color.white.opacity(0.12)
    static let surfaceElevated = Color(red: 0.09, green: 0.09, blue: 0.12).opacity(0.85)
    
    /// Media placeholder well.
    static let mediaWell = Color(red: 0.04, green: 0.04, blue: 0.06)

    // MARK: - Accents & Futuristic Glows

    static let cyberCyan = Color(red: 0.20, green: 0.85, blue: 1.0)
    static let cyberPurple = Color(red: 0.65, green: 0.35, blue: 1.0)
    static let neonEmerald = Color(red: 0.20, green: 0.95, blue: 0.65)
    static let solarAmber = Color(red: 1.0, green: 0.65, blue: 0.20)
    static let electricBlue = Color(red: 0.25, green: 0.55, blue: 1.0)

    // MARK: - Ink

    static let ink = Color.white
    static let inkSecondary = Color.white.opacity(0.65)
    static let inkTertiary = Color.white.opacity(0.38)
    static let inkQuaternary = Color.white.opacity(0.20)
    static let inkInverted = Color.black

    // MARK: - Lines & Borders

    static let hairline = Color.white.opacity(0.09)
    static let hairlineStrong = Color.white.opacity(0.22)
    static let hairlineGlow = Color.white.opacity(0.40)
    static let hairlineWidth: CGFloat = 0.5

    // MARK: - Radius

    enum Radius {
        static let sm: CGFloat = 6
        static let card: CGFloat = 14
        static let cardLg: CGFloat = 20
        static let control: CGFloat = 10
        static let pill: CGFloat = 999
    }

    // MARK: - Spacing

    enum Space {
        static let xxs: CGFloat = 2
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 24
        static let xxl: CGFloat = 36
        static let grid: CGFloat = 20
    }

    // MARK: - Motion & Physics (iOS 26 feel)

    enum Motion {
        static let springStandard = Animation.spring(response: 0.38, dampingFraction: 0.78)
        static let springQuick = Animation.spring(response: 0.25, dampingFraction: 0.85)
        static let springBouncy = Animation.spring(response: 0.45, dampingFraction: 0.68)
        static let linearLoop = Animation.linear(duration: 3.5).repeatForever(autoreverses: false)
        static let shimmerDuration: Double = 2.4
        static let hoverScale: CGFloat = 1.025
    }
}

// MARK: - Typography (iOS 26 Futuristic & Refined)

extension Font {
    static func display(_ size: CGFloat) -> Font {
        .system(size: size, weight: .bold, design: .default)
    }

    static let heroTitle = Font.system(size: 34, weight: .bold, design: .default)
    static let sectionHeading = Font.system(size: 20, weight: .semibold, design: .default)
    static let cardTitle = Font.system(size: 14, weight: .semibold)
    static let cardSubtitle = Font.system(size: 12, weight: .regular)
    static let badge = Font.system(size: 10, weight: .bold, design: .monospaced)
    static let chip = Font.system(size: 12, weight: .medium)
    static let label = Font.system(size: 13, weight: .regular)
    static let monoMetric = Font.system(size: 11, weight: .semibold, design: .monospaced)
}

// MARK: - Animated Rotating Beam Border (Inspired by Wallper.app)

/// Rotating conic gradient beam border effect that sweeps around the perimeter.
struct BeamBorder: ViewModifier {
    var cornerRadius: CGFloat = Theme.Radius.card
    var lineWidth: CGFloat = 1.2
    var isActive: Bool = true
    var glowIntensity: Double = 0.6
    
    @State private var phase: Double = 0

    func body(content: Content) -> some View {
        content
            .overlay {
                if isActive {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .strokeBorder(
                            AngularGradient(
                                gradient: Gradient(stops: [
                                    .init(color: .clear, location: 0.0),
                                    .init(color: .clear, location: 0.45),
                                    .init(color: Theme.electricBlue.opacity(0.3), location: 0.52),
                                    .init(color: Theme.cyberCyan.opacity(0.9), location: 0.58),
                                    .init(color: .white, location: 0.60),
                                    .init(color: Theme.cyberPurple.opacity(0.9), location: 0.63),
                                    .init(color: Theme.electricBlue.opacity(0.3), location: 0.68),
                                    .init(color: .clear, location: 0.75),
                                    .init(color: .clear, location: 1.0)
                                ]),
                                center: .center,
                                startAngle: .degrees(phase),
                                endAngle: .degrees(phase + 360)
                            ),
                            lineWidth: lineWidth
                        )
                        .blur(radius: 0.5)
                        .opacity(glowIntensity)
                        .onAppear {
                            withAnimation(.linear(duration: 4.0).repeatForever(autoreverses: false)) {
                                phase = 360
                            }
                        }
                }
            }
    }
}

extension View {
    func beamBorder(
        cornerRadius: CGFloat = Theme.Radius.card,
        lineWidth: CGFloat = 1.2,
        isActive: Bool = true,
        glowIntensity: Double = 0.7
    ) -> some View {
        modifier(BeamBorder(
            cornerRadius: cornerRadius,
            lineWidth: lineWidth,
            isActive: isActive,
            glowIntensity: glowIntensity
        ))
    }
}

// MARK: - Futuristic Glass Card

struct GlassCard: ViewModifier {
    var cornerRadius: CGFloat = Theme.Radius.card
    var isHovered: Bool = false
    var isSelected: Bool = false

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(isSelected ? Theme.surfaceActive : (isHovered ? Theme.surfaceHover : Theme.surface))
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .strokeBorder(
                                isSelected ? Theme.hairlineGlow : (isHovered ? Theme.hairlineStrong : Theme.hairline),
                                lineWidth: Theme.hairlineWidth
                            )
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .shadow(
                color: isSelected ? Theme.cyberCyan.opacity(0.18) : (isHovered ? Color.black.opacity(0.4) : Color.clear),
                radius: isSelected ? 16 : 10,
                x: 0,
                y: isSelected ? 4 : 2
            )
    }
}

extension View {
    func glassCard(
        cornerRadius: CGFloat = Theme.Radius.card,
        isHovered: Bool = false,
        isSelected: Bool = false
    ) -> some View {
        modifier(GlassCard(cornerRadius: cornerRadius, isHovered: isHovered, isSelected: isSelected))
    }
}

// MARK: - High-Tech Micro Badges

struct TechBadge: View {
    let text: String
    var icon: String? = nil
    var color: Color = Theme.cyberCyan

    var body: some View {
        HStack(spacing: 4) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 8, weight: .bold))
            }
            Text(text)
                .font(.badge)
        }
        .foregroundStyle(color)
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(color.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .strokeBorder(color.opacity(0.3), lineWidth: 0.5)
        }
    }
}

// MARK: - Futuristic Loading Shimmer

struct FuturisticShimmer: View {
    @State private var phase: CGFloat = -1

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            LinearGradient(
                colors: [
                    Color(red: 0.06, green: 0.06, blue: 0.08),
                    Color(red: 0.12, green: 0.12, blue: 0.16),
                    Color(red: 0.06, green: 0.06, blue: 0.08)
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(width: width * 2)
            .offset(x: phase * width)
            .animation(
                .linear(duration: Theme.Motion.shimmerDuration).repeatForever(autoreverses: false),
                value: phase
            )
            .onAppear { phase = 1 }
        }
        .background(Theme.mediaWell)
        .clipped()
        .allowsHitTesting(false)
    }
}

// MARK: - Interactive Button Styles

struct FuturisticPrimaryButtonStyle: ButtonStyle {
    @State private var isHovering = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(Theme.inkInverted)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(Color.white.opacity(configuration.isPressed ? 0.8 : (isHovering ? 0.95 : 1.0)))
            )
            .beamBorder(cornerRadius: Theme.Radius.pill, lineWidth: 1.0, isActive: isHovering, glowIntensity: 0.8)
            .shadow(color: isHovering ? Color.white.opacity(0.3) : Color.clear, radius: 10, x: 0, y: 0)
            .scaleEffect(configuration.isPressed ? 0.97 : (isHovering ? 1.02 : 1.0))
            .onHover { isHovering = $0 }
            .animation(Theme.Motion.springQuick, value: isHovering)
            .animation(Theme.Motion.springQuick, value: configuration.isPressed)
    }
}

struct FuturisticGhostButtonStyle: ButtonStyle {
    var accentColor: Color = Theme.ink
    @State private var isHovering = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(accentColor)
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(
                Capsule()
                    .fill(configuration.isPressed ? Theme.surfaceActive : (isHovering ? Theme.surfaceHover : Theme.surface))
            )
            .overlay {
                Capsule()
                    .strokeBorder(isHovering ? accentColor.opacity(0.5) : Theme.hairline, lineWidth: Theme.hairlineWidth)
            }
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .onHover { isHovering = $0 }
            .animation(Theme.Motion.springQuick, value: isHovering)
            .animation(Theme.Motion.springQuick, value: configuration.isPressed)
    }
}

// MARK: - Capsule Search Field (iOS 26 Style)

struct FuturisticSearchField: View {
    let placeholder: String
    @Binding var text: String
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(isFocused ? Theme.cyberCyan : Theme.inkTertiary)

            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(Theme.ink)
                .focused($isFocused)

            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.inkTertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(isFocused ? Theme.surfaceActive : Theme.surface)
        .clipShape(Capsule())
        .overlay {
            Capsule().strokeBorder(
                isFocused ? Theme.cyberCyan.opacity(0.5) : Theme.hairline,
                lineWidth: Theme.hairlineWidth
            )
        }
        .animation(Theme.Motion.springQuick, value: isFocused)
        .animation(Theme.Motion.springQuick, value: text.isEmpty)
    }
}

// MARK: - Capsule Filter Chip

struct FuturisticChip: View {
    let title: String
    var count: Int? = nil
    let isSelected: Bool
    var action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Text(title)
                    .font(.chip)
                if let count {
                    Text("\(count)")
                        .font(.badge)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(isSelected ? Color.black.opacity(0.25) : Theme.surfaceActive)
                        .clipShape(Capsule())
                }
            }
            .foregroundStyle(isSelected ? Theme.inkInverted : Theme.ink)
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(
                Capsule()
                    .fill(isSelected ? Color.white : (isHovering ? Theme.surfaceHover : Theme.surface))
            )
            .overlay {
                Capsule().strokeBorder(
                    isSelected ? Color.clear : (isHovering ? Theme.hairlineStrong : Theme.hairline),
                    lineWidth: Theme.hairlineWidth
                )
            }
            .beamBorder(cornerRadius: Theme.Radius.pill, lineWidth: 1.0, isActive: isSelected, glowIntensity: 0.6)
            .scaleEffect(isHovering && !isSelected ? 1.03 : 1.0)
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
        .animation(Theme.Motion.springQuick, value: isSelected)
        .animation(Theme.Motion.springQuick, value: isHovering)
    }
}

// MARK: - Aliases

typealias Shimmer = FuturisticShimmer
typealias HairlineCard = GlassCard
typealias InvertedButtonStyle = FuturisticPrimaryButtonStyle
typealias GhostButtonStyle = FuturisticGhostButtonStyle
typealias SearchField = FuturisticSearchField
typealias Chip = FuturisticChip

extension View {
    func hairlineCard(radius: CGFloat = Theme.Radius.card, fill: Color = Theme.surface) -> some View {
        modifier(GlassCard(cornerRadius: radius))
    }
}
