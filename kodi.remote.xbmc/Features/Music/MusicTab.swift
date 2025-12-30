//
//  MusicTab.swift
//  kodi.remote.xbmc
//

import SwiftUI

enum MusicSection: String, CaseIterable {
    case recentlyAdded = "Recently Added"
    case artists = "Artists"
    case albums = "Albums"
}

struct MusicTab: View {
    @Environment(AppState.self) private var appState
    @State private var viewModel = MusicViewModel()
    @State private var selectedSection: MusicSection = .recentlyAdded
    @State private var searchText = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Section Picker
                Picker("Section", selection: $selectedSection) {
                    ForEach(MusicSection.allCases, id: \.self) { section in
                        Text(section.rawValue).tag(section)
                    }
                }
                .pickerStyle(.segmented)
                .padding()

                // Content
                Group {
                    switch selectedSection {
                    case .recentlyAdded:
                        recentlyAddedView
                    case .artists:
                        artistsView
                    case .albums:
                        albumsView
                    }
                }
            }
            .navigationTitle("Music")
            .searchable(text: $searchText, prompt: "Search music")
            .refreshable {
                await viewModel.refresh(section: selectedSection)
            }
        }
        .task {
            viewModel.configure(appState: appState)
            await viewModel.loadRecentlyAdded()
        }
        .onChange(of: selectedSection) { _, newSection in
            Task {
                await viewModel.loadSection(newSection)
            }
        }
    }

    // MARK: - Recently Added

    private var recentlyAddedView: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 20) {
                if !viewModel.recentAlbums.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("New Albums")
                            .font(.headline)
                            .padding(.horizontal)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 16) {
                                ForEach(viewModel.recentAlbums) { album in
                                    NavigationLink(value: album) {
                                        AlbumCard(album: album, host: appState.currentHost)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                }

                if !viewModel.recentSongs.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("New Songs")
                            .font(.headline)
                            .padding(.horizontal)

                        ForEach(viewModel.recentSongs) { song in
                            SongRow(
                                song: song,
                                host: appState.currentHost,
                                showAlbum: true,
                                onTap: { Task { await viewModel.playSong(song) } },
                                onQueue: { Task { await viewModel.queueSong(song) } }
                            )
                            .padding(.horizontal)
                        }
                    }
                }

                if viewModel.recentAlbums.isEmpty && viewModel.recentSongs.isEmpty && !viewModel.isLoading {
                    ContentUnavailableView {
                        Label("No Recent Music", systemImage: "music.note")
                    } description: {
                        Text("Recently added music will appear here")
                    }
                }
            }
            .padding(.vertical)
        }
        .navigationDestination(for: Album.self) { album in
            AlbumDetailView(album: album, viewModel: viewModel)
        }
    }

    // MARK: - Artists

    private var artistsView: some View {
        Group {
            if viewModel.isLoading && viewModel.artists.isEmpty {
                ProgressView("Loading Artists...")
            } else if filteredArtists.isEmpty {
                if searchText.isEmpty {
                    ContentUnavailableView {
                        Label("No Artists", systemImage: "music.mic")
                    } description: {
                        Text("Your music library is empty")
                    }
                } else {
                    ContentUnavailableView.search(text: searchText)
                }
            } else {
                List(filteredArtists) { artist in
                    NavigationLink(value: artist) {
                        ArtistRow(artist: artist, host: appState.currentHost)
                    }
                }
                .listStyle(.plain)
                .navigationDestination(for: Artist.self) { artist in
                    ArtistDetailView(artist: artist, viewModel: viewModel)
                }
            }
        }
    }

    private var filteredArtists: [Artist] {
        if searchText.isEmpty {
            return viewModel.artists
        }
        return viewModel.artists.filter {
            $0.displayName.localizedCaseInsensitiveContains(searchText)
        }
    }

    // MARK: - Albums

    private var albumsView: some View {
        Group {
            if viewModel.isLoading && viewModel.albums.isEmpty {
                ProgressView("Loading Albums...")
            } else if filteredAlbums.isEmpty {
                if searchText.isEmpty {
                    ContentUnavailableView {
                        Label("No Albums", systemImage: "square.stack")
                    } description: {
                        Text("Your music library is empty")
                    }
                } else {
                    ContentUnavailableView.search(text: searchText)
                }
            } else {
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 16)], spacing: 16) {
                        ForEach(filteredAlbums) { album in
                            NavigationLink(value: album) {
                                AlbumCard(album: album, host: appState.currentHost)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding()
                }
                .navigationDestination(for: Album.self) { album in
                    AlbumDetailView(album: album, viewModel: viewModel)
                }
            }
        }
    }

    private var filteredAlbums: [Album] {
        if searchText.isEmpty {
            return viewModel.albums
        }
        return viewModel.albums.filter {
            $0.title.localizedCaseInsensitiveContains(searchText) ||
            ($0.artistText?.localizedCaseInsensitiveContains(searchText) ?? false)
        }
    }
}

// MARK: - Album Card

struct AlbumCard: View {
    let album: Album
    let host: KodiHost?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Color.clear
                .aspectRatio(1, contentMode: .fit)
                .overlay {
                    AsyncArtworkImage(path: album.artworkPath, host: host)
                }
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 2) {
                Text(album.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)

                if let artist = album.artistText {
                    Text(artist)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .frame(width: 150)
    }
}

// MARK: - Artist Row

struct ArtistRow: View {
    let artist: Artist
    let host: KodiHost?

    var body: some View {
        HStack(spacing: 12) {
            AsyncArtworkImage(path: artist.artworkPath, host: host)
                .frame(width: 50, height: 50)
                .clipShape(Circle())

            Text(artist.displayName)
                .font(.body)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Song Row

struct SongRow: View {
    let song: Song
    let host: KodiHost?
    var showAlbum: Bool = false
    let onTap: () -> Void
    let onQueue: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            AsyncArtworkImage(path: song.artworkPath, host: host)
                .frame(width: 50, height: 50)
                .clipShape(RoundedRectangle(cornerRadius: 6))

            VStack(alignment: .leading, spacing: 2) {
                Text(song.title)
                    .font(.body)
                    .lineLimit(1)

                HStack(spacing: 4) {
                    if let artist = song.artistText {
                        Text(artist)
                    }
                    if showAlbum, let album = song.album {
                        Text("•")
                        Text(album)
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            }

            Spacer()

            if let duration = song.formattedDuration {
                Text(duration)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
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
    MusicTab()
        .environment(AppState())
}
