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
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}

struct QuickActionButton: View {
    let icon: String
    let label: String
    let action: () -> Void

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
        .foregroundStyle(.primary)
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
