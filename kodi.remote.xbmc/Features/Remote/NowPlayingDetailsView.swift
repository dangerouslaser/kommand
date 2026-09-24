//
//  NowPlayingDetailsView.swift
//  kodi.remote.xbmc
//

import SwiftUI

struct NowPlayingDetailsView: View {
    let item: NowPlayingItem
    let showDolbyVisionProfile: Bool
    let onAudioStreamChange: ((Int) -> Void)?
    let onSubtitleChange: ((Int) -> Void)?
    @Environment(\.themeColors) private var themeColors

    private var metadata: NowPlayingMediaMetadata {
        NowPlayingMediaMetadata(item: item, showDolbyVisionProfile: showDolbyVisionProfile)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if item.videoCodec != nil || item.videoWidth != nil {
                DetailRow(
                    icon: "film",
                    label: "Video",
                    value: metadata.videoInfoString
                )
            }

            if item.audioCodec != nil {
                DetailRow(
                    icon: "speaker.wave.2",
                    label: "Audio",
                    value: metadata.formatAudioCodecFull(item.audioCodec, channels: item.audioChannels)
                )
            }

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
                .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.button))
                .themeCardBorder(cornerRadius: DesignSystem.Radius.button)
            }
        }
        .padding(.horizontal, 4)
    }
}
