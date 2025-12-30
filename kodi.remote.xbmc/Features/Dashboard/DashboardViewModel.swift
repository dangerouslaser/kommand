//
//  DashboardViewModel.swift
//  kodi.remote.xbmc
//

import Foundation
import UIKit

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
    private let client = KodiClient()

    // Continue Watching
    var inProgressMovies: [Movie] = []
    var inProgressEpisodes: [Episode] = []

    // Recently Added
    var recentMovies: [Movie] = []
    var recentEpisodes: [Episode] = []

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

            await MainActor.run {
                // Filter to only items with actual resume points
                inProgressMovies = (moviesResponse.movies ?? []).filter { $0.hasResume }
                inProgressEpisodes = (episodesResponse.episodes ?? []).filter { $0.hasResume }
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

            await MainActor.run {
                recentMovies = moviesResponse.movies ?? []
                recentEpisodes = episodesResponse.episodes ?? []
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
            triggerHaptic(.success)
        } catch {
            print("Failed to play movie: \(error)")
            triggerHaptic(.error)
        }
    }

    func playEpisode(_ episode: Episode, resume: Bool = true) async {
        do {
            try await client.playEpisode(episodeId: episode.id, resume: resume)
            triggerHaptic(.success)
        } catch {
            print("Failed to play episode: \(error)")
            triggerHaptic(.error)
        }
    }

    // MARK: - Refresh

    func refresh() async {
        await loadAll()
    }

    // MARK: - Helpers

    private func triggerHaptic(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(type)
    }
}
