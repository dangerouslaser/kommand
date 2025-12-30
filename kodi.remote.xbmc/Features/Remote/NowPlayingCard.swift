//
//  NowPlayingCard.swift
//  kodi.remote.xbmc
//

import SwiftUI

struct NowPlayingCard: View {
    let item: NowPlayingItem
    @Environment(AppState.self) private var appState

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

                    // Codec info if available (CoreELEC)
                    if let videoCodec = item.videoCodec {
                        HStack(spacing: 8) {
                            CodecBadge(text: videoCodec.uppercased())

                            if let hdr = item.hdrType {
                                CodecBadge(text: formatHDR(hdr), color: .orange)
                            }

                            if let audioCodec = item.audioCodec {
                                CodecBadge(text: audioCodec.uppercased())
                            }
                        }
                    }
                }

                Spacer()

                // Play state indicator
                Image(systemName: item.isPlaying ? "pause.fill" : "play.fill")
                    .font(.title2)
                    .foregroundStyle(.secondary)
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
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
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
            hdrType: "dolbyvision"
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
            hdrType: nil
        ))
    }
    .padding()
    .environment(AppState())
}
