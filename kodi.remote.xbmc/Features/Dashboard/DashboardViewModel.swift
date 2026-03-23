//
//  DashboardViewModel.swift
//  kodi.remote.xbmc
//

import Foundation
import os

// Represents a TV show with recently added episodes
struct RecentShowInfo: Identifiable, Hashable {
    let tvshowid: Int
    let title: String
    let fanart: String?
    let thumbnail: String?
    let season: Int // Most recent season with new episodes
    let newEpisodeCount: Int

    var id: Int { tvshowid }
}

@Observable
final class DashboardViewModel {
    private var appState: AppState?
    private var client = KodiClient() // Replaced in configure() with shared instance

    // Continue Watching
    var inProgressMovies: [Movie] = []
    var inProgressEpisodes: [Episode] = []

    // Recently Added
    var recentMovies: [Movie] = []
    var recentEpisodes: [Episode] = []

    // Search Results
    var searchMovies: [Movie] = []
    var searchTVShows: [TVShow] = []
    var searchChannels: [PVRChannel] = []
    var isSearching = false

    // Loading states
    var isLoadingInProgress = false
    var isLoadingRecent = false
    var isInitialLoad = true

    // Errors
    var error: String?

    var hasContinueWatching: Bool {
        !inProgressMovies.isEmpty || !inProgressEpisodes.isEmpty
    }

    var hasRecentlyAdded: Bool {
        !recentMovies.isEmpty || !recentShows.isEmpty
    }

    // Group recent episodes by TV show, preserving most-recently-added order
    var recentShows: [RecentShowInfo] {
        var seen = Set<Int>()
        var results: [RecentShowInfo] = []

        // Episodes are already sorted by dateadded descending from Kodi
        let grouped = Dictionary(grouping: recentEpisodes) { $0.tvshowid ?? 0 }

        for episode in recentEpisodes {
            let tvshowid = episode.tvshowid ?? 0
            guard tvshowid != 0, !seen.contains(tvshowid) else { continue }
            seen.insert(tvshowid)

            let showEpisodes = grouped[tvshowid] ?? []
            let mostRecentSeason = showEpisodes.map { $0.season }.max() ?? 1

            results.append(RecentShowInfo(
                tvshowid: tvshowid,
                title: episode.showtitle ?? "Unknown Show",
                fanart: episode.fanart,
                thumbnail: episode.thumbnail,
                season: mostRecentSeason,
                newEpisodeCount: showEpisodes.count
            ))
        }

        return results
    }

    func configure(appState: AppState) {
        self.appState = appState
        self.client = appState.client
        if let host = appState.currentHost {
            Task {
                await client.configure(with: host)
            }
        }
    }

    // MARK: - Load All

