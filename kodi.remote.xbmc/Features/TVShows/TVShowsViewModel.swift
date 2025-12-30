//
//  TVShowsViewModel.swift
//  kodi.remote.xbmc
//

import Foundation
import SwiftUI

@Observable
final class TVShowsViewModel {
    private var appState: AppState?
    private var libraryState: LibraryState?
    private let client = KodiClient()

    // Cached data for detail views
    var seasons: [Season] = []
    var episodes: [Episode] = []
    var isLoadingSeasons = false
    var isLoadingEpisodes = false

    func configure(appState: AppState, libraryState: LibraryState) {
        self.appState = appState
        self.libraryState = libraryState
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
            let sortField = await MainActor.run { libraryState.tvShowSortField.rawValue }
            let sortAscending = await MainActor.run { libraryState.tvShowSortAscending }

            let response = try await client.getTVShows(
                sort: (field: sortField, ascending: sortAscending),
                start: 0,
                limit: 1000
            )

            await MainActor.run {
                libraryState.tvShows = response.tvshows ?? []
                libraryState.tvShowsTotalCount = response.limits?.total ?? libraryState.tvShows.count
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
            await MainActor.run {
                isLoadingSeasons = false
            }
            print("Load seasons error: \(error)")
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
            await MainActor.run {
                isLoadingEpisodes = false
            }
            print("Load episodes error: \(error)")
        }
    }

    // MARK: - Playback

    func playEpisode(_ episode: Episode, resume: Bool = false) async {
        do {
            try await client.playEpisode(episodeId: episode.episodeid, resume: resume)
            triggerHaptic(.success)
        } catch {
            print("Play error: \(error)")
            triggerHaptic(.error)
        }
    }

    func queueEpisode(_ episode: Episode) async {
        do {
            try await client.queueEpisode(episodeId: episode.episodeid)
            triggerHaptic(.success)
        } catch {
            print("Queue error: \(error)")
            triggerHaptic(.error)
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
            triggerHaptic(.success)
        } catch {
            print("Toggle watched error: \(error)")
            triggerHaptic(.error)
        }
    }

    // MARK: - Haptics

    private func triggerHaptic(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(type)
    }
}
