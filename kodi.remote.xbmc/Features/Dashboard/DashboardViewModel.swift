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

    // Group recent episodes by TV show
    var recentShows: [RecentShowInfo] {
        let grouped = Dictionary(grouping: recentEpisodes) { $0.tvshowid ?? 0 }

        return grouped.compactMap { (tvshowid, episodes) -> RecentShowInfo? in
            guard tvshowid != 0,
                  let latestEpisode = episodes.first else { return nil }

            // Find the most recent season among these episodes
            let mostRecentSeason = episodes.map { $0.season }.max() ?? 1

            return RecentShowInfo(
                tvshowid: tvshowid,
                title: latestEpisode.showtitle ?? "Unknown Show",
                fanart: latestEpisode.fanart,
                thumbnail: latestEpisode.thumbnail,
                season: mostRecentSeason,
                newEpisodeCount: episodes.count
            )
        }.sorted { $0.title < $1.title }
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
        await MainActor.run {
            isLoadingRecent = true
        }

        do {
            async let moviesTask = client.getRecentlyAddedMovies(limit: 20)
            async let episodesTask = client.getRecentlyAddedEpisodes(limit: 20)

            let (moviesResponse, episodesResponse) = try await (moviesTask, episodesTask)

            let episodes = episodesResponse.episodes ?? []

            await MainActor.run {
                recentMovies = moviesResponse.movies ?? []
                recentEpisodes = episodes
                isLoadingRecent = false
            }
        } catch {
            await MainActor.run {
                isLoadingRecent = false
                self.error = error.localizedDescription
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
