import SwiftUI

// MARK: - Color Extensions

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        let int = UInt64(hex, radix: 16) ?? 0
        let r = Double((int >> 16) & 0xFF) / 255
        let g = Double((int >> 8) & 0xFF) / 255
        let b = Double(int & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}

// MARK: - Theme

enum Theme {

    // MARK: - Colors (Omnira depth system)

    enum Colors {
        // Background layers (darker = further back)
        static let background  = Color(hex: "0A0A0A")
        static let surface1    = Color(hex: "0E0E0E")
        static let surface2    = Color(hex: "161616")
        static let surface3    = Color(hex: "1E1E1E")
        static let surface4    = Color(hex: "282828")

        // Primary accent — soft blue
        static let accent      = Color(hex: "5B9EF5")
        static let accentLight = Color(hex: "8BBDFF")
        static let accentDim   = Color(hex: "5B9EF5").opacity(0.12)
        static let accentGlow  = Color(hex: "5B9EF5").opacity(0.30)

        // Text hierarchy
        static let textPrimary   = Color.white.opacity(0.9)
        static let textSecondary = Color.white.opacity(0.5)
        static let textTertiary  = Color.white.opacity(0.3)
        static let textDisabled  = Color.white.opacity(0.2)

        // Borders
        static let borderSubtle   = Color.white.opacity(0.06)
        static let borderDefault  = Color.white.opacity(0.10)
        static let borderElevated = Color.white.opacity(0.15)

        // Semantic
        static let success = Color(hex: "34D399")
        static let error   = Color(hex: "F97066")
        static let warning = Color(hex: "F59E0B")
        static let info    = Color(hex: "818CF8")

        // Chat bubbles
        static let bubbleSent     = Color(hex: "5B9EF5").opacity(0.20)
        static let bubbleReceived = Color.white.opacity(0.08)
        static let bubbleText     = Color.white

        // Overlays
        static let overlayDim   = Color.black.opacity(0.60)
        static let overlayHeavy = Color.black.opacity(0.80)
        static let separator    = Color.white.opacity(0.04)
    }

    // MARK: - Typography

    enum Typography {
        static let largeTitle  = Font.system(size: 28, weight: .bold)
        static let title       = Font.system(size: 22, weight: .semibold)
        static let headline    = Font.system(size: 17, weight: .semibold)
        static let body        = Font.system(size: 17, weight: .regular)
        static let callout     = Font.system(size: 16, weight: .regular)
        static let subhead     = Font.system(size: 15, weight: .regular)
        static let footnote    = Font.system(size: 13, weight: .regular)
        static let caption     = Font.system(size: 11, weight: .regular)

        // Monospaced
        static let mono        = Font.system(size: 13, weight: .regular, design: .monospaced)
        static let monoBody    = Font.system(size: 15, weight: .regular, design: .monospaced)
    }

    // MARK: - Spacing

    enum Spacing {
        static let xs:  CGFloat = 4
        static let sm:  CGFloat = 8
        static let md:  CGFloat = 16
        static let lg:  CGFloat = 24
        static let xl:  CGFloat = 32
    }

    // MARK: - Radius

    enum Radius {
        static let sm:     CGFloat = 8
        static let md:     CGFloat = 12
        static let lg:     CGFloat = 16
        static let xl:     CGFloat = 22
        static let bubble: CGFloat = 18
        static let pill:   CGFloat = 9999
    }

    // MARK: - Animation

    enum Anim {
        static let spring = SwiftUI.Animation.spring(response: 0.35, dampingFraction: 0.8)
        static let smooth = SwiftUI.Animation.easeInOut(duration: 0.2)
        static let fast   = SwiftUI.Animation.easeOut(duration: 0.15)
    }
}

// MARK: - View Modifiers

extension View {
    /// Glass card with material background, with liquid glass on iOS 26+
    @ViewBuilder
    func glassCard(cornerRadius: CGFloat = Theme.Radius.lg) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius)
        if #available(iOS 26.0, *) {
            self
                .background(.ultraThinMaterial, in: shape)
                .glassEffect(in: shape)
        } else {
            self
                .background(.ultraThinMaterial, in: shape)
        }
    }

    /// Apply liquid glass with a rounded rect shape, falling back to material on older OS
    @ViewBuilder
    func liquidGlass(in shape: RoundedRectangle) -> some View {
        if #available(iOS 26.0, *) {
            self.glassEffect(in: shape)
        } else {
            self
        }
    }

    /// Apply liquid glass with a circle shape
    @ViewBuilder
    func liquidGlass(in shape: Circle) -> some View {
        if #available(iOS 26.0, *) {
            self.glassEffect(in: shape)
        } else {
            self
        }
    }

    /// Apply liquid glass with no specific shape
    @ViewBuilder
    func liquidGlass() -> some View {
        if #available(iOS 26.0, *) {
            self.glassEffect()
        } else {
            self
        }
    }

    @ViewBuilder
    func `if`<Transform: View>(_ condition: Bool, transform: (Self) -> Transform) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}
