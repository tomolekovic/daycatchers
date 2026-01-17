import SwiftUI

/// ThemeManager manages the app's visual theme.
/// Persists theme selection to UserDefaults.
final class ThemeManager: ObservableObject {
    @Published var selectedTheme: AppTheme {
        didSet {
            UserDefaults.standard.set(selectedTheme.rawValue, forKey: "selectedTheme")
        }
    }

    var theme: Theme {
        selectedTheme.theme
    }

    init() {
        let savedTheme = UserDefaults.standard.string(forKey: "selectedTheme") ?? AppTheme.classic.rawValue
        self.selectedTheme = AppTheme(rawValue: savedTheme) ?? .classic
    }
}

// MARK: - App Theme Enum

enum AppTheme: String, CaseIterable, Identifiable {
    case classic
    case modernScrapbook

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .classic: return "Classic"
        case .modernScrapbook: return "Modern Scrapbook"
        }
    }

    var description: String {
        switch self {
        case .classic: return "Bright coral and lavender colors"
        case .modernScrapbook: return "Warm cream and terracotta aesthetic"
        }
    }

    var theme: Theme {
        switch self {
        case .classic: return ClassicTheme()
        case .modernScrapbook: return ModernScrapbookTheme()
        }
    }
}

// MARK: - Theme Protocol

protocol Theme {
    var primaryColor: Color { get }
    var secondaryColor: Color { get }
    var backgroundColor: Color { get }
    var surfaceColor: Color { get }
    var textPrimary: Color { get }
    var textSecondary: Color { get }
    var accent: Color { get }
    var destructive: Color { get }

    // Typography
    var titleFont: Font { get }
    var headlineFont: Font { get }
    var bodyFont: Font { get }
    var captionFont: Font { get }

    // Spacing
    var spacingSmall: CGFloat { get }
    var spacingMedium: CGFloat { get }
    var spacingLarge: CGFloat { get }

    // Corner Radius
    var cornerRadiusSmall: CGFloat { get }
    var cornerRadiusMedium: CGFloat { get }
    var cornerRadiusLarge: CGFloat { get }

    // Shadows
    var shadowRadius: CGFloat { get }
    var shadowColor: Color { get }
}

// MARK: - Classic Theme

struct ClassicTheme: Theme {
    // Colors
    let primaryColor = Color(hex: "FF6B6B")      // Coral
    let secondaryColor = Color(hex: "B8A9E0")    // Lavender
    let backgroundColor = Color(hex: "FFFFFF")   // White
    let surfaceColor = Color(hex: "F8F9FA")      // Light gray
    let textPrimary = Color(hex: "212529")       // Dark gray
    let textSecondary = Color(hex: "6C757D")     // Medium gray
    let accent = Color(hex: "4ECDC4")            // Teal
    let destructive = Color(hex: "DC3545")       // Red

    // Typography
    let titleFont = Font.system(.largeTitle, design: .rounded, weight: .bold)
    let headlineFont = Font.system(.headline, design: .rounded, weight: .semibold)
    let bodyFont = Font.system(.body, design: .rounded)
    let captionFont = Font.system(.caption, design: .rounded)

    // Spacing
    let spacingSmall: CGFloat = 8
    let spacingMedium: CGFloat = 16
    let spacingLarge: CGFloat = 24

    // Corner Radius
    let cornerRadiusSmall: CGFloat = 8
    let cornerRadiusMedium: CGFloat = 12
    let cornerRadiusLarge: CGFloat = 20

    // Shadows
    let shadowRadius: CGFloat = 8
    let shadowColor = Color.black.opacity(0.1)
}

// MARK: - Modern Scrapbook Theme

struct ModernScrapbookTheme: Theme {
    // Colors
    let primaryColor = Color(hex: "C4A77D")      // Terracotta
    let secondaryColor = Color(hex: "8B9D83")    // Sage
    let backgroundColor = Color(hex: "FDF8F3")   // Cream
    let surfaceColor = Color(hex: "FFF9F0")      // Warm white
    let textPrimary = Color(hex: "3D3D3D")       // Warm dark
    let textSecondary = Color(hex: "7A7A7A")     // Warm gray
    let accent = Color(hex: "D4A574")            // Warm gold
    let destructive = Color(hex: "C75050")       // Muted red

    // Typography
    let titleFont = Font.system(.largeTitle, design: .serif, weight: .bold)
    let headlineFont = Font.system(.headline, design: .serif, weight: .semibold)
    let bodyFont = Font.system(.body, design: .default)
    let captionFont = Font.system(.caption, design: .default)

    // Spacing
    let spacingSmall: CGFloat = 8
    let spacingMedium: CGFloat = 16
    let spacingLarge: CGFloat = 24

    // Corner Radius
    let cornerRadiusSmall: CGFloat = 6
    let cornerRadiusMedium: CGFloat = 10
    let cornerRadiusLarge: CGFloat = 16

    // Shadows
    let shadowRadius: CGFloat = 6
    let shadowColor = Color(hex: "C4A77D").opacity(0.15)
}

// MARK: - Color Extension

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
            (a, r, g, b) = (1, 1, 1, 0)
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
