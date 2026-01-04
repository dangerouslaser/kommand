//
//  NowPlayingCard.swift
//  kodi.remote.xbmc
//

import SwiftUI

struct NowPlayingCard: View {
    let item: NowPlayingItem
    var onAudioStreamChange: ((Int) -> Void)?
    var onSubtitleChange: ((Int) -> Void)?
    @Environment(AppState.self) private var appState
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.themeColors) private var themeColors
    @State private var isExpanded = false
    @AppStorage("showDolbyVisionProfile") private var showDolbyVisionProfile = false

    private let cardHeight: CGFloat = 180
    private let cornerRadius: CGFloat = 20
    private let contentPadding: CGFloat = 16
    private let posterWidth: CGFloat = 52
    private let posterHeight: CGFloat = 78

    private var isDarkMode: Bool { colorScheme == .dark }

    var body: some View {
        VStack(spacing: 0) {
            // Main hero card
            ZStack(alignment: .bottom) {
                // Background: Fanart or fallback
                backgroundView
                    .frame(height: cardHeight)

                // Gradient overlay (lighter in light mode)
                LinearGradient(
                    stops: isDarkMode ? [
                        .init(color: .clear, location: 0),
                        .init(color: .black.opacity(0.7), location: 0.5),
                        .init(color: .black.opacity(0.95), location: 1.0)
                    ] : [
                        .init(color: .clear, location: 0.3),
                        .init(color: .black.opacity(0.5), location: 0.6),
                        .init(color: .black.opacity(0.8), location: 1.0)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: cardHeight)

                // Content overlay
                VStack(spacing: 8) {
                    Spacer()

                    HStack(alignment: .bottom, spacing: 12) {
                        // Small poster thumbnail
                        AsyncArtworkImage(path: item.artworkPath, host: appState.currentHost)
                            .frame(width: posterWidth, height: posterHeight)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                            .shadow(color: .black.opacity(isDarkMode ? 0.5 : 0.3), radius: isDarkMode ? 8 : 6, x: 0, y: 4)

                        // Title and badges
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.title)
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(.white)
                                .lineLimit(2)

                            if let subtitle = item.subtitle {
                                Text(subtitle)
                                    .font(.system(size: 13))
                                    .foregroundStyle(.white.opacity(0.7))
                                    .lineLimit(1)
                            }

                            // Badges row
                            if item.videoCodec != nil || item.hdrType != nil {
                                HStack(spacing: 4) {
                                    HeroBadge(text: colorspaceBadge, color: colorspaceBadgeColor)

                                    if showDolbyVisionProfile && hasFEL {
                                        HeroBadge(text: "FEL", color: .green)
                                    }

                                    if let resolution = formattedResolution {
                                        HeroBadge(text: resolution)
                                    }

                                    if let audioCodec = item.audioCodec {
                                        HeroBadge(text: formatAudioCodecShort(audioCodec))
                                    }

                                    if item.hasAtmos {
                                        HeroBadge(text: "Atmos", color: .blue)
                                    }
                                }
                            }
                        }

                        Spacer()

                        // Play/Pause indicator button
                        ZStack {
                            Circle()
                                .fill(.ultraThinMaterial)
                                .frame(width: 36, height: 36)

                            Image(systemName: item.isPlaying ? "pause.fill" : "play.fill")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(.white)
                        }
                        .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
                    }
                    .padding(.horizontal, contentPadding)

                    // Progress bar
                    VStack(spacing: 4) {
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                // Track
                                RoundedRectangle(cornerRadius: 1.5)
                                    .fill(.white.opacity(0.3))
                                    .frame(height: 3)

                                // Progress
                                RoundedRectangle(cornerRadius: 1.5)
                                    .fill(.white)
                                    .frame(width: geometry.size.width * item.progress, height: 3)
                            }
                        }
                        .frame(height: 3)

                        HStack {
                            Text(item.position.formattedDuration)
                                .font(.system(size: 10))
                                .foregroundStyle(.white.opacity(0.6))

                            Spacer()

                            Text("-\(item.remainingTime.formattedDuration)")
                                .font(.system(size: 10))
                                .foregroundStyle(.white.opacity(0.6))
                        }
                    }
                    .padding(.horizontal, contentPadding)
                    .padding(.bottom, contentPadding)
                }
            }
            .frame(height: cardHeight)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .overlay {
                // Subtle border in light mode or when theme requires it
                if !isDarkMode {
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .stroke(Color.black.opacity(0.1), lineWidth: 0.5)
                } else if let borderColor = themeColors.cardBorder {
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .stroke(borderColor, lineWidth: 0.5)
                }
            }

            // Expanded details (below the card)
            if isExpanded {
                expandedContent
                    .padding(.top, 12)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }

            // Expand indicator
            HStack {
                Spacer()
                Image(systemName: "chevron.compact.down")
                    .font(.body)
                    .foregroundStyle(.tertiary)
                    .rotationEffect(.degrees(isExpanded ? 180 : 0))
                Spacer()
            }
            .padding(.top, 8)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.2)) {
                isExpanded.toggle()
            }
        }
    }

    // MARK: - Background View

    @ViewBuilder
    private var backgroundView: some View {
        if let fanartPath = item.fanartPath, !fanartPath.isEmpty {
            // Primary: Use fanart
            AsyncArtworkImage(path: fanartPath, host: appState.currentHost)
                .clipped()
        } else if let artworkPath = item.artworkPath, !artworkPath.isEmpty {
            // Fallback: Blurred and scaled poster
            AsyncArtworkImage(path: artworkPath, host: appState.currentHost)
                .blur(radius: 20)
                .scaleEffect(1.2)
                .clipped()
        } else {
            // Final fallback: Dark gradient
            LinearGradient(
                colors: [Color(white: 0.2), Color(white: 0.1)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    // MARK: - Expanded Content

    private var expandedContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Video info
            if item.videoCodec != nil || item.videoWidth != nil {
                DetailRow(
                    icon: "film",
                    label: "Video",
                    value: videoInfoString
                )
            }

            // Audio info
            if item.audioCodec != nil {
                DetailRow(
                    icon: "speaker.wave.2",
                    label: "Audio",
                    value: formatAudioCodecFull(item.audioCodec, channels: item.audioChannels)
                )
            }

            // Audio & Subtitle Pickers (grouped settings-style)
            if (item.audioStreams.count > 1 && onAudioStreamChange != nil) ||
               (!item.subtitles.isEmpty && onSubtitleChange != nil) {
                Divider()

                VStack(spacing: 0) {
                    if item.audioStreams.count > 1, let onAudioStreamChange {
                        AudioPicker(
                            audioStreams: item.audioStreams,
                            currentIndex: item.currentAudioStreamIndex,
                            onSelect: onAudioStreamChange
                        )

                        // Separator if both pickers are shown
                        if !item.subtitles.isEmpty, onSubtitleChange != nil {
                            Rectangle()
                                .fill(Color.primary.opacity(0.1))
                                .frame(height: 0.5)
                                .padding(.leading, 14)
                        }
                    }

                    if !item.subtitles.isEmpty, let onSubtitleChange {
                        SubtitlePicker(
                            subtitles: item.subtitles,
                            currentIndex: item.currentSubtitleIndex,
                            isEnabled: item.subtitlesEnabled,
                            onSelect: onSubtitleChange
                        )
                    }
                }
                .background(themeColors.secondaryFill)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .themeCardBorder(cornerRadius: 12)
            }
        }
        .padding(.horizontal, 4)
    }

    // MARK: - Colorspace

    private var colorspaceBadge: String {
        if let hdr = item.hdrType, !hdr.isEmpty {
            return formatHDR(hdr)
        }
        return "SDR"
    }

    private var colorspaceBadgeColor: Color {
        guard let hdr = item.hdrType?.lowercased(), !hdr.isEmpty else {
            return .white.opacity(0.6)
        }
        switch hdr {
        case "dolbyvision": return .purple
        case "hdr10", "hdr10plus": return .orange
        case "hlg": return .green
        default: return .orange
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

    private var hasFEL: Bool {
        item.dolbyVisionProfile?.contains("FEL") == true
    }

    // MARK: - Resolution

    private var formattedResolution: String? {
        guard let width = item.videoWidth, let height = item.videoHeight else { return nil }
        if height >= 2160 {
            return "4K"
        } else if height >= 1080 {
            return "1080p"
        } else if height >= 720 {
            return "720p"
        } else if height >= 480 {
            return "480p"
        }
        return "\(width)x\(height)"
    }

    // MARK: - Video Info

    private var videoInfoString: String {
        var parts: [String] = []
        if let codec = item.videoCodec {
            parts.append(formatVideoCodec(codec))
        }
        if let width = item.videoWidth, let height = item.videoHeight {
            parts.append("\(width)x\(height)")
        }
        if let hdr = item.hdrType, !hdr.isEmpty {
            parts.append(formatHDRFull(hdr))
        } else {
            parts.append("SDR")
        }
        return parts.joined(separator: " • ")
    }

    private func formatHDRFull(_ type: String) -> String {
        switch type.lowercased() {
        case "dolbyvision":
            if showDolbyVisionProfile, let dvProfile = item.dolbyVisionProfile {
                return "Dolby Vision \(dvProfile)"
            }
            return "Dolby Vision"
        case "hdr10": return "HDR10"
        case "hdr10plus": return "HDR10+"
        case "hlg": return "HLG"
        default: return type.uppercased()
        }
    }

    private func formatVideoCodec(_ codec: String) -> String {
        switch codec.lowercased() {
        case "hevc", "h265": return "HEVC"
        case "h264", "avc": return "H.264"
        case "av1": return "AV1"
        case "vp9": return "VP9"
        case "mpeg2video": return "MPEG-2"
        default: return codec.uppercased()
        }
    }

    // MARK: - Audio Info

    private func formatAudioCodecShort(_ codec: String?) -> String {
        guard let codec = codec else { return "" }
        let lower = codec.lowercased()

        if lower.contains("truehd") {
            return "TrueHD"
        } else if lower.contains("dts") {
            if lower.contains("hd") || lower.contains("ma") {
                return "DTS-HD"
            } else if lower.contains("x") {
                return "DTS:X"
            }
            return "DTS"
        } else if lower.contains("eac3") || lower.contains("ec3") || lower.contains("ddp") {
            return "DD+"
        } else if lower.contains("ac3") || lower.contains("dolby") {
            return "DD"
        } else if lower.contains("aac") {
            return "AAC"
        } else if lower.contains("flac") {
            return "FLAC"
        } else if lower.contains("pcm") {
            return "PCM"
        }
        return codec.uppercased()
    }

    private func formatAudioCodecFull(_ codec: String?, channels: Int?) -> String {
        guard let codec = codec else { return "Unknown" }
        let lower = codec.lowercased()

        var name: String

        if lower.contains("truehd") {
            name = "Dolby TrueHD"
        } else if lower.contains("dts") {
            if lower.contains("hd") && lower.contains("ma") {
                name = "DTS-HD Master Audio"
            } else if lower.contains("hd") {
                name = "DTS-HD"
            } else if lower.contains("x") {
                name = "DTS:X"
            } else {
                name = "DTS"
            }
        } else if lower.contains("eac3") || lower.contains("ec3") || lower.contains("ddp") {
            name = "Dolby Digital Plus"
        } else if lower.contains("ac3") {
            name = "Dolby Digital"
        } else if lower.contains("aac") {
            name = "AAC"
        } else if lower.contains("flac") {
            name = "FLAC"
        } else if lower.contains("pcm") {
            name = "PCM"
        } else {
            name = codec.uppercased()
        }

        if let ch = channels {
            let channelStr = formatChannels(ch)
            name += " \(channelStr)"
        }

        if item.hasAtmos {
            name += " (Atmos)"
        }

        return name
    }

    private func formatChannels(_ channels: Int) -> String {
        switch channels {
        case 1: return "1.0"
        case 2: return "2.0"
        case 6: return "5.1"
        case 8: return "7.1"
        default: return "\(channels)ch"
        }
    }
}

// MARK: - Hero Badge (for use on dark backgrounds)

struct HeroBadge: View {
    let text: String
    var color: Color = .white.opacity(0.6)

    var body: some View {
        Text(text)
            .font(.system(size: 9, weight: .semibold))
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(color.opacity(0.25), in: RoundedRectangle(cornerRadius: 3))
            .foregroundStyle(color == .white.opacity(0.6) ? .white.opacity(0.8) : color)
    }
}

// MARK: - Legacy CodecBadge (for expanded details)

struct CodecBadge: View {
    let text: String
    var color: Color = .secondary

    var body: some View {
        Text(text)
            .font(.caption2)
            .fontWeight(.medium)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.2), in: RoundedRectangle(cornerRadius: 4))
            .foregroundStyle(color)
    }
}

struct DetailRow: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 16)

            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()

            Text(value)
                .font(.caption)
                .foregroundStyle(.primary)
                .lineLimit(1)
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        NowPlayingCard(item: NowPlayingItem(
            type: .movie,
            title: "The Matrix Resurrections",
            subtitle: "2021",
            artworkPath: nil,
            fanartPath: nil,
            duration: 8100,
            position: 3600,
            speed: 1,
            audioStreams: [],
            subtitles: [],
            currentAudioStreamIndex: 0,
            currentSubtitleIndex: 0,
            subtitlesEnabled: true,
            videoCodec: "hevc",
            audioCodec: "truehd",
            hdrType: "dolbyvision",
            videoWidth: 3840,
            videoHeight: 2160,
            audioChannels: 8,
            audioLanguage: "eng",
            subtitleLanguage: "eng",
            filePath: "/movies/The Matrix Resurrections (2021)/The.Matrix.Resurrections.2021.2160p.mkv",
            dolbyVisionProfile: "P7 FEL",
            hasAtmos: true
        ))

        NowPlayingCard(item: NowPlayingItem(
            type: .episode,
            title: "The One Where They All Turn Thirty",
            subtitle: "Friends S7E14",
            artworkPath: nil,
            fanartPath: nil,
            duration: 1320,
            position: 600,
            speed: 0,
            audioStreams: [],
            subtitles: [],
            currentAudioStreamIndex: 0,
            currentSubtitleIndex: 0,
            subtitlesEnabled: false,
            videoCodec: nil,
            audioCodec: nil,
            hdrType: nil,
            videoWidth: nil,
            videoHeight: nil,
            audioChannels: nil,
            audioLanguage: nil,
            subtitleLanguage: nil,
            filePath: nil,
            dolbyVisionProfile: nil,
            hasAtmos: false
        ))
    }
    .padding()
    .environment(AppState())
}
