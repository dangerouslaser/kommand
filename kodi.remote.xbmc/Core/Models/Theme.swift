//
//  Theme.swift
//  kodi.remote.xbmc
//

import SwiftUI

// MARK: - Theme Color Set

/// Colors for a specific appearance mode (light or dark)
nonisolated struct ThemeColorSet {
    let background: Color
    let cardBackground: Color
    let accent: Color
    let secondaryFill: Color
    let textPrimary: Color
    let textSecondary: Color

    /// Whether accent text should be inverted (e.g., black text on white accent)
    var invertAccentText: Bool = false

    /// Optional card border for themes that need edge definition
    var cardBorder: Color? = nil
}

// MARK: - App Theme

/// Represents a complete theme with light and dark variants
nonisolated struct AppTheme: Identifiable, Equatable {
    let id: String
    let name: String
    let light: ThemeColorSet
    let dark: ThemeColorSet

    static func == (lhs: AppTheme, rhs: AppTheme) -> Bool {
        lhs.id == rhs.id
    }

    /// Get the appropriate color set for the current color scheme
    func colors(for colorScheme: ColorScheme) -> ThemeColorSet {
        colorScheme == .dark ? dark : light
    }
}

// MARK: - Theme Definitions

extension AppTheme {

    // MARK: Default (Free)

    static let `default` = AppTheme(
        id: "default",
        name: "Default",
        light: ThemeColorSet(
            background: Color(hex: "F2F2F7"),
            cardBackground: Color(hex: "FFFFFF", opacity: 0.9),
            accent: Color(hex: "5E5CE6"),
            secondaryFill: Color(hex: "787880", opacity: 0.2),
            textPrimary: Color(hex: "000000"),
            textSecondary: Color(hex: "3C3C43", opacity: 0.6)
        ),
        dark: ThemeColorSet(
            background: Color(hex: "0A0A0A"),
            cardBackground: Color(hex: "1C1C1E", opacity: 0.9),
            accent: Color(hex: "7B7BFF"),
            secondaryFill: Color(hex: "3C3C43", opacity: 0.6),
            textPrimary: Color(hex: "FFFFFF"),
            textSecondary: Color(hex: "EBEBF5", opacity: 0.6)
        )
    )

    // MARK: Pure Black (Pro)

    static let pureBlack = AppTheme(
        id: "pureBlack",
        name: "Pure Black",
        light: ThemeColorSet(
            background: Color(hex: "FFFFFF"),
            cardBackground: Color(hex: "F0F0F5", opacity: 0.9),
            accent: Color(hex: "5E5CE6"),
            secondaryFill: Color(hex: "787880", opacity: 0.16),
            textPrimary: Color(hex: "000000"),
            textSecondary: Color(hex: "3C3C43", opacity: 0.6)
        ),
        dark: ThemeColorSet(
            background: Color(hex: "000000"),
            cardBackground: Color(hex: "1C1C1E", opacity: 0.9),
            accent: Color(hex: "7B7BFF"),
            secondaryFill: Color(hex: "3C3C43", opacity: 0.6),
            textPrimary: Color(hex: "FFFFFF"),
            textSecondary: Color(hex: "EBEBF5", opacity: 0.6),
            cardBorder: Color.white.opacity(0.06)
        )
    )

    // MARK: Cinema (Pro)

    static let cinema = AppTheme(
        id: "cinema",
        name: "Cinema",
        light: ThemeColorSet(
            background: Color(hex: "FDF6F6"),
            cardBackground: Color(hex: "FFFFFF", opacity: 0.9),
            accent: Color(hex: "A01830"),
            secondaryFill: Color(hex: "C41E3A", opacity: 0.12),
            textPrimary: Color(hex: "000000"),
            textSecondary: Color(hex: "3C3C43", opacity: 0.6)
        ),
        dark: ThemeColorSet(
            background: Color(hex: "0D0A0A"),
            cardBackground: Color(hex: "281C1E", opacity: 0.9),
            accent: Color(hex: "C41E3A"),
            secondaryFill: Color(hex: "433235", opacity: 0.6),
            textPrimary: Color(hex: "FFFFFF"),
            textSecondary: Color(hex: "EBEBF5", opacity: 0.6)
        )
    )

    // MARK: Ember (Pro)

    static let ember = AppTheme(
        id: "ember",
        name: "Ember",
        light: ThemeColorSet(
            background: Color(hex: "FFFBF5"),
            cardBackground: Color(hex: "FFFFFF", opacity: 0.9),
            accent: Color(hex: "D35400"),
            secondaryFill: Color(hex: "E67E22", opacity: 0.12),
            textPrimary: Color(hex: "000000"),
            textSecondary: Color(hex: "3C3C43", opacity: 0.6)
        ),
        dark: ThemeColorSet(
            background: Color(hex: "0A0906"),
            cardBackground: Color(hex: "201C16", opacity: 0.9),
            accent: Color(hex: "E67E22"),
            secondaryFill: Color(hex: "433A2D", opacity: 0.6),
            textPrimary: Color(hex: "FFFFFF"),
            textSecondary: Color(hex: "EBEBF5", opacity: 0.6)
        )
    )

    // MARK: Midnight (Pro)

    static let midnight = AppTheme(
        id: "midnight",
        name: "Midnight",
        light: ThemeColorSet(
            background: Color(hex: "F0F9FF"),
            cardBackground: Color(hex: "FFFFFF", opacity: 0.9),
            accent: Color(hex: "0284C7"),
            secondaryFill: Color(hex: "0EA5E9", opacity: 0.12),
            textPrimary: Color(hex: "000000"),
            textSecondary: Color(hex: "3C3C43", opacity: 0.6)
        ),
        dark: ThemeColorSet(
            background: Color(hex: "060A0D"),
            cardBackground: Color(hex: "16202A", opacity: 0.9),
            accent: Color(hex: "0EA5E9"),
            secondaryFill: Color(hex: "2D3A48", opacity: 0.6),
            textPrimary: Color(hex: "FFFFFF"),
            textSecondary: Color(hex: "EBEBF5", opacity: 0.6)
        )
    )

