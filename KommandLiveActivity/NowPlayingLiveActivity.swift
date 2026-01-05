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

// MARK: - Helper Functions

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

// MARK: - Dynamic Island Badge

private struct DynamicIslandBadge: View {
    let text: String
    var color: Color = .white.opacity(0.6)

    var body: some View {
        Text(text)
            .font(.system(size: 9, weight: .bold))
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(color.opacity(0.2), in: RoundedRectangle(cornerRadius: 4))
            .foregroundStyle(color == .white.opacity(0.6) ? .white.opacity(0.8) : color)
    }
}

struct NowPlayingLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: NowPlayingAttributes.self) { context in
            // Lock Screen / Banner UI
            LockScreenView(context: context)
                .activityBackgroundTint(Color.black.opacity(0.8))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded: Leading - Square artwork like Podcasts
                DynamicIslandExpandedRegion(.leading) {
                    DynamicIslandPoster()
                }

                // Expanded: Center - Title and badges
                DynamicIslandExpandedRegion(.center) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(context.state.title)
                            .font(.system(size: 14, weight: .semibold))
                            .lineLimit(1)

                        // Colored badges matching lock screen
                        HStack(spacing: 4) {
                            if let hdr = context.state.hdrType {
                                DynamicIslandBadge(
                                    text: formatHDR(hdr),
                                    color: hdrColor(hdr)
                                )
                            }
                            if let resolution = context.state.resolution {
                                DynamicIslandBadge(text: resolution)
                            }
                            if let audio = context.state.audioCodec {
                                DynamicIslandBadge(text: audio)
                            }
                        }
                    }
                }

                // Expanded: Trailing - Empty (keep layout clean)
                DynamicIslandExpandedRegion(.trailing) {
                    EmptyView()
                }

                // Expanded: Bottom - Progress bar + Controls (like Podcasts)
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(spacing: 12) {
                        // Progress bar (auto-updates when playing)
                        LiveProgressBar(
                            elapsed: context.state.elapsedTime,
                            total: context.state.totalDuration,
                            isPlaying: context.state.isPlaying,
                            lastUpdated: context.state.lastUpdated,
                            compact: true
                        )

                        // Playback controls (centered)
                        HStack(spacing: 32) {
                            Button(intent: SeekBackwardIntent()) {
                                Image(systemName: "gobackward.30")
                                    .font(.system(size: 22, weight: .medium))
                                    .frame(width: 44, height: 44)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)

                            Button(intent: PlayPauseIntent()) {
                                Image(systemName: context.state.isPlaying ? "pause.fill" : "play.fill")
                                    .font(.system(size: 32, weight: .semibold))
                                    .frame(width: 44, height: 44)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)

                            Button(intent: SeekForwardIntent()) {
                                Image(systemName: "goforward.30")
                                    .font(.system(size: 22, weight: .medium))
                                    .frame(width: 44, height: 44)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
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
                    .frame(width: 36, height: 54)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            } else {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.white.opacity(0.15))
                    .frame(width: 36, height: 54)
                    .overlay {
                        Image(systemName: "film.fill")
                            .font(.system(size: 16))
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

// MARK: - Progress Bar

private struct LiveProgressBar: View {
    let elapsed: TimeInterval
    let total: TimeInterval
    let isPlaying: Bool
    let lastUpdated: Date
    var compact: Bool = false

    private var progress: Double {
        guard total > 0 else { return 0 }
        return min(1, max(0, elapsed / total))
    }

    private var remaining: TimeInterval {
        max(0, total - elapsed)
    }

    // For live counting: the date when playback "started" (extrapolated back from current position)
    private var playbackStartDate: Date {
        lastUpdated.addingTimeInterval(-elapsed)
    }

    // For live counting: the date when playback will "end"
    private var playbackEndDate: Date {
        playbackStartDate.addingTimeInterval(total)
    }

    // Fixed widths to prevent layout shifts
    private var elapsedWidth: CGFloat {
        total >= 3600 ? 55 : 38
    }

    private var remainingWidth: CGFloat {
        total >= 3600 ? 60 : 43
    }

    var body: some View {
        HStack(spacing: 8) {
            // Elapsed time - counts up when playing
            if isPlaying && total > 0 {
                Text(
                    timerInterval: playbackStartDate...playbackEndDate,
                    countsDown: false
                )
                .font(.system(size: compact ? 10 : 11, weight: .medium).monospacedDigit())
                .foregroundStyle(.white.opacity(0.6))
                .frame(width: elapsedWidth, alignment: .leading)
            } else {
                Text(formatTime(elapsed))
                    .font(.system(size: compact ? 10 : 11, weight: .medium).monospacedDigit())
                    .foregroundStyle(.white.opacity(0.6))
                    .frame(width: elapsedWidth, alignment: .leading)
            }

            // Progress bar (static - updates on poll)
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(.white.opacity(0.3))
                    Capsule()
                        .fill(.white)
                        .frame(width: geometry.size.width * progress)
                }
            }
            .frame(height: compact ? 3 : 4)

            // Remaining time - counts down when playing
            if isPlaying && total > 0 {
                HStack(spacing: 0) {
                    Text("-")
                    Text(
                        timerInterval: playbackStartDate...playbackEndDate,
                        countsDown: true
                    )
                }
                .font(.system(size: compact ? 10 : 11, weight: .medium).monospacedDigit())
                .foregroundStyle(.white.opacity(0.6))
                .frame(width: remainingWidth, alignment: .trailing)
            } else {
                Text("-\(formatTime(remaining))")
                    .font(.system(size: compact ? 10 : 11, weight: .medium).monospacedDigit())
                    .foregroundStyle(.white.opacity(0.6))
                    .frame(width: remainingWidth, alignment: .trailing)
            }
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
        HStack(spacing: 16) {
            // Left: Poster
            LockScreenPoster()
                .frame(width: 72, height: 108)
                .clipShape(RoundedRectangle(cornerRadius: 8))

            // Right: Everything else
            VStack(alignment: .leading, spacing: 8) {
                // Title
                Text(context.state.title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                // Badges
                BadgesRow(state: context.state)

                // Progress bar (auto-updates when playing)
                LiveProgressBar(
                    elapsed: context.state.elapsedTime,
                    total: context.state.totalDuration,
                    isPlaying: context.state.isPlaying,
                    lastUpdated: context.state.lastUpdated
                )

                // Playback controls (centered)
                HStack {
                    Spacer()

                    HStack(spacing: 24) {
                        Button(intent: SeekBackwardIntent()) {
                            Image(systemName: "gobackward.30")
                                .font(.system(size: 22, weight: .medium))
                                .frame(width: 44, height: 44)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)

                        Button(intent: PlayPauseIntent()) {
                            Image(systemName: context.state.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                                .font(.system(size: 48))
                                .frame(width: 52, height: 52)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)

                        Button(intent: SeekForwardIntent()) {
                            Image(systemName: "goforward.30")
                                .font(.system(size: 22, weight: .medium))
                                .frame(width: 44, height: 44)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                    .foregroundStyle(.white)

                    Spacer()
                }
            }
        }
        .padding(16)
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
            .font(.system(size: 9, weight: .bold))
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(color.opacity(0.2), in: RoundedRectangle(cornerRadius: 4))
            .foregroundStyle(color == .white.opacity(0.6) ? .white.opacity(0.8) : color)
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
        lastUpdated: Date(),
        hdrType: "dolbyvision",
        resolution: "4K",
        audioCodec: "TrueHD",
        hasAtmos: true
    )
}
