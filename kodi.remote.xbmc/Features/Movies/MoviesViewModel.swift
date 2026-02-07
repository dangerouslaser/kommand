//
//  MoviesViewModel.swift
//  kodi.remote.xbmc
//

import Foundation
import SwiftUI
import os

@Observable
final class MoviesViewModel {
    private var appState: AppState?
    private var libraryState: LibraryState?
    private var client = KodiClient() // Replaced in configure() with shared instance

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

    // For actor filmography view
    var actorMovies: [Movie] = []
    var isLoadingActorMovies = false

    // MARK: - Loading

    func loadMovies(forceRefresh: Bool = false) async {
        guard let libraryState = libraryState else { return }

        // Skip if already loaded and not forcing refresh
        if !forceRefresh && !libraryState.movies.isEmpty {
            return
        }

        await MainActor.run {
            libraryState.isLoadingMovies = true
            libraryState.moviesError = nil
        }

        do {
            let sortField = await MainActor.run { libraryState.movieSortField }
            let sortAscending = await MainActor.run { libraryState.movieSortAscending }

            let result = try await client.getMovies(
                sort: (field: sortField.rawValue, ascending: sortAscending),
                start: 0,
                limit: 1000
            )

            await MainActor.run {
                libraryState.movies = result.movies ?? []
                libraryState.moviesTotalCount = result.limits?.total ?? 0
                libraryState.lastMoviesSync = Date()
                libraryState.isLoadingMovies = false
            }
        } catch {
            await MainActor.run {
                libraryState.moviesError = error.localizedDescription
                libraryState.isLoadingMovies = false
            }
        }
    }

    func loadMoviesByActor(_ actorName: String) async {
        await MainActor.run {
            isLoadingActorMovies = true
            actorMovies = []
        }

        do {
            let result = try await client.getMoviesByActor(actorName: actorName)
            await MainActor.run {
                actorMovies = result.movies ?? []
                isLoadingActorMovies = false
            }
        } catch {
            Logger.networking.error("Failed to load movies by actor: \(error.localizedDescription)")
            await MainActor.run {
                isLoadingActorMovies = false
            }
        }
    }

    // MARK: - Playback

    func playMovie(_ movie: Movie, resume: Bool = false) async {
        do {
            try await client.playMovie(movieId: movie.movieid, resume: resume)
            HapticService.notification(.success)
        } catch {
            Logger.playback.error("Failed to play movie: \(error.localizedDescription)")
            HapticService.notification(.error)
        }
    }

    func queueMovie(_ movie: Movie) async {
        do {
            try await client.queueMovie(movieId: movie.movieid)
            HapticService.notification(.success)
        } catch {
            Logger.playback.error("Failed to queue movie: \(error.localizedDescription)")
            HapticService.notification(.error)
        }
    }

    func toggleWatched(_ movie: Movie) async {
        do {
            try await client.setWatched(movieId: movie.movieid, watched: !movie.isWatched)
            // Refresh the movie in the list
            await loadMovies(forceRefresh: true)
            HapticService.notification(.success)
        } catch {
            Logger.networking.error("Failed to toggle watched status: \(error.localizedDescription)")
            HapticService.notification(.error)
        }
    }
}
