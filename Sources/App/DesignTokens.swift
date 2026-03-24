import SwiftUI

enum DesignTokens {
    static let background = Color(hex: "0d0d0e")
    static let surface = Color(hex: "141416")
    static let accent = Color(hex: "c8a97e")
    static let accentGradientStart = Color(hex: "c8a97e")
    static let accentGradientMid = Color(hex: "d4a056")
    static let accentGradientEnd = Color(hex: "e8956a")
    static let textPrimary = Color(hex: "f5f5f7")
    static let textSecondary = Color(hex: "8b8b8e")

    static let radiusSm: CGFloat = 6
    static let radiusMd: CGFloat = 12
    static let radiusLg: CGFloat = 22

    static let spring = SwiftUI.Animation.spring(response: 0.35, dampingFraction: 0.85)
    static let easeOut = SwiftUI.Animation.easeOut(duration: 0.25)

    static let waveformGradient = LinearGradient(
        colors: [accentGradientStart, accentGradientMid, accentGradientEnd],
        startPoint: .leading,
        endPoint: .trailing
    )
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
