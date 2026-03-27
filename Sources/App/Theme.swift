import SwiftUI

// MARK: - iOS 26 Liquid Glass Theme
// Unified design system for Crisp — aligned with iOS 26 Liquid Glass principles:
// glassmorphism, warm gold accent, large corner radii, haptic feedback, 11pt min fonts.

enum Theme {
    // MARK: - Colors

    static let background = Color(hex: "0d0d0e")
    static let surface = Color(hex: "141416")
    static let surfaceElevated = Color(hex: "1c1c1e")
    static let accent = Color(hex: "c8a97e")
    static let accentGradientStart = Color(hex: "c8a97e")
    static let accentGradientMid = Color(hex: "d4a056")
    static let accentGradientEnd = Color(hex: "e8956a")
    static let textPrimary = Color(hex: "f5f5f7")
    static let textSecondary = Color(hex: "8b8b8e")
    static let textTertiary = Color(hex: "5c5c5e")
    static let destructive = Color(hex: "ff453a")
    static let success = Color(hex: "30d158")

    // MARK: - Corner Radius (iOS 26 Liquid Glass — large, soft radii)

    /// 6pt — chips, small insets
    static let radiusSm: CGFloat = 6
    /// 12pt — cards, inputs, medium elements
    static let radiusMd: CGFloat = 12
    /// 20pt — large cards, sheets, modals
    static let radiusLg: CGFloat = 20
    /// 28pt — full-screen glass elements
    static let radiusXl: CGFloat = 28

    // MARK: - Typography (minimum 11pt for iOS 26 accessibility)

    static let fontCaption2: Font = .system(size: 11, weight: .regular)      // 11pt min
    static let fontCaption: Font = .system(size: 12, weight: .regular)     // 12pt
    static let fontFootnote: Font = .system(size: 13, weight: .regular)    // 13pt
    static let fontSubhead: Font = .system(size: 15, weight: .regular)     // 15pt
    static let fontBody: Font = .system(size: 17, weight: .regular)        // 17pt
    static let fontHeadline: Font = .system(size: 20, weight: .bold)        // 20pt
    static let fontTitle: Font = .system(size: 28, weight: .bold)          // 28pt

    // MARK: - Spacing

    static let spacingXs: CGFloat = 4
    static let spacingSm: CGFloat = 8
    static let spacingMd: CGFloat = 16
    static let spacingLg: CGFloat = 24
    static let spacingXl: CGFloat = 40

    // MARK: - Shadows

    static let shadowSm = (color: Color.black.opacity(0.15), radius: CGFloat(8), y: CGFloat(2))
    static let shadowMd = (color: Color.black.opacity(0.25), radius: CGFloat(16), y: CGFloat(4))
    static let shadowGlass = (color: Color.black.opacity(0.20), radius: CGFloat(20), y: CGFloat(8))

    // MARK: - Haptics (iOS 26 — use for all significant interactions)

    /// Light impact — used for micro-interactions (toggles, selections)
    static let hapticLight = { UIImpactFeedbackGenerator(style: .light).impactOccurred() }

    /// Medium impact — used for button taps, standard interactions
    static let hapticMedium = { UIImpactFeedbackGenerator(style: .medium).impactOccurred() }

    /// Heavy impact — used for major actions (record start/stop, delete)
    static let hapticHeavy = { UIImpactFeedbackGenerator(style: .heavy).impactOccurred() }

    /// Soft impact — iOS 16+ soft aesthetic
    static let hapticSoft = { UIImpactFeedbackGenerator(style: .soft).impactOccurred() }

    /// Rigid impact — iOS 16+ rigid aesthetic
    static let hapticRigid = { UIImpactFeedbackGenerator(style: .rigid).impactOccurred() }

    /// Selection changed — used for pickers, steppers
    static let hapticSelection = { UISelectionFeedbackGenerator().selectionChanged() }

    /// Success notification haptic
    static let hapticSuccess = { UINotificationFeedbackGenerator().notificationOccurred(.success) }

    /// Warning notification haptic
    static let hapticWarning = { UINotificationFeedbackGenerator().notificationOccurred(.warning) }

    /// Error notification haptic
    static let hapticError = { UINotificationFeedbackGenerator().notificationOccurred(.error) }

    // MARK: - Glass Effect

    static let glassBackground = Color(hex: "141416").opacity(0.7)
    static let glassBorder = Color.white.opacity(0.08)
    static let glassBlur: CGFloat = 20

    // MARK: - Animation

    static let springAnimation = SwiftUI.Animation.spring(response: 0.35, dampingFraction: 0.85)
    static let easeOut = SwiftUI.Animation.easeOut(duration: 0.25)
    static let easeInOut = SwiftUI.Animation.easeInOut(duration: 0.3)
}

// MARK: - DesignTokens Compatibility Layer
// Keep existing DesignTokens references working while migrating to Theme.

enum DesignTokens {
    static let background = Theme.background
    static let surface = Theme.surface
    static let accent = Theme.accent
    static let accentGradientStart = Theme.accentGradientStart
    static let accentGradientMid = Theme.accentGradientMid
    static let accentGradientEnd = Theme.accentGradientEnd
    static let textPrimary = Theme.textPrimary
    static let textSecondary = Theme.textSecondary

    /// Updated to iOS 26 Liquid Glass large radius (was 22, now 20)
    static let radiusSm: CGFloat = Theme.radiusSm
    static let radiusMd: CGFloat = Theme.radiusMd
    static let radiusLg: CGFloat = Theme.radiusLg

    static let spring = Theme.springAnimation
    static let easeOut = Theme.easeOut

    static let waveformGradient = LinearGradient(
        colors: [accentGradientStart, accentGradientMid, accentGradientEnd],
        startPoint: .leading,
        endPoint: .trailing
    )
}
