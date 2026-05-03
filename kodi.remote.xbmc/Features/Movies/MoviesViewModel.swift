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
        guard let libraryState = libraryState,
              let hostId = appState?.currentHost?.id else { return }

        // If we have in-memory data and not forcing refresh, skip
        if !forceRefresh && !libraryState.movies.isEmpty {
            return
        }

        // Try disk cache first when starting from empty
        if libraryState.movies.isEmpty {
            if let cached = await LibraryCacheService.shared.loadMovies(for: hostId) {
                await MainActor.run {
                    libraryState.movies = cached.movies
                    libraryState.moviesTotalCount = cached.movies.count
                    libraryState.lastMoviesSync = cached.savedAt
                    // Clear the skeleton flag now that real data is on screen.
                    // The background refresh handles its own staleness silently.
                    libraryState.isLoadingMovies = false
                }
                // Background refresh unless explicitly forced
                if !forceRefresh {
                    await backgroundRefreshMovies(hostId: hostId)
                    return
                }
            }
        }

        // Network fetch — show spinner only if no data to display
        let showSpinner = libraryState.movies.isEmpty
        await MainActor.run {
            if showSpinner { libraryState.isLoadingMovies = true }
            libraryState.moviesError = nil
        }

        do {
            let result = try await client.getMovies(sort: (field: "title", ascending: true))
            let movies = result.movies ?? []

            await MainActor.run {
                libraryState.movies = movies
                libraryState.moviesTotalCount = result.limits?.total ?? movies.count
                libraryState.lastMoviesSync = Date()
                libraryState.isLoadingMovies = false
            }

            await LibraryCacheService.shared.saveMovies(movies, for: hostId)
        } catch {
            await MainActor.run {
                if libraryState.movies.isEmpty {
                    libraryState.moviesError = error.localizedDescription
                }
                libraryState.isLoadingMovies = false
            }
        }
    }

    private func backgroundRefreshMovies(hostId: UUID) async {
        do {
            let result = try await client.getMovies(sort: (field: "title", ascending: true))
            let movies = result.movies ?? []

            await MainActor.run {
                libraryState?.movies = movies
                libraryState?.moviesTotalCount = result.limits?.total ?? movies.count
                libraryState?.lastMoviesSync = Date()
            }

            await LibraryCacheService.shared.saveMovies(movies, for: hostId)
        } catch {
            Logger.networking.warning("Background movie refresh failed: \(error.localizedDescription)")
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
