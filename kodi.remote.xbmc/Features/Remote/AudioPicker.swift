//
//  AudioPicker.swift
//  kodi.remote.xbmc
//

import SwiftUI

struct AudioPicker: View {
    let audioStreams: [AudioStream]
    let currentIndex: Int
    let onSelect: (Int) -> Void

    var body: some View {
        Menu {
            ForEach(audioStreams) { stream in
                Button {
                    onSelect(stream.id)
                } label: {
                    HStack {
                        Text(stream.displayName)
                        if currentIndex == stream.id {
                            Spacer()
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 12) {
                // Left side: icon + label (fixed, never wraps)
                Image(systemName: "speaker.wave.2")
                    .font(.system(size: 14))
                    .foregroundStyle(.primary)
                    .frame(width: 16)

                Text("Audio")
                    .font(.system(size: 14))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)

                // Right side: current value (flexible, truncates) + chevron
                Spacer(minLength: 8)

                Text(currentAudioLabel)
                    .font(.footnote)
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
        .accessibilityLabel("Audio: \(currentAudioLabel)")
    }

    private var currentAudioLabel: String {
        if let current = audioStreams.first(where: { $0.id == currentIndex }) {
            return current.displayName
        }
        return "None"
    }
}

#Preview {
    VStack(spacing: 20) {
        // Dark mode preview
        VStack(spacing: 0) {
            AudioPicker(
                audioStreams: [
                    AudioStream(id: 0, name: "English", language: "eng", codec: "eac3", channels: 6),
                    AudioStream(id: 1, name: "Spanish", language: "spa", codec: "aac", channels: 2)
                ],
                currentIndex: 0,
                onSelect: { _ in }
            )
        }
        .background(Color(UIColor.tertiarySystemFill))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .environment(\.colorScheme, .dark)

        // Light mode preview
        VStack(spacing: 0) {
            AudioPicker(
                audioStreams: [
                    AudioStream(id: 0, name: "English", language: "eng", codec: "eac3", channels: 6),
                    AudioStream(id: 1, name: "Spanish", language: "spa", codec: "aac", channels: 2)
                ],
                currentIndex: 0,
                onSelect: { _ in }
            )
        }
        .background(Color(UIColor.tertiarySystemFill))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .environment(\.colorScheme, .light)
    }
    .padding()
}
