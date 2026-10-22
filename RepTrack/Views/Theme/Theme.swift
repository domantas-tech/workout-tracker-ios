import SwiftUI
import UIKit

extension Color {
    /// `Color(hex: 0xD4FF3F)`
    init(hex: UInt32, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }
}

/// "Electric Lime" – one accent on a neutral, near-black base. The app is always dark.
enum Palette {
    static let lime = Color(hex: 0xD4FF3F)
    static let limeDim = Color(hex: 0xA8CC2E)
    static let onLime = Color(hex: 0x0E1400)
    static let limeContainer = Color(hex: 0x2A3310)
    static let coral = Color(hex: 0xFF6B6B)

    /// Screen background
    static let background = Color(hex: 0x0B0B0D)
    /// Cards
    static let surface = Color(hex: 0x141417)
    /// Inputs, steppers, chips
    static let surfaceHigh = Color(hex: 0x1D1D21)
    static let surfaceHighest = Color(hex: 0x26262B)
    static let outline = Color(hex: 0x2E2E34)
    static let outlineVariant = Color(hex: 0x222227)

    static let textPrimary = Color(hex: 0xF4F4F5)
    static let textSecondary = Color(hex: 0xA1A1AA)

    static let uiLime = UIColor(red: 0xD4 / 255, green: 1, blue: 0x3F / 255, alpha: 1)
    static let uiOnLime = UIColor(red: 0x0E / 255, green: 0x14 / 255, blue: 0, alpha: 1)
    static let uiBackground = UIColor(red: 0x0B / 255, green: 0x0B / 255, blue: 0x0D / 255, alpha: 1)
    static let uiTextPrimary = UIColor(red: 0xF4 / 255, green: 0xF4 / 255, blue: 0xF5 / 255, alpha: 1)
    static let uiSurfaceHigh = UIColor(red: 0x1D / 255, green: 0x1D / 255, blue: 0x21 / 255, alpha: 1)
}

/// Type scale. Numbers use monospaced digits so they don't jitter as reps/weights/timer change.
enum AppFont {
    static let displaySmall = Font.system(size: 34, weight: .semibold).monospacedDigit()
    static let headlineLarge = Font.system(size: 30, weight: .bold)
    static let headlineMedium = Font.system(size: 24, weight: .semibold).monospacedDigit()
    static let headlineSmall = Font.system(size: 20, weight: .semibold).monospacedDigit()
    static let titleLarge = Font.system(size: 20, weight: .semibold)
    static let titleMedium = Font.system(size: 17, weight: .semibold)
    static let titleSmall = Font.system(size: 15, weight: .semibold).monospacedDigit()
    static let bodyLarge = Font.system(size: 16)
    static let bodyMedium = Font.system(size: 14)
    static let bodySmall = Font.system(size: 13)
    static let labelLarge = Font.system(size: 15, weight: .semibold).monospacedDigit()
    static let labelMedium = Font.system(size: 12, weight: .medium).monospacedDigit()
    static let labelSmall = Font.system(size: 11, weight: .medium)
}

/// Corner radii (extra small … extra large).
enum Radius {
    static let extraSmall: CGFloat = 8
    static let small: CGFloat = 12
    static let medium: CGFloat = 16
    static let large: CGFloat = 24
    static let extraLarge: CGFloat = 28
}

/// UIKit-backed controls that SwiftUI can't style directly.
enum Appearance {
    static func configure() {
        let segmented = UISegmentedControl.appearance()
        segmented.selectedSegmentTintColor = Palette.uiLime
        segmented.backgroundColor = Palette.uiSurfaceHigh
        segmented.setTitleTextAttributes([.foregroundColor: Palette.uiOnLime, .font: UIFont.systemFont(ofSize: 14, weight: .semibold)], for: .selected)
        segmented.setTitleTextAttributes([.foregroundColor: Palette.uiTextPrimary, .font: UIFont.systemFont(ofSize: 14, weight: .medium)], for: .normal)

        let navigationBar = UINavigationBarAppearance()
        navigationBar.configureWithOpaqueBackground()
        navigationBar.backgroundColor = Palette.uiBackground
        navigationBar.shadowColor = .clear
        navigationBar.titleTextAttributes = [.foregroundColor: Palette.uiTextPrimary]
        navigationBar.largeTitleTextAttributes = [.foregroundColor: Palette.uiTextPrimary]
        UINavigationBar.appearance().standardAppearance = navigationBar
        UINavigationBar.appearance().scrollEdgeAppearance = navigationBar
        UINavigationBar.appearance().compactAppearance = navigationBar
    }
}

/// Light haptic feedback, like the Android app's long-press and toggle haptics.
enum Haptics {
    @MainActor static func longPress() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    @MainActor static func toggle(on: Bool) {
        UIImpactFeedbackGenerator(style: on ? .rigid : .soft).impactOccurred()
    }
}

/// A rounded card on the surface colour.
struct CardBackground: ViewModifier {
    var radius: CGFloat = Radius.large
    var color: Color = Palette.surface

    func body(content: Content) -> some View {
        content.background(color, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
    }
}

extension View {
    func card(radius: CGFloat = Radius.large, color: Color = Palette.surface) -> some View {
        modifier(CardBackground(radius: radius, color: color))
    }
}
