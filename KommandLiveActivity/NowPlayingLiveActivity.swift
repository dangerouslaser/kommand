//
//  NowPlayingLiveActivity.swift
//  KommandLiveActivity
//
//  Live Activity UI for Now Playing on lock screen and Dynamic Island.
//

import ActivityKit
import AppIntents
import SwiftUI
import WidgetKit

struct NowPlayingLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: NowPlayingAttributes.self) { context in
            // Lock Screen / Banner UI
            LockScreenView(context: context)
                .activityBackgroundTint(Color.black.opacity(0.8))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded: Leading - Poster thumbnail
                DynamicIslandExpandedRegion(.leading) {
                    DynamicIslandPoster()
                }

                // Expanded: Trailing - Playback controls
                DynamicIslandExpandedRegion(.trailing) {
                    HStack(spacing: 8) {
                        Button(intent: SeekBackwardIntent()) {
                            Image(systemName: "gobackward.30")
                                .font(.system(size: 16, weight: .semibold))
                                .frame(width: 32, height: 32)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)

                        Button(intent: PlayPauseIntent()) {
                            Image(systemName: context.state.isPlaying ? "pause.fill" : "play.fill")
                                .font(.system(size: 22, weight: .semibold))
                                .frame(width: 36, height: 36)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)

                        Button(intent: SeekForwardIntent()) {
                            Image(systemName: "goforward.30")
                                .font(.system(size: 16, weight: .semibold))
                                .frame(width: 32, height: 32)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }

                // Expanded: Center - Title and subtitle
                DynamicIslandExpandedRegion(.center) {
                    VStack(spacing: 2) {
                        Text(context.state.title)
                            .font(.system(size: 14, weight: .semibold))
                            .lineLimit(1)
                        if !context.state.subtitle.isEmpty {
                            Text(context.state.subtitle)
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                }

                // Expanded: Bottom - Progress bar
                DynamicIslandExpandedRegion(.bottom) {
                    ProgressBarView(
                        elapsed: context.state.elapsedTime,
                        total: context.state.totalDuration
                    )
                    .padding(.horizontal, 4)
                }
            } compactLeading: {
                // Compact: Leading - Small poster or icon
                DynamicIslandCompactPoster(mediaType: context.attributes.mediaType)
            } compactTrailing: {
                // Compact: Trailing - Play/pause button
                Button(intent: PlayPauseIntent()) {
                    Image(systemName: context.state.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .frame(width: 24, height: 24)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            } minimal: {
                // Minimal: Just an icon
                Image(systemName: context.state.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 12, weight: .semibold))
            }
        }
    }
}

// MARK: - Dynamic Island Poster (Expanded)

private struct DynamicIslandPoster: View {
    var body: some View {
        Group {
            if let image = loadPoster() {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 44, height: 44)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.white.opacity(0.15))
                    .frame(width: 44, height: 44)
                    .overlay {
                        Image(systemName: "film.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(.white.opacity(0.5))
                    }
            }
        }
    }

    private func loadPoster() -> UIImage? {
        guard let url = AppGroupConstants.posterURL,
              let data = try? Data(contentsOf: url),
              let image = UIImage(data: data) else {
            return nil
        }
        return image
    }
}

// MARK: - Dynamic Island Compact Poster

private struct DynamicIslandCompactPoster: View {
    let mediaType: String

    var body: some View {
        // Use app icon for compact Dynamic Island view
        Image("KommandIcon")
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: 20, height: 20)
            .clipShape(RoundedRectangle(cornerRadius: 5))
    }
}

// MARK: - Lock Screen View

private struct LockScreenView: View {
    let context: ActivityViewContext<NowPlayingAttributes>

