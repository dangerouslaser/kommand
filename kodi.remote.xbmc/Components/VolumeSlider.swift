//
//  VolumeSlider.swift
//  kodi.remote.xbmc
//

import SwiftUI

struct VolumeSlider: View {
    @Binding var volume: Int
    let isMuted: Bool
    let onMuteToggle: () -> Void

    @State private var isDragging = false

    var body: some View {
        HStack(spacing: 12) {
            // Mute button
            Button {
                onMuteToggle()
            } label: {
                Image(systemName: isMuted ? "speaker.slash.fill" : volumeIcon)
                    .font(.title3)
                    .foregroundStyle(isMuted ? .red : .primary)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isMuted ? "Unmute" : "Mute")

            // Volume slider
            Slider(
                value: Binding(
                    get: { Double(volume) },
                    set: { volume = Int($0) }
                ),
                in: 0...100,
                step: 1
            ) {
                Text("Volume")
            } minimumValueLabel: {
                EmptyView()
            } maximumValueLabel: {
                EmptyView()
            } onEditingChanged: { editing in
                isDragging = editing
            }
            .tint(.primary)
            .accessibilityValue("\(volume) percent")

            // Volume percentage
            Text("\(volume)")
                .font(.subheadline)
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .frame(width: 36, alignment: .trailing)
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
    }

    private var volumeIcon: String {
        if volume == 0 {
            return "speaker.fill"
        } else if volume < 33 {
            return "speaker.wave.1.fill"
        } else if volume < 66 {
            return "speaker.wave.2.fill"
        } else {
            return "speaker.wave.3.fill"
        }
    }
}

#Preview {
    VStack {
        VolumeSlider(
            volume: .constant(50),
            isMuted: false,
            onMuteToggle: {}
        )

        VolumeSlider(
            volume: .constant(0),
            isMuted: true,
            onMuteToggle: {}
        )
    }
    .padding()
}
