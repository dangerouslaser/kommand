//
//  NowPlayingCard.swift
//  kodi.remote.xbmc
//

import SwiftUI

struct NowPlayingCard: View {
    let item: NowPlayingItem
    @Environment(AppState.self) private var appState
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                // Artwork
                AsyncArtworkImage(path: item.artworkPath, host: appState.currentHost)
                    .frame(width: 80, height: 80)
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                // Title and subtitle
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.title)
                        .font(.headline)
                        .lineLimit(2)

                    if let subtitle = item.subtitle {
                        Text(subtitle)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    // Stream info badges - prioritize colorspace
                    if item.videoCodec != nil || item.hdrType != nil {
                        HStack(spacing: 6) {
                            // Colorspace first (most important)
                            CodecBadge(text: colorspaceBadge, color: colorspaceBadgeColor)

                            // FEL badge for Dolby Vision with Full Enhancement Layer
                            if hasFEL {
                                CodecBadge(text: "FEL", color: .green)
                            }

                            if let resolution = formattedResolution {
                                CodecBadge(text: resolution)
                            }

                            if let audioCodec = item.audioCodec {
                                CodecBadge(text: formatAudioCodecShort(audioCodec))
                            }

                            // Atmos badge
                            if item.hasAtmos {
                                CodecBadge(text: "Atmos", color: .blue)
                            }
                        }
                    }
                }

                Spacer()

                // Play state indicator and expand chevron
                VStack(spacing: 6) {
                    Image(systemName: item.isPlaying ? "pause.fill" : "play.fill")
                        .font(.title2)
                        .foregroundStyle(.secondary)

                    Image(systemName: "chevron.down.circle.fill")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }
            }

            // Progress bar
            VStack(spacing: 4) {
                ProgressView(value: item.progress)
                    .tint(.primary)

                HStack {
                    Text(item.position.formattedDuration)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Spacer()

                    Text("-\(item.remainingTime.formattedDuration)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            // Expanded details
            if isExpanded {
                VStack(alignment: .leading, spacing: 8) {
                    Divider()

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
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.2)) {
                isExpanded.toggle()
            }
        }
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
            return .secondary
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
            if let dvProfile = item.dolbyVisionProfile {
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

        // Add channel info
        if let ch = channels {
            let channelStr = formatChannels(ch)
            name += " \(channelStr)"
        }

        // Add Atmos indicator (from actual player info, not codec string)
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
    VStack {
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
