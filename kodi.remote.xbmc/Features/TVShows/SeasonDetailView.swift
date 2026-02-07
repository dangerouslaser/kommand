//
//  SeasonDetailView.swift
//  kodi.remote.xbmc
//

import SwiftUI

struct SeasonDetailView: View {
    let show: TVShow
    let season: Season
    let viewModel: TVShowsViewModel
    @Environment(AppState.self) private var appState

    var body: some View {
        List {
            if viewModel.isLoadingEpisodes {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
                .listRowBackground(Color.clear)
            } else if viewModel.episodes.isEmpty {
                ContentUnavailableView {
                    Label("No Episodes", systemImage: "tv")
                } description: {
                    Text("No episodes found for this season")
                }
                .listRowBackground(Color.clear)
            } else {
                ForEach(viewModel.episodes) { episode in
                    EpisodeRow(
                        episode: episode,
                        host: appState.currentHost,
                        onPlay: { await viewModel.playEpisode(episode) },
                        onResume: { await viewModel.playEpisode(episode, resume: true) },
                        onQueue: { await viewModel.queueEpisode(episode) },
                        onToggleWatched: { await viewModel.toggleWatched(episode) }
                    )
                    .listRowBackground(Color.clear)
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .navigationTitle(season.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.loadEpisodes(for: show, season: season.season)
        }
    }
}

// MARK: - Episode Row

struct EpisodeRow: View {
    let episode: Episode
    let host: KodiHost?
    let onPlay: () async -> Void
    let onResume: () async -> Void
    let onQueue: () async -> Void
    let onToggleWatched: () async -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Thumbnail
            ZStack(alignment: .bottomLeading) {
                AsyncArtworkImage(path: episode.thumbnail, host: host)
                    .frame(width: 120, height: 68)
                    .clipShape(RoundedRectangle(cornerRadius: 6))

                if episode.hasResume {
                    ProgressView(value: episode.resume?.progress ?? 0)
                        .tint(.white)
                        .frame(width: 120)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(episode.episodeNumber)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)

                    if episode.isWatched {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.green)
                    }
                }

                Text(episode.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(2)

                HStack(spacing: 8) {
                    if let runtime = episode.formattedRuntime {
                        Text(runtime)
                    }
                    if let firstaired = episode.firstaired {
                        Text(firstaired)
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)

                // Compact media tags
                if let stream = episode.streamdetails {
                    EpisodeMediaTags(streamDetails: stream)
                }
            }

            Spacer()
        }
        .contentShape(Rectangle())
        .onTapGesture {
            Task {
                if episode.hasResume {
                    await onResume()
                } else {
                    await onPlay()
                }
            }
        }
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            Button {
                Task { await onPlay() }
            } label: {
                Label("Play", systemImage: "play.fill")
            }
            .tint(.blue)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button {
                Task { await onToggleWatched() }
            } label: {
                Label(
                    episode.isWatched ? "Unwatched" : "Watched",
                    systemImage: episode.isWatched ? "eye.slash" : "eye"
                )
            }
            .tint(.orange)

            Button {
                Task { await onQueue() }
            } label: {
                Label("Queue", systemImage: "text.badge.plus")
            }
            .tint(.purple)
        }
        .contextMenu {
            Button {
                Task { await onPlay() }
            } label: {
                Label("Play", systemImage: "play.fill")
            }

            if episode.hasResume {
                Button {
                    Task { await onResume() }
                } label: {
                    Label("Resume", systemImage: "play.circle")
                }
            }

            Button {
                Task { await onQueue() }
            } label: {
                Label("Add to Queue", systemImage: "text.badge.plus")
            }

            Divider()

            Button {
                Task { await onToggleWatched() }
            } label: {
                Label(
                    episode.isWatched ? "Mark as Unwatched" : "Mark as Watched",
                    systemImage: episode.isWatched ? "eye.slash" : "eye"
                )
            }
        }
    }
}

// MARK: - Episode Media Tags

struct EpisodeMediaTags: View {
    let streamDetails: StreamDetails

    var body: some View {
        HStack(spacing: 6) {
            // Resolution
            if let resolution = streamDetails.primaryVideo?.resolutionLabel {
                CompactTagBadge(text: resolution, color: .blue)
            }

            // HDR
            if let hdr = streamDetails.primaryVideo?.hdrBadge {
                CompactTagBadge(text: hdr, color: .orange)
            }

            // Video Codec
            if let codec = streamDetails.primaryVideo?.codecLabel {
                CompactTagBadge(text: codec, color: .purple)
            }

            // Audio
            if let audio = streamDetails.primaryAudio?.channelLabel {
                CompactTagBadge(text: audio, color: .green)
            }
        }
    }
}

struct CompactTagBadge: View {
    let text: String
    var color: Color = .secondary

    var body: some View {
        Text(text)
            .font(.caption2.weight(.medium))
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(color.opacity(0.15), in: RoundedRectangle(cornerRadius: 4))
            .foregroundStyle(color)
    }
}

#Preview {
    NavigationStack {
        SeasonDetailView(
            show: TVShow(
                tvshowid: 1,
                title: "Breaking Bad",
                year: 2008,
                rating: nil,
                plot: nil,
                genre: nil,
                studio: nil,
                cast: nil,
                thumbnail: nil,
                fanart: nil,
                art: nil,
                episode: nil,
                watchedepisodes: nil,
                season: nil,
                playcount: nil,
                file: nil,
                imdbnumber: nil,
                premiered: nil,
                dateadded: nil
            ),
            season: Season(
                seasonid: 1,
                season: 1,
                showtitle: "Breaking Bad",
                tvshowid: 1,
                episode: 7,
                watchedepisodes: 5,
                thumbnail: nil,
                fanart: nil,
                art: nil,
                playcount: nil
            ),
            viewModel: TVShowsViewModel()
        )
    }
    .environment(AppState())
}