    var body: some View {
        HStack(spacing: 12) {
            // Poster - always try to load, show placeholder if fails
            LockScreenPoster()
                .frame(width: 48, height: 72)
                .clipShape(RoundedRectangle(cornerRadius: 6))

            // Info
            VStack(alignment: .leading, spacing: 4) {
                // Title
                Text(context.state.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                // Subtitle + Badges
                HStack(spacing: 6) {
                    if !context.state.subtitle.isEmpty {
                        Text(context.state.subtitle)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    BadgesRow(state: context.state)
                }

                // Progress
                ProgressBarView(
                    elapsed: context.state.elapsedTime,
                    total: context.state.totalDuration
                )
            }

            // Playback Controls
            HStack(spacing: 12) {
                Button(intent: SeekBackwardIntent()) {
                    Image(systemName: "gobackward.30")
                        .font(.system(size: 18, weight: .semibold))
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Button(intent: PlayPauseIntent()) {
                    Image(systemName: context.state.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 28, weight: .semibold))
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Button(intent: SeekForwardIntent()) {
                    Image(systemName: "goforward.30")
                        .font(.system(size: 18, weight: .semibold))
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .foregroundStyle(.white)
        }
        .padding(12)
    }
}

// MARK: - Lock Screen Poster

private struct LockScreenPoster: View {
    var body: some View {
        Group {
            if let image = loadPoster() {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.white.opacity(0.15))
                    .overlay {
                        Image(systemName: "film.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(.white.opacity(0.4))
                    }
            }
        }
    }

    private func loadPoster() -> UIImage? {
        guard let url = AppGroupConstants.posterURL,
              let data = try? Data(contentsOf: url),
              let image = UIImage(data: data) else {
            return nil
        }
        return image
    }
}

// MARK: - Badges Row

private struct BadgesRow: View {
    let state: NowPlayingAttributes.ContentState

    var body: some View {
        HStack(spacing: 4) {
            if let hdr = state.hdrType {
                Badge(text: formatHDR(hdr), color: hdrColor(hdr))
            }

            if let resolution = state.resolution {
                Badge(text: resolution)
            }

            if let audio = state.audioCodec {
                Badge(text: audio)
            }

            if state.hasAtmos {
                Badge(text: "Atmos", color: .blue)
            }
        }
    }

    private func formatHDR(_ type: String) -> String {
        switch type.lowercased() {
        case "dolbyvision": return "DV"
        case "hdr10": return "HDR10"
        case "hdr10plus": return "HDR10+"
        case "hlg": return "HLG"
        default: return type.uppercased()
        }
    }

    private func hdrColor(_ type: String) -> Color {
        switch type.lowercased() {
        case "dolbyvision": return .purple
        case "hdr10", "hdr10plus": return .orange
        case "hlg": return .green
        default: return .orange
        }
    }
}

private struct Badge: View {
    let text: String
    var color: Color = .white.opacity(0.6)

    var body: some View {
        Text(text)
            .font(.system(size: 8, weight: .semibold))
            .padding(.horizontal, 4)
            .padding(.vertical, 2)
            .background(color.opacity(0.25), in: RoundedRectangle(cornerRadius: 3))
            .foregroundStyle(color == .white.opacity(0.6) ? .white.opacity(0.8) : color)
    }
}

// MARK: - Progress Bar View

private struct ProgressBarView: View {
    let elapsed: TimeInterval
    let total: TimeInterval

    private var progress: Double {
        guard total > 0 else { return 0 }
        return min(1, max(0, elapsed / total))
    }

    var body: some View {
        HStack(spacing: 6) {
            // Elapsed time
            Text(formatTime(elapsed))
                .font(.system(size: 9, weight: .medium).monospacedDigit())
                .foregroundStyle(.white.opacity(0.7))

            // Progress track
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(.white.opacity(0.25))
                    Capsule()
                        .fill(.white)
                        .frame(width: geometry.size.width * progress)
                }
            }
            .frame(height: 3)

            // Remaining time
            Text("-\(formatTime(max(0, total - elapsed)))")
                .font(.system(size: 9, weight: .medium).monospacedDigit())
                .foregroundStyle(.white.opacity(0.7))
        }
    }

    private func formatTime(_ interval: TimeInterval) -> String {
        let totalSeconds = Int(interval)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }
}

// MARK: - Playback Controls View

private struct PlaybackControlsView: View {
    let isPlaying: Bool

    var body: some View {
        HStack(spacing: 12) {
            // Seek backward 30s
            Button(intent: SeekBackwardIntent()) {
                Image(systemName: "gobackward.30")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .buttonStyle(.plain)

            // Play/Pause with circle background
            Button(intent: PlayPauseIntent()) {
                ZStack {
                    Circle()
                        .fill(.ultraThinMaterial)
                        .frame(width: 40, height: 40)

                    Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                }
            }
            .buttonStyle(.plain)

            // Seek forward 30s
            Button(intent: SeekForwardIntent()) {
                Image(systemName: "goforward.30")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - Preview

#Preview("Lock Screen", as: .content, using: NowPlayingAttributes(mediaType: "movie", hostName: "Living Room")) {
    NowPlayingLiveActivity()
} contentStates: {
    NowPlayingAttributes.ContentState(
        title: "The Dark Knight",
        subtitle: "2008 - Action, Crime, Drama",
        hasPoster: false,
        hasFanart: false,
        elapsedTime: 3600,
        totalDuration: 9120,
        isPlaying: true,
        hdrType: "dolbyvision",
        resolution: "4K",
        audioCodec: "TrueHD",
        hasAtmos: true
    )
}
