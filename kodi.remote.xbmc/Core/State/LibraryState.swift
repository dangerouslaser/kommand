//
//  LibraryState.swift
//  kodi.remote.xbmc
//

import Foundation

@Observable
final class LibraryState {
    // Movies
    var movies: [Movie] = []
    var isLoadingMovies = false
    var moviesError: String?
    var moviesTotalCount = 0

    // TV Shows
    var tvShows: [TVShow] = []
    var isLoadingTVShows = false
    var tvShowsError: String?
    var tvShowsTotalCount = 0

    // Caching
    var lastMoviesSync: Date?
    var lastTVShowsSync: Date?

    // Sorting
    var movieSortField: SortField = .title
    var movieSortAscending = true
    var tvShowSortField: SortField = .title
    var tvShowSortAscending = true

    // Filtering
    var movieFilter: LibraryFilter = .all
    var tvShowFilter: LibraryFilter = .all
    var selectedMovieGenres: Set<String> = []
    var selectedTVShowGenres: Set<String> = []

    enum SortField: String, CaseIterable {
        case title = "title"
        case year = "year"
        case rating = "rating"
        case dateadded = "dateadded"
        case lastplayed = "lastplayed"
        case random = "random"

        var displayName: String {
            switch self {
            case .title: return "Title"
            case .year: return "Year"
            case .rating: return "Rating"
            case .dateadded: return "Date Added"
            case .lastplayed: return "Last Played"
            case .random: return "Random"
            }
        }
    }

    enum LibraryFilter: String, CaseIterable {
        case all = "all"
        case unwatched = "unwatched"
        case inProgress = "inProgress"

        var displayName: String {
            switch self {
            case .all: return "All"
            case .unwatched: return "Unwatched"
            case .inProgress: return "In Progress"
            }
        }
    }

    // MARK: - Available Genres

    var availableMovieGenres: [String] {
        Array(Set(movies.compactMap { $0.genre }.flatMap { $0 })).sorted()
    }

    var availableTVShowGenres: [String] {
        Array(Set(tvShows.compactMap { $0.genre }.flatMap { $0 })).sorted()
    }

    // MARK: - Client-Side Sorting

    var sortedMovies: [Movie] {
        switch movieSortField {
        case .title:
            return movieSortAscending
                ? movies.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
                : movies.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedDescending }
        case .year:
            return movies.sorted { movieSortAscending ? ($0.year ?? 0) < ($1.year ?? 0) : ($0.year ?? 0) > ($1.year ?? 0) }
        case .rating:
            return movies.sorted { movieSortAscending ? ($0.rating ?? 0) < ($1.rating ?? 0) : ($0.rating ?? 0) > ($1.rating ?? 0) }
        case .dateadded:
            return movies.sorted { movieSortAscending ? ($0.dateadded ?? "") < ($1.dateadded ?? "") : ($0.dateadded ?? "") > ($1.dateadded ?? "") }
        case .lastplayed:
            return movies.sorted { movieSortAscending ? ($0.lastplayed ?? "") < ($1.lastplayed ?? "") : ($0.lastplayed ?? "") > ($1.lastplayed ?? "") }
        case .random:
            return movies // Shuffled in-place when user selects random
        }
    }

    var sortedTVShows: [TVShow] {
        switch tvShowSortField {
        case .title:
            return tvShowSortAscending
                ? tvShows.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
                : tvShows.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedDescending }
        case .year:
            return tvShows.sorted { tvShowSortAscending ? ($0.year ?? 0) < ($1.year ?? 0) : ($0.year ?? 0) > ($1.year ?? 0) }
        case .rating:
            return tvShows.sorted { tvShowSortAscending ? ($0.rating ?? 0) < ($1.rating ?? 0) : ($0.rating ?? 0) > ($1.rating ?? 0) }
        case .dateadded:
            return tvShows.sorted { tvShowSortAscending ? ($0.dateadded ?? "") < ($1.dateadded ?? "") : ($0.dateadded ?? "") > ($1.dateadded ?? "") }
        case .lastplayed:
            return tvShows.sorted { tvShowSortAscending ? ($0.lastplayed ?? "") < ($1.lastplayed ?? "") : ($0.lastplayed ?? "") > ($1.lastplayed ?? "") }
        case .random:
            return tvShows // Shuffled in-place when user selects random
        }
    }

    /// Clear all loaded data; preserves user-chosen sort/filter preferences.
    /// Call when switching hosts so stale library data from another host doesn't leak through.
    func reset() {
        movies = []
        moviesError = nil
        moviesTotalCount = 0
        lastMoviesSync = nil

        tvShows = []
        tvShowsError = nil
        tvShowsTotalCount = 0
        lastTVShowsSync = nil

        isLoadingMovies = false
        isLoadingTVShows = false
    }

    /// Shuffle movies in-place for random sort
    func shuffleMovies() {
        movies.shuffle()
    }

    /// Shuffle TV shows in-place for random sort
    func shuffleTVShows() {
        tvShows.shuffle()
    }

    // MARK: - Filtering (chains off sorted)

    var filteredMovies: [Movie] {
        var source = sortedMovies
        switch movieFilter {
        case .all: break
        case .unwatched:
            source = source.filter { !$0.isWatched }
        case .inProgress:
            source = source.filter { $0.hasResume }
        }
        if !selectedMovieGenres.isEmpty {
            source = source.filter { movie in
                guard let genres = movie.genre else { return false }
                return !selectedMovieGenres.isDisjoint(with: genres)
            }
        }
        return source
    }

    var filteredTVShows: [TVShow] {
        var source = sortedTVShows
        switch tvShowFilter {
        case .all: break
        case .unwatched:
            source = source.filter { !$0.isFullyWatched }
        case .inProgress:
            source = source.filter { ($0.watchedepisodes ?? 0) > 0 && !$0.isFullyWatched }
        }
        if !selectedTVShowGenres.isEmpty {
            source = source.filter { show in
                guard let genres = show.genre else { return false }
                return !selectedTVShowGenres.isDisjoint(with: genres)
            }
        }
        return source
    }
}
