//
//  NowPlayingCard.swift
//  kodi.remote.xbmc
//

import SwiftUI

struct NowPlayingCard: View {
    let item: NowPlayingItem
    var onAudioStreamChange: ((Int) -> Void)?
    var onSubtitleChange: ((Int) -> Void)?
    var onSeek: ((Double) -> Void)?
    @Environment(AppState.self) private var appState
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.themeColors) private var themeColors
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var isExpanded = false
    @State private var isSeeking = false
    @State private var seekProgress: Double = 0
    @AppStorage(AppStorageKeys.showDolbyVisionProfile) private var showDolbyVisionProfile = false

    var flexibleHeight: Bool = false

    private var isIPad: Bool { horizontalSizeClass == .regular }
    private var cardHeight: CGFloat { 180 }
    private let cornerRadius: CGFloat = DesignSystem.Radius.card
    private var contentPadding: CGFloat { isIPad ? 24 : 16 }
    private var posterWidth: CGFloat { item.type == .song ? (isIPad ? 128 : 64) : (isIPad ? 104 : 52) }
    private var posterHeight: CGFloat { item.type == .song ? (isIPad ? 128 : 64) : (isIPad ? 156 : 78) }
    private var isDarkMode: Bool { colorScheme == .dark }
    private var metadata: NowPlayingMediaMetadata {
        NowPlayingMediaMetadata(item: item, showDolbyVisionProfile: showDolbyVisionProfile)
    }

    var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .bottom) {
                Color.clear
                    .overlay {
                        NowPlayingArtworkBackground(item: item, host: appState.currentHost)
                    }
                    .clipped()

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

                VStack(spacing: 8) {
                    heroContent

                    NowPlayingProgressView(
                        item: item,
                        onSeek: onSeek,
                        isSeeking: $isSeeking,
                        seekProgress: $seekProgress
                    )
                    .padding(.horizontal, contentPadding)
                    .padding(.bottom, contentPadding)
                }
            }
            .frame(minHeight: cardHeight, maxHeight: flexibleHeight ? .infinity : cardHeight)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .overlay {
                if !isDarkMode {
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .stroke(Color.black.opacity(0.1), lineWidth: 0.5)
                } else if let borderColor = themeColors.cardBorder {
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .stroke(borderColor, lineWidth: 0.5)
                }
            }

            if isExpanded {
                NowPlayingDetailsView(
                    item: item,
                    showDolbyVisionProfile: showDolbyVisionProfile,
                    onAudioStreamChange: onAudioStreamChange,
                    onSubtitleChange: onSubtitleChange
                )
                .padding(.top, 12)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.2)) {
                isExpanded.toggle()
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityDescription)
        .accessibilityHint("Tap card to \(isExpanded ? "collapse" : "show") details")
    }

    private var heroContent: some View {
        HStack(alignment: .bottom, spacing: 12) {
            AsyncArtworkImage(path: item.artworkPath, host: appState.currentHost)
                .frame(width: posterWidth, height: posterHeight)
                .clipShape(RoundedRectangle(cornerRadius: item.type == .song ? 8 : 6))
                .shadow(color: .black.opacity(isDarkMode ? 0.5 : 0.3), radius: isDarkMode ? 8 : 6, x: 0, y: 4)

            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(2)

                if let subtitle = item.subtitle {
                    Text(subtitle)
                        .font(.footnote)
                        .foregroundStyle(.white.opacity(0.7))
                        .lineLimit(1)
                }

                if item.videoCodec != nil || item.hdrType != nil {
                    HStack(spacing: 4) {
                        HeroBadge(text: metadata.colorspaceBadge, color: metadata.colorspaceBadgeColor)

                        if showDolbyVisionProfile && metadata.hasFEL {
                            HeroBadge(text: "FEL", color: .green)
                        }

                        if let resolution = metadata.formattedResolution {
                            HeroBadge(text: resolution)
                        }

                        if let audioCodec = item.audioCodec {
                            HeroBadge(text: metadata.formatAudioCodecShort(audioCodec))
                        }

                        if item.hasAtmos {
                            HeroBadge(text: "Atmos", color: .blue)
                        }
                    }
                }
            }

            Spacer()

            ZStack {
                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: 36, height: 36)

                Image(systemName: item.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
            .accessibilityLabel(item.isPlaying ? "Playing" : "Paused")
        }
        .padding(.horizontal, contentPadding)
    }

    private var accessibilityDescription: String {
        var description = "Now playing: \(item.title)"
        if let subtitle = item.subtitle {
            description += ", \(subtitle)"
        }
        description += ". \(item.position.formattedDuration) of \(item.duration.formattedDuration)"
        description += item.isPlaying ? ". Playing" : ". Paused"
        return description
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
