//
//  MusicViewModel.swift
//  kodi.remote.xbmc
//

import Foundation
import SwiftUI
import os

@Observable
final class MusicViewModel {
    private var appState: AppState?
    private var client = KodiClient() // Replaced in configure() with shared instance

    var artists: [Artist] = []
    var albums: [Album] = []
    var recentAlbums: [Album] = []
    var recentSongs: [Song] = []
    var songs: [Song] = [] // For album detail

    var isLoading = false
    var error: String?

    private var loadedSections: Set<MusicSection> = []

    func configure(appState: AppState) {
        self.appState = appState
        self.client = appState.client
        if let host = appState.currentHost {
            Task {
                await client.configure(with: host)
            }
        }
    }

    // MARK: - Loading

    func loadSection(_ section: MusicSection) async {
        guard !loadedSections.contains(section) else { return }

        switch section {
        case .recentlyAdded:
            await loadRecentlyAdded()
        case .artists:
            await loadArtists()
        case .albums:
            await loadAlbums()
        }
    }

    func refresh(section: MusicSection) async {
        loadedSections.remove(section)
        await loadSection(section)
    }

    func loadRecentlyAdded() async {
        guard !loadedSections.contains(.recentlyAdded) else { return }

        await MainActor.run { isLoading = true }

        do {
            async let albumsTask = client.getRecentlyAddedAlbums(limit: 10)
            async let songsTask = client.getRecentlyAddedSongs(limit: 20)

            let (albumsResponse, songsResponse) = try await (albumsTask, songsTask)

            await MainActor.run {
                recentAlbums = albumsResponse.albums ?? []
                recentSongs = songsResponse.songs ?? []
                loadedSections.insert(.recentlyAdded)
                isLoading = false
            }
        } catch {
            await MainActor.run {
                self.error = error.localizedDescription
                isLoading = false
            }
        }
    }

    func loadArtists() async {
        guard !loadedSections.contains(.artists) else { return }

        await MainActor.run { isLoading = true }

        do {
            let result = try await client.getArtists(
                sort: (field: "artist", ascending: true),
                start: 0,
                limit: 1000
            )
            await MainActor.run {
                artists = result.artists ?? []
                loadedSections.insert(.artists)
                isLoading = false
            }
        } catch {
            await MainActor.run {
                self.error = error.localizedDescription
                isLoading = false
            }
        }
    }

    func loadAlbums() async {
        guard !loadedSections.contains(.albums) else { return }

        await MainActor.run { isLoading = true }

        do {
            let result = try await client.getAlbums(
                artistId: nil,
                sort: (field: "title", ascending: true),
                start: 0,
                limit: 1000
            )
            await MainActor.run {
                albums = result.albums ?? []
                loadedSections.insert(.albums)
                isLoading = false
            }
        } catch {
            await MainActor.run {
                self.error = error.localizedDescription
                isLoading = false
            }
        }
    }

    func loadAlbumsForArtist(_ artist: Artist) async -> [Album] {
        do {
            let result = try await client.getAlbums(
                artistId: artist.artistid,
                sort: (field: "year", ascending: false),
                start: 0,
                limit: 100
            )
            return result.albums ?? []
        } catch {
            Logger.networking.error("Failed to load albums for artist: \(error.localizedDescription)")
            return []
        }
    }

    func loadSongsForAlbum(_ album: Album) async {
        await MainActor.run {
            isLoading = true
            songs = []
        }

        do {
            let response = try await client.getSongs(
                albumId: album.albumid,
                start: 0,
                limit: 500
            )
            await MainActor.run {
                songs = response.songs ?? []
                isLoading = false
            }
        } catch {
            await MainActor.run {
                self.error = error.localizedDescription
                isLoading = false
            }
        }
    }

    // MARK: - Playback

    func playAlbum(_ album: Album, shuffle: Bool = false) async {
        do {
            try await client.playAlbum(albumId: album.albumid, shuffle: shuffle)
            HapticService.notification(.success)
        } catch {
            Logger.playback.error("Failed to play album: \(error.localizedDescription)")
            HapticService.notification(.error)
        }
    }

    func queueAlbum(_ album: Album) async {
        do {
            try await client.queueAlbum(albumId: album.albumid)
            HapticService.notification(.success)
        } catch {
            Logger.playback.error("Failed to queue album: \(error.localizedDescription)")
            HapticService.notification(.error)
        }
    }

    func playSong(_ song: Song) async {
        do {
            try await client.playSong(songId: song.songid)
            HapticService.notification(.success)
        } catch {
            Logger.playback.error("Failed to play song: \(error.localizedDescription)")
            HapticService.notification(.error)
        }
    }

    func queueSong(_ song: Song) async {
        do {
            try await client.queueSong(songId: song.songid)
            HapticService.notification(.success)
        } catch {
            Logger.playback.error("Failed to queue song: \(error.localizedDescription)")
            HapticService.notification(.error)
        }
    }

    func playArtist(_ artist: Artist, shuffle: Bool = true) async {
        do {
            try await client.playArtist(artistId: artist.artistid, shuffle: shuffle)
            HapticService.notification(.success)
        } catch {
            Logger.playback.error("Failed to play artist: \(error.localizedDescription)")
            HapticService.notification(.error)
        }
    }
}
