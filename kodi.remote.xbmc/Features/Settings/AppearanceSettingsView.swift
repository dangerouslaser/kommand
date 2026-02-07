//
//  AppearanceSettingsView.swift
//  kodi.remote.xbmc
//

import SwiftUI

struct AppearanceSettingsView: View {
    @Environment(\.colorScheme) private var systemColorScheme
    @AppStorage("colorScheme") private var colorSchemeSetting = 0 // 0=System, 1=Light, 2=Dark
    @AppStorage("selectedTheme") private var selectedThemeId = "default"
    @AppStorage("nowPlayingBackground") private var nowPlayingBackground = 0 // 0=Blur, 1=Solid
    @AppStorage("showDolbyVisionProfile") private var showDolbyVisionProfile = false
    private var effectiveColorScheme: ColorScheme {
        switch colorSchemeSetting {
        case 1: return .light
        case 2: return .dark
        default: return systemColorScheme
        }
    }

    var body: some View {
        Form {
            Section {
                Picker("Appearance", selection: $colorSchemeSetting) {
                    Text("System").tag(0)
                    Text("Light").tag(1)
                    Text("Dark").tag(2)
                }
            } header: {
                Text("Color Scheme")
            }

            Section {
                ThemeGridPicker(
                    selectedThemeId: $selectedThemeId,
                    effectiveColorScheme: effectiveColorScheme
                )
            } header: {
                Text("Theme")
            } footer: {
                if let theme = AppTheme.allThemes.first(where: { $0.id == selectedThemeId }) {
                    if theme.id == "pureBlack" {
                        Text("True black backgrounds for OLED displays.")
                    } else if theme.id == "noir" {
                        Text("Monochrome elegance with inverted accent colors.")
                    } else if theme.id == "ember" {
                        Text("Warm amber tones for comfortable night viewing.")
                    } else if theme.id == "cinema" {
                        Text("Theater curtain inspired with deep reds.")
                    }
                }
            }

            Section("Now Playing") {
                Picker("Background Style", selection: $nowPlayingBackground) {
                    Text("Blurred Artwork").tag(0)
                    Text("Solid Color").tag(1)
                }
            }

            Section {
                Toggle("Dolby Vision Profile", isOn: $showDolbyVisionProfile)
            } header: {
                Text("Advanced")
            } footer: {
                Text("Show detailed Dolby Vision profile information (e.g., P7 FEL, P8.1 MEL) on the Now Playing card.")
            }
        }
        .navigationTitle("Appearance")
        .navigationBarTitleDisplayMode(.inline)
        .themedScrollBackground()
    }
}

// MARK: - Theme Grid Picker

struct ThemeGridPicker: View {
    @Binding var selectedThemeId: String
    let effectiveColorScheme: ColorScheme

    private let columns = [
        GridItem(.adaptive(minimum: 70), spacing: 12)
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(AppTheme.allThemes) { theme in
                ThemeSwatch(
                    theme: theme,
                    colorScheme: effectiveColorScheme,
                    isSelected: selectedThemeId == theme.id
                ) {
                    selectedThemeId = theme.id
                }
            }
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Theme Swatch

struct ThemeSwatch: View {
    let theme: AppTheme
    let colorScheme: ColorScheme
    let isSelected: Bool
    let action: () -> Void

    private var colors: ThemeColorSet {
        theme.colors(for: colorScheme)
    }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                ZStack {
                    Circle()
                        .fill(colors.background)
                        .frame(width: 50, height: 50)

                    Circle()
                        .fill(colors.accent)
                        .frame(width: 28, height: 28)

                    if isSelected {
                        Circle()
                            .stroke(colors.accent, lineWidth: 3)
                            .frame(width: 56, height: 56)
                    }

                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(colors.invertAccentText ? colors.accent == .white ? .black : .white : .white)
                    }
                }
                .frame(width: 60, height: 60)

                Text(theme.name)
                    .font(.caption2)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
            }
        }
        .buttonStyle(.plain)
    }
}