    // MARK: Noir (Pro)

    static let noir = AppTheme(
        id: "noir",
        name: "Noir",
        light: ThemeColorSet(
            background: Color(hex: "FAFAFA"),
            cardBackground: Color(hex: "FFFFFF", opacity: 0.95),
            accent: Color(hex: "000000"),
            secondaryFill: Color(hex: "000000", opacity: 0.08),
            textPrimary: Color(hex: "000000"),
            textSecondary: Color(hex: "3C3C43", opacity: 0.6),
            invertAccentText: true
        ),
        dark: ThemeColorSet(
            background: Color(hex: "080808"),
            cardBackground: Color(hex: "181818", opacity: 0.95),
            accent: Color(hex: "FFFFFF"),
            secondaryFill: Color(hex: "323232", opacity: 0.8),
            textPrimary: Color(hex: "FFFFFF"),
            textSecondary: Color(hex: "EBEBF5", opacity: 0.6),
            invertAccentText: true
        )
    )

    // MARK: Forest (Pro)

    static let forest = AppTheme(
        id: "forest",
        name: "Forest",
        light: ThemeColorSet(
            background: Color(hex: "F0FDF4"),
            cardBackground: Color(hex: "FFFFFF", opacity: 0.9),
            accent: Color(hex: "16A34A"),
            secondaryFill: Color(hex: "22C55E", opacity: 0.12),
            textPrimary: Color(hex: "000000"),
            textSecondary: Color(hex: "3C3C43", opacity: 0.6)
        ),
        dark: ThemeColorSet(
            background: Color(hex: "070A08"),
            cardBackground: Color(hex: "18201A", opacity: 0.9),
            accent: Color(hex: "22C55E"),
            secondaryFill: Color(hex: "2D3C30", opacity: 0.6),
            textPrimary: Color(hex: "FFFFFF"),
            textSecondary: Color(hex: "EBEBF5", opacity: 0.6)
        )
    )

    // MARK: Ultraviolet (Pro)

    static let ultraviolet = AppTheme(
        id: "ultraviolet",
        name: "Ultraviolet",
        light: ThemeColorSet(
            background: Color(hex: "FAF5FF"),
            cardBackground: Color(hex: "FFFFFF", opacity: 0.9),
            accent: Color(hex: "9333EA"),
            secondaryFill: Color(hex: "A855F7", opacity: 0.12),
            textPrimary: Color(hex: "000000"),
            textSecondary: Color(hex: "3C3C43", opacity: 0.6)
        ),
        dark: ThemeColorSet(
            background: Color(hex: "0A070D"),
            cardBackground: Color(hex: "20182A", opacity: 0.9),
            accent: Color(hex: "A855F7"),
            secondaryFill: Color(hex: "3A2D48", opacity: 0.6),
            textPrimary: Color(hex: "FFFFFF"),
            textSecondary: Color(hex: "EBEBF5", opacity: 0.6)
        )
    )

    // MARK: Rose Gold (Pro)

    static let roseGold = AppTheme(
        id: "roseGold",
        name: "Rose Gold",
        light: ThemeColorSet(
            background: Color(hex: "FFF5F7"),
            cardBackground: Color(hex: "FFFFFF", opacity: 0.9),
            accent: Color(hex: "EC4899"),
            secondaryFill: Color(hex: "F472B6", opacity: 0.12),
            textPrimary: Color(hex: "000000"),
            textSecondary: Color(hex: "3C3C43", opacity: 0.6)
        ),
        dark: ThemeColorSet(
            background: Color(hex: "0D0A0A"),
            cardBackground: Color(hex: "261E20", opacity: 0.9),
            accent: Color(hex: "F472B6"),
            secondaryFill: Color(hex: "43343A", opacity: 0.6),
            textPrimary: Color(hex: "FFFFFF"),
            textSecondary: Color(hex: "EBEBF5", opacity: 0.6)
        )
    )

    // MARK: All Themes

    static let allThemes: [AppTheme] = [
        .default,
        .pureBlack,
        .cinema,
        .ember,
        .midnight,
        .noir,
        .forest,
        .ultraviolet,
        .roseGold
    ]

    static func theme(for id: String) -> AppTheme {
        allThemes.first { $0.id == id } ?? .default
    }
}

// MARK: - Color Hex Extension

extension Color {
    init(hex: String, opacity: Double = 1.0) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r, g, b: UInt64
        switch hex.count {
        case 6:
            (r, g, b) = ((int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        case 8:
            (r, g, b) = ((int >> 24) & 0xFF, (int >> 16) & 0xFF, (int >> 8) & 0xFF)
        default:
            (r, g, b) = (0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: opacity
        )
    }
}

// MARK: - Theme Environment

private struct CurrentThemeKey: EnvironmentKey {
    static let defaultValue = AppTheme.default
}

private struct ThemeColorsKey: EnvironmentKey {
    static let defaultValue = AppTheme.default.dark
}

extension EnvironmentValues {
    var currentTheme: AppTheme {
        get { self[CurrentThemeKey.self] }
        set { self[CurrentThemeKey.self] = newValue }
    }

    var themeColors: ThemeColorSet {
        get { self[ThemeColorsKey.self] }
        set { self[ThemeColorsKey.self] = newValue }
    }
}
