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
            .themedBackground()
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
        .onChange(of: appState.currentHost?.id) { _, _ in
            // Host changed - reconfigure client and reload
            viewModel.configure(appState: appState)
            Task {
                await viewModel.refresh(section: selectedSection)
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

                if viewModel.recentAlbums.isEmpty && viewModel.recentSongs.isEmpty {
                    if viewModel.isLoading {
                        recentlyAddedSkeleton
                    } else {
                        ContentUnavailableView {
                            Label("No Recent Music", systemImage: "music.note")
                        } description: {
                            Text("Recently added music will appear here")
                        }
                    }
                }
            }
            .padding(.vertical)
            .animation(.easeInOut(duration: 0.3), value: viewModel.recentAlbums.isEmpty)
            .animation(.easeInOut(duration: 0.3), value: viewModel.recentSongs.isEmpty)
        }
        .navigationDestination(for: Album.self) { album in
            AlbumDetailView(album: album, viewModel: viewModel)
        }
    }

    // Skeleton for the Recently Added section while initial data loads.
    // Mirrors the section structure (horizontal album row + vertical song rows)
    // so the layout doesn't reflow when content arrives.
    private var recentlyAddedSkeleton: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 12) {
                Text("New Albums")
                    .font(.headline)
                    .padding(.horizontal)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        ForEach(0..<5, id: \.self) { _ in
                            VStack(alignment: .leading, spacing: 8) {
                                RoundedRectangle(cornerRadius: DesignSystem.Radius.thumbnail)
                                    .fill(Color(.secondarySystemFill))
                                    .frame(width: 140, height: 140)
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color(.tertiarySystemFill))
                                    .frame(width: 110, height: 12)
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color(.tertiarySystemFill))
                                    .frame(width: 80, height: 10)
                            }
                        }
                    }
                    .padding(.horizontal)
                }
            }

            VStack(alignment: .leading, spacing: 12) {
                Text("New Songs")
                    .font(.headline)
                    .padding(.horizontal)

                ForEach(0..<6, id: \.self) { _ in
                    HStack(spacing: 12) {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color(.secondarySystemFill))
                            .frame(width: 48, height: 48)
                        VStack(alignment: .leading, spacing: 6) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color(.tertiarySystemFill))
                                .frame(width: 180, height: 14)
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color(.tertiarySystemFill))
                                .frame(width: 120, height: 10)
                        }
                        Spacer()
                    }
                    .padding(.horizontal)
                }
            }
        }
        .redacted(reason: .placeholder)
        .allowsHitTesting(false)
    }

    // MARK: - Artists

    private var artistsView: some View {
        Group {
            if viewModel.isLoading && viewModel.artists.isEmpty {
                LibraryListSkeleton()
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
                List {
                    ForEach(filteredArtists) { artist in
                        NavigationLink(value: artist) {
                            ArtistRow(artist: artist, host: appState.currentHost)
                        }
                        .listRowBackground(Color.clear)
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
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
                LibraryGridSkeleton(columns: [GridItem(.adaptive(minimum: 150), spacing: 16)])
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
                .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.thumbnail))

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
