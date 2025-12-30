//
//  MoviesViewModel.swift
//  kodi.remote.xbmc
//

import Foundation
import SwiftUI

@Observable
final class MoviesViewModel {
    private var appState: AppState?
    private var libraryState: LibraryState?
    private var client = KodiClient()

    func configure(appState: AppState, libraryState: LibraryState) {
        self.appState = appState
        self.libraryState = libraryState
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
            await MainActor.run {
                isLoadingActorMovies = false
            }
            print("Error loading movies for actor: \(error)")
        }
    }

    // MARK: - Playback

    func playMovie(_ movie: Movie, resume: Bool = false) async {
        do {
            try await client.playMovie(movieId: movie.movieid, resume: resume)
            triggerHaptic(.success)
        } catch {
            print("Play error: \(error)")
            triggerHaptic(.error)
        }
    }

    func queueMovie(_ movie: Movie) async {
        do {
            try await client.queueMovie(movieId: movie.movieid)
            triggerHaptic(.success)
        } catch {
            print("Queue error: \(error)")
            triggerHaptic(.error)
        }
    }

    func toggleWatched(_ movie: Movie) async {
        do {
            try await client.setWatched(movieId: movie.movieid, watched: !movie.isWatched)
            // Refresh the movie in the list
            await loadMovies(forceRefresh: true)
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
