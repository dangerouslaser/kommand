//
//  AlbumDetailView.swift
//  kodi.remote.xbmc
//

import SwiftUI

struct AlbumDetailView: View {
    let album: Album
    let viewModel: MusicViewModel
    @Environment(AppState.self) private var appState

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Album Art Header
                HStack(spacing: 16) {
                    AsyncArtworkImage(path: album.artworkPath, host: appState.currentHost)
                        .frame(width: 160, height: 160)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .shadow(radius: 8)

                    VStack(alignment: .leading, spacing: 8) {
                        Text(album.title)
                            .font(.title2)
                            .fontWeight(.bold)
                            .lineLimit(3)

                        if let artist = album.artistText {
                            Text(artist)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }

                        HStack(spacing: 8) {
                            if let year = album.year {
                                Text(String(year))
                            }
                            if let genre = album.genreText {
                                Text("•")
                                Text(genre)
                            }
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)

                        Spacer()
                    }
                }
                .padding()

                // Action buttons
                HStack(spacing: 12) {
                    Button {
                        Task { await viewModel.playAlbum(album) }
                    } label: {
                        Label("Play", systemImage: "play.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)

                    Button {
                        Task { await viewModel.playAlbum(album, shuffle: true) }
                    } label: {
                        Label("Shuffle", systemImage: "shuffle")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)

                    Button {
                        Task { await viewModel.queueAlbum(album) }
                    } label: {
                        Image(systemName: "text.badge.plus")
                    }
                    .buttonStyle(.bordered)
                }
                .padding(.horizontal)

                // Track list
                VStack(alignment: .leading, spacing: 0) {
                    Text("Tracks")
                        .font(.headline)
                        .padding()

                    if viewModel.isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding()
                    } else if viewModel.songs.isEmpty {
                        Text("No tracks found")
                            .foregroundStyle(.secondary)
                            .padding()
                    } else {
                        ForEach(viewModel.songs) { song in
                            TrackRow(
                                song: song,
                                onTap: { Task { await viewModel.playSong(song) } },
                                onQueue: { Task { await viewModel.queueSong(song) } }
                            )
                            Divider()
                                .padding(.leading, 50)
                        }
                    }
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.loadSongsForAlbum(album)
        }
    }
}

// MARK: - Track Row

struct TrackRow: View {
    let song: Song
    let onTap: () -> Void
    let onQueue: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Track number
            Text(song.trackNumber ?? "-")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(width: 30, alignment: .trailing)

            // Title
            Text(song.title)
                .font(.body)
                .lineLimit(1)

            Spacer()

            // Duration
            if let duration = song.formattedDuration {
                Text(duration)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
        .contextMenu {
            Button {
                onTap()
            } label: {
                Label("Play", systemImage: "play.fill")
            }

            Button {
                onQueue()
            } label: {
                Label("Add to Queue", systemImage: "text.badge.plus")
            }
        }
    }
}

#Preview {
    NavigationStack {
        AlbumDetailView(
            album: Album(
                albumid: 1,
                title: "Abbey Road",
                label: nil,
                artist: ["The Beatles"],
                displayartist: "The Beatles",
                year: 1969,
                genre: ["Rock"],
                rating: nil,
                thumbnail: nil,
                fanart: nil,
                art: nil,
                playcount: nil,
                artistid: [1],
                dateadded: nil
            ),
            viewModel: MusicViewModel()
        )
    }
    .environment(AppState())
}
