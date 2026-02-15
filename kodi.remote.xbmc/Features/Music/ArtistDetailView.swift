//
//  ArtistDetailView.swift
//  kodi.remote.xbmc
//

import SwiftUI

struct ArtistDetailView: View {
    let artist: Artist
    let viewModel: MusicViewModel
    @Environment(AppState.self) private var appState
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.colorScheme) private var colorScheme
    @State private var albums: [Album] = []
    @State private var isLoading = true
    @State private var isDescriptionExpanded = false
    @State private var isDescriptionTruncated = false

    private var isIPad: Bool {
        horizontalSizeClass == .regular
    }

    private var gradientColor: Color {
        colorScheme == .dark ? .black : .white
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Hero Image
                GeometryReader { geo in
                    ZStack(alignment: .bottomLeading) {
                        AsyncArtworkImage(path: artist.fanartPath ?? artist.artworkPath, host: appState.currentHost)
                            .frame(width: geo.size.width, height: geo.size.height)
                            .clipped()

                        LinearGradient(
                            stops: [
                                .init(color: .clear, location: 0),
                                .init(color: gradientColor.opacity(0.3), location: 0.4),
                                .init(color: gradientColor.opacity(0.85), location: 0.75),
                                .init(color: gradientColor, location: 1.0)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )

                        heroOverlayContent
                            .padding(isIPad ? 32 : 16)
                    }
                }
                .frame(height: isIPad ? 550 : 350)

                VStack(alignment: .leading, spacing: 16) {
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
                        let formatted = description
                            .components(separatedBy: "\n")
                            .map { $0.trimmingCharacters(in: .whitespaces) }
                            .filter { !$0.isEmpty }
                            .joined(separator: "\n\n")
                        VStack(alignment: .leading, spacing: 8) {
                            Text(formatted)
                                .font(.body)
                                .foregroundStyle(.secondary)
                                .lineLimit(isDescriptionExpanded ? nil : 4)
                                .background(
                                    GeometryReader { visibleGeometry in
                                        Text(formatted)
                                            .font(.body)
                                            .lineLimit(nil)
                                            .fixedSize(horizontal: false, vertical: true)
                                            .background(
                                                GeometryReader { fullGeometry in
                                                    Color.clear.onAppear {
                                                        isDescriptionTruncated = fullGeometry.size.height > visibleGeometry.size.height + 1
                                                    }
                                                }
                                            )
                                            .hidden()
                                    }
                                )

                            if isDescriptionTruncated || isDescriptionExpanded {
                                Button {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        isDescriptionExpanded.toggle()
                                    }
                                } label: {
                                    Text(isDescriptionExpanded ? "Show Less" : "More")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                }
                            }
                        }
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

    // MARK: - Hero Overlay

    private var heroOverlayContent: some View {
        VStack(alignment: .leading, spacing: isIPad ? 12 : 8) {
            if let clearlogo = artist.clearlogoPath {
                AsyncArtworkImage(path: clearlogo, host: appState.currentHost)
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: isIPad ? 450 : 280, maxHeight: isIPad ? 140 : 80, alignment: .leading)
            } else {
                Text(artist.displayName)
                    .font(.system(size: isIPad ? 42 : 28, weight: .bold))
                    .shadow(color: .black.opacity(0.7), radius: 4, x: 0, y: 2)
            }

            if let genres = artist.genre, !genres.isEmpty {
                Text(genres.joined(separator: ", "))
                    .font(isIPad ? .subheadline : .caption)
            }
        }
        .foregroundStyle(colorScheme == .dark ? .white : .black)
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
