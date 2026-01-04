//
//  CECVolumeControl.swift
//  kodi.remote.xbmc
//

import SwiftUI

struct CECVolumeControl: View {
    let onVolumeUp: () -> Void
    let onVolumeDown: () -> Void
    let onMute: () -> Void

    @Environment(\.themeColors) private var colors

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 0) {
                Text("TV Volume")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(colors.textSecondary)

                Spacer()

                Image(systemName: "tv")
                    .font(.caption)
                    .foregroundStyle(colors.textSecondary)
            }

            HStack(spacing: 16) {
                // Volume Down
                Button {
                    onVolumeDown()
                } label: {
                    Image(systemName: "speaker.minus.fill")
                        .font(.title2)
                        .foregroundStyle(colors.textPrimary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(colors.secondaryFill, in: RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Volume Down")

                // Mute
                Button {
                    onMute()
                } label: {
                    Image(systemName: "speaker.slash.fill")
                        .font(.title2)
                        .frame(width: 60, height: 50)
                        .background(Color.red.opacity(0.2), in: RoundedRectangle(cornerRadius: 12))
                        .foregroundStyle(.red)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Mute")

                // Volume Up
                Button {
                    onVolumeUp()
                } label: {
                    Image(systemName: "speaker.plus.fill")
                        .font(.title2)
                        .foregroundStyle(colors.textPrimary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(colors.secondaryFill, in: RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Volume Up")
            }
        }
        .padding()
        .background(colors.cardBackground, in: RoundedRectangle(cornerRadius: 20))
        .themeCardBorder(cornerRadius: 20)
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        CECVolumeControl(
            onVolumeUp: {},
            onVolumeDown: {},
            onMute: {}
        )
        .padding()
    }
}