    func loadAll() async {
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.loadInProgress() }
            group.addTask { await self.loadRecentlyAdded() }
        }
        await MainActor.run {
            isInitialLoad = false
        }
    }

    // MARK: - Continue Watching

    func loadInProgress() async {
        await MainActor.run {
            isLoadingInProgress = true
        }

        do {
            async let moviesTask = client.getInProgressMovies()
            async let episodesTask = client.getInProgressEpisodes()

            let (moviesResponse, episodesResponse) = try await (moviesTask, episodesTask)

            // Filter to only items with actual resume points
            let movies = (moviesResponse.movies ?? []).filter { $0.hasResume }
            let episodes = (episodesResponse.episodes ?? []).filter { $0.hasResume }

            await MainActor.run {
                inProgressMovies = movies
                inProgressEpisodes = episodes
                isLoadingInProgress = false
            }
        } catch {
            await MainActor.run {
                isLoadingInProgress = false
                self.error = error.localizedDescription
            }
        }
    }

    // MARK: - Recently Added

    func loadRecentlyAdded() async {
        guard let hostId = appState?.currentHost?.id else { return }

        // Load from cache first for instant display
        if recentMovies.isEmpty && recentEpisodes.isEmpty {
            if let cached = await LibraryCacheService.shared.loadRecentMovies(for: hostId) {
                await MainActor.run { recentMovies = cached.movies }
            }
            if let cached = await LibraryCacheService.shared.loadRecentEpisodes(for: hostId) {
                await MainActor.run { recentEpisodes = cached.episodes }
            }
        }

        await MainActor.run {
            isLoadingRecent = true
        }

        do {
            async let moviesTask = client.getRecentlyAddedMovies(limit: 20)
            async let episodesTask = client.getRecentlyAddedEpisodes(limit: 200)

            let (moviesResponse, episodesResponse) = try await (moviesTask, episodesTask)

            let movies = moviesResponse.movies ?? []
            let episodes = episodesResponse.episodes ?? []

            await MainActor.run {
                recentMovies = movies
                recentEpisodes = episodes
                isLoadingRecent = false
            }

            // Save to cache in background
            await LibraryCacheService.shared.saveRecentMovies(movies, for: hostId)
            await LibraryCacheService.shared.saveRecentEpisodes(episodes, for: hostId)
        } catch {
            // Only show error if we have no cached data
            await MainActor.run {
                isLoadingRecent = false
                if recentMovies.isEmpty && recentEpisodes.isEmpty {
                    self.error = error.localizedDescription
                }
            }
        }
    }

    // MARK: - Playback

    func playMovie(_ movie: Movie, resume: Bool = true) async {
        do {
            try await client.playMovie(movieId: movie.id, resume: resume)
            HapticService.notification(.success)
        } catch {
            Logger.playback.error("Failed to play movie: \(error.localizedDescription)")
            HapticService.notification(.error)
        }
    }

    func playEpisode(_ episode: Episode, resume: Bool = true) async {
        do {
            try await client.playEpisode(episodeId: episode.id, resume: resume)
            HapticService.notification(.success)
        } catch {
            Logger.playback.error("Failed to play episode: \(error.localizedDescription)")
            HapticService.notification(.error)
        }
    }

    // MARK: - Refresh

    func refresh() async {
        await loadAll()
    }

    // MARK: - Search

    func search(query: String) async {
        guard !query.isEmpty else {
            await MainActor.run {
                searchMovies = []
                searchTVShows = []
                searchChannels = []
                isSearching = false
            }
            return
        }

        await MainActor.run {
            isSearching = true
        }

        do {
            async let moviesTask = client.searchMovies(query: query)
            async let showsTask = client.searchTVShows(query: query)
            async let channelsTask = client.getAllTVChannels()

            let (moviesResponse, showsResponse, channelsResponse) = try await (moviesTask, showsTask, channelsTask)

            // Filter channels client-side by name
            let queryLower = query.lowercased()
            let filteredChannels = (channelsResponse.channels ?? []).filter { channel in
                channel.label.lowercased().contains(queryLower) ||
                channel.broadcastnow?.title.lowercased().contains(queryLower) == true
            }

            await MainActor.run {
                searchMovies = moviesResponse.movies ?? []
                searchTVShows = showsResponse.tvshows ?? []
                searchChannels = filteredChannels
                isSearching = false
            }
        } catch {
            Logger.networking.error("Search failed: \(error.localizedDescription)")
            await MainActor.run {
                searchMovies = []
                searchTVShows = []
                searchChannels = []
                isSearching = false
            }
        }
    }

    func clearSearch() {
        searchMovies = []
        searchTVShows = []
        searchChannels = []
        isSearching = false
    }

    var hasSearchResults: Bool {
        !searchMovies.isEmpty || !searchTVShows.isEmpty || !searchChannels.isEmpty
    }

    // MARK: - Play Channel

    func playChannel(_ channel: PVRChannel) async {
        do {
            try await client.playChannel(channelId: channel.channelid)
            HapticService.notification(.success)
        } catch {
            Logger.playback.error("Failed to play channel: \(error.localizedDescription)")
            HapticService.notification(.error)
        }
    }
}
