//
//  ArtistDetailView.swift
//  kodi.remote.xbmc
//

import SwiftUI

struct ArtistDetailView: View {
    let artist: Artist
    let viewModel: MusicViewModel
    @Environment(AppState.self) private var appState
    @State private var albums: [Album] = []
    @State private var isLoading = true

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Hero Image
                ZStack(alignment: .bottom) {
                    AsyncArtworkImage(path: artist.artworkPath, host: appState.currentHost)
                        .aspectRatio(16/9, contentMode: .fill)
                        .clipped()

                    LinearGradient(
                        colors: [.clear, .black.opacity(0.8)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 120)
                }
                .frame(height: 220)

                VStack(alignment: .leading, spacing: 16) {
                    // Artist name
                    Text(artist.displayName)
                        .font(.title)
                        .fontWeight(.bold)

                    // Genre
                    if let genres = artist.genre, !genres.isEmpty {
                        Text(genres.joined(separator: ", "))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    // Action buttons
                    HStack(spacing: 12) {
                        Button {
                            Task { await viewModel.playArtist(artist, shuffle: true) }
                        } label: {
                            Label("Shuffle", systemImage: "shuffle")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)

                        Button {
                            Task { await viewModel.playArtist(artist, shuffle: false) }
                        } label: {
                            Label("Play All", systemImage: "play.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                    }

                    // Description
                    if let description = artist.description, !description.isEmpty {
                        Text(description)
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }

                    // Albums
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Albums")
                            .font(.headline)

                        if isLoading {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                        } else if albums.isEmpty {
                            Text("No albums found")
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(albums) { album in
                                NavigationLink(value: album) {
                                    AlbumRow(album: album, host: appState.currentHost)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding()
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .ignoresSafeArea(edges: .top)
        .navigationDestination(for: Album.self) { album in
            AlbumDetailView(album: album, viewModel: viewModel)
        }
        .task {
            albums = await viewModel.loadAlbumsForArtist(artist)
            isLoading = false
        }
    }
}

// MARK: - Album Row

struct AlbumRow: View {
    let album: Album
    let host: KodiHost?

    var body: some View {
        HStack(spacing: 12) {
            AsyncArtworkImage(path: album.artworkPath, host: host)
                .frame(width: 60, height: 60)
                .clipShape(RoundedRectangle(cornerRadius: 6))

            VStack(alignment: .leading, spacing: 4) {
                Text(album.title)
                    .font(.body)
                    .fontWeight(.medium)

                if let year = album.year {
                    Text(String(year))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}

#Preview {
    NavigationStack {
        ArtistDetailView(
            artist: Artist(
                artistid: 1,
                artist: "The Beatles",
                label: nil,
                description: "The Beatles were an English rock band formed in Liverpool in 1960.",
                genre: ["Rock", "Pop"],
                thumbnail: nil,
                fanart: nil,
                art: nil
            ),
            viewModel: MusicViewModel()
        )
    }
    .environment(AppState())
}
