//
//  QuickActionsBar.swift
//  kodi.remote.xbmc
//

import SwiftUI

struct QuickActionsBar: View {
    let onHome: () -> Void
    let onBack: () -> Void
    let onInfo: () -> Void
    let onOSD: () -> Void
    let onKeyboard: () -> Void

    @Environment(\.themeColors) private var colors

    var body: some View {
        HStack(spacing: 0) {
            QuickActionButton(icon: "house.fill", label: "Home", action: onHome)
            Divider().frame(height: 24)
            QuickActionButton(icon: "arrow.backward", label: "Back", action: onBack)
            Divider().frame(height: 24)
            QuickActionButton(icon: "keyboard", label: "Keyboard", action: onKeyboard)
            Divider().frame(height: 24)
            QuickActionButton(icon: "info.circle", label: "Info", action: onInfo)
            Divider().frame(height: 24)
            QuickActionButton(icon: "rectangle.on.rectangle", label: "OSD", action: onOSD)
        }
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .background(colors.cardBackground, in: RoundedRectangle(cornerRadius: 20))
        .themeCardBorder(cornerRadius: 20)
    }
}

struct QuickActionButton: View {
    let icon: String
    let label: String
    let action: () -> Void

    @Environment(\.themeColors) private var colors

    var body: some View {
        Button {
            action()
        } label: {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.title3)
                Text(label)
                    .font(.caption2)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
        .foregroundStyle(colors.textPrimary)
        .accessibilityLabel(label)
    }
}

#Preview {
    QuickActionsBar(
        onHome: {},
        onBack: {},
        onInfo: {},
        onOSD: {},
        onKeyboard: {}
    )
    .padding()
}
