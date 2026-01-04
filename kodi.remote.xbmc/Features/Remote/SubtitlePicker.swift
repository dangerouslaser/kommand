//
//  SubtitlePicker.swift
//  kodi.remote.xbmc
//

import SwiftUI

struct SubtitlePicker: View {
    let subtitles: [Subtitle]
    let currentIndex: Int
    let isEnabled: Bool
    let onSelect: (Int) -> Void

    var body: some View {
        Menu {
            // Off option
            Button {
                onSelect(-1)
            } label: {
                HStack {
                    Text("Off")
                    if !isEnabled {
                        Spacer()
                        Image(systemName: "checkmark")
                    }
                }
            }

            Divider()

            // Available subtitle tracks
            ForEach(subtitles) { subtitle in
                Button {
                    onSelect(subtitle.id)
                } label: {
                    HStack {
                        Text(subtitle.displayName)
                        if isEnabled && currentIndex == subtitle.id {
                            Spacer()
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 12) {
                // Left side: icon + label (fixed, never wraps)
                Image(systemName: "captions.bubble")
                    .font(.system(size: 14))
                    .foregroundStyle(.primary)
                    .frame(width: 16)

                Text("Subtitles")
                    .font(.system(size: 14))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)

                // Right side: current value (flexible, truncates) + chevron
                Spacer(minLength: 8)

                Text(currentSubtitleLabel)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Subtitles: \(currentSubtitleLabel)")
    }

    private var currentSubtitleLabel: String {
        if !isEnabled {
            return "Off"
        }
        if let current = subtitles.first(where: { $0.id == currentIndex }) {
            return current.displayName
        }
        return "None"
    }
}

#Preview {
    VStack(spacing: 20) {
        // Dark mode preview
        VStack(spacing: 0) {
            SubtitlePicker(
                subtitles: [
                    Subtitle(id: 0, name: "English", language: "eng"),
                    Subtitle(id: 1, name: "Spanish", language: "spa")
                ],
                currentIndex: 0,
                isEnabled: true,
                onSelect: { _ in }
            )
        }
        .background(Color(UIColor.tertiarySystemFill))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .environment(\.colorScheme, .dark)

        // Light mode preview
        VStack(spacing: 0) {
            SubtitlePicker(
                subtitles: [
                    Subtitle(id: 0, name: "English", language: "eng"),
                    Subtitle(id: 1, name: "Spanish", language: "spa")
                ],
                currentIndex: 0,
                isEnabled: true,
                onSelect: { _ in }
            )
        }
        .background(Color(UIColor.tertiarySystemFill))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .environment(\.colorScheme, .light)
    }
    .padding()
}
