//
//  PlaybackControls.swift
//  kodi.remote.xbmc
//

import SwiftUI

struct PlaybackControls: View {
    let isPlaying: Bool
    let onPlayPause: () -> Void
    let onStop: () -> Void
    let onSkipBack: () -> Void
    let onSkipForward: () -> Void
    let onSeekBack: () -> Void
    let onSeekForward: () -> Void

    var body: some View {
        HStack(spacing: 20) {
            // Skip back
            ControlButton(
                icon: "backward.end.fill",
                label: "Previous",
                action: onSkipBack
            )

            // Seek backward
            ControlButton(
                icon: "gobackward.30",
                label: "Rewind 30 seconds",
                action: onSeekBack
            )

            // Play/Pause (long-press for Stop)
            Button {
                onPlayPause()
            } label: {
                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                    .font(.title)
                    .frame(width: 64, height: 64)
                    .background(.tint, in: Circle())
                    .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isPlaying ? "Pause" : "Play")
            .contextMenu {
                Button(role: .destructive) {
                    onStop()
                } label: {
                    Label("Stop Playback", systemImage: "stop.fill")
                }
            }

            // Seek forward
            ControlButton(
                icon: "goforward.30",
                label: "Forward 30 seconds",
                action: onSeekForward
            )

            // Skip forward
            ControlButton(
                icon: "forward.end.fill",
                label: "Next",
                action: onSkipForward
            )
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
}

struct ControlButton: View {
    let icon: String
    let label: String
    let action: () -> Void

    var body: some View {
        Button {
            action()
        } label: {
            Image(systemName: icon)
                .font(.title2)
                .frame(width: 44, height: 44)
                .foregroundStyle(.primary)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

#Preview {
    PlaybackControls(
        isPlaying: true,
        onPlayPause: {},
        onStop: {},
        onSkipBack: {},
        onSkipForward: {},
        onSeekBack: {},
        onSeekForward: {}
    )
    .padding()
}
