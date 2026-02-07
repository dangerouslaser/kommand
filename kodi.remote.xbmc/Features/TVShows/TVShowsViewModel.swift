//
//  TVShowsViewModel.swift
//  kodi.remote.xbmc
//

import Foundation
import SwiftUI
import os

@Observable
final class TVShowsViewModel {
    private var appState: AppState?
    private var libraryState: LibraryState?
    private var client = KodiClient() // Replaced in configure() with shared instance

    // Cached data for detail views
    var seasons: [Season] = []
    var episodes: [Episode] = []
    var isLoadingSeasons = false
    var isLoadingEpisodes = false

    func configure(appState: AppState, libraryState: LibraryState) {
        self.appState = appState
        self.libraryState = libraryState
        self.client = appState.client
        if let host = appState.currentHost {
            Task {
                await client.configure(with: host)
            }
        }
    }

    // MARK: - Loading Shows

    func loadTVShows(forceRefresh: Bool = false) async {
        guard let libraryState = libraryState else { return }

        if !forceRefresh && !libraryState.tvShows.isEmpty {
            return
        }

        await MainActor.run {
            libraryState.isLoadingTVShows = true
            libraryState.tvShowsError = nil
        }

        do {
            let sortField = await MainActor.run { libraryState.tvShowSortField }
            let sortAscending = await MainActor.run { libraryState.tvShowSortAscending }

            let result = try await client.getTVShows(
                sort: (field: sortField.rawValue, ascending: sortAscending),
                start: 0,
                limit: 1000
            )

            await MainActor.run {
                libraryState.tvShows = result.tvshows ?? []
                libraryState.tvShowsTotalCount = result.limits?.total ?? 0
                libraryState.lastTVShowsSync = Date()
                libraryState.isLoadingTVShows = false
            }
        } catch {
            await MainActor.run {
                libraryState.tvShowsError = error.localizedDescription
                libraryState.isLoadingTVShows = false
            }
        }
    }

    // MARK: - Loading Seasons

    func loadSeasons(for show: TVShow) async {
        await MainActor.run {
            isLoadingSeasons = true
            seasons = []
        }

        do {
            let response = try await client.getSeasons(tvShowId: show.tvshowid)
            await MainActor.run {
                seasons = response.seasons ?? []
                isLoadingSeasons = false
            }
        } catch {
            Logger.networking.error("Failed to load seasons: \(error.localizedDescription)")
            await MainActor.run {
                isLoadingSeasons = false
            }
        }
    }

    // MARK: - Loading Episodes

    func loadEpisodes(for show: TVShow, season: Int? = nil) async {
        await MainActor.run {
            isLoadingEpisodes = true
            episodes = []
        }

        do {
            let response = try await client.getEpisodes(
                tvShowId: show.tvshowid,
                season: season,
                start: 0,
                limit: 500
            )
            await MainActor.run {
                episodes = response.episodes ?? []
                isLoadingEpisodes = false
            }
        } catch {
            Logger.networking.error("Failed to load episodes: \(error.localizedDescription)")
            await MainActor.run {
                isLoadingEpisodes = false
            }
        }
    }

    // MARK: - Playback

    func playEpisode(_ episode: Episode, resume: Bool = false) async {
        do {
            try await client.playEpisode(episodeId: episode.episodeid, resume: resume)
            HapticService.notification(.success)
        } catch {
            Logger.playback.error("Failed to play episode: \(error.localizedDescription)")
            HapticService.notification(.error)
        }
    }

    func queueEpisode(_ episode: Episode) async {
        do {
            try await client.queueEpisode(episodeId: episode.episodeid)
            HapticService.notification(.success)
        } catch {
            Logger.playback.error("Failed to queue episode: \(error.localizedDescription)")
            HapticService.notification(.error)
        }
    }

    func toggleWatched(_ episode: Episode) async {
        do {
            try await client.setWatched(episodeId: episode.episodeid, watched: !episode.isWatched)
            // Refresh the episodes list
            if let tvShowId = episode.tvshowid {
                let show = TVShow(
                    tvshowid: tvShowId,
                    title: "",
                    year: nil,
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
                )
                await loadEpisodes(for: show, season: episode.season)
            }
            HapticService.notification(.success)
        } catch {
            Logger.networking.error("Failed to toggle watched status: \(error.localizedDescription)")
            HapticService.notification(.error)
        }
    }
}
