//
//  LibraryState.swift
//  kodi.remote.xbmc
//

import Foundation

@Observable
final class LibraryState {
    // Movies. isLoadingMovies defaults to true so the grid/list skeleton renders
    // on the very first paint — otherwise the empty-state view ("No Movies")
    // briefly shows before the network call begins and flips the flag.
    var movies: [Movie] = [] { didSet { invalidateMovieCache() } }
    var isLoadingMovies = true
    var moviesError: String?
    var moviesTotalCount = 0

    // TV Shows. Same first-paint reasoning as isLoadingMovies above.
    var tvShows: [TVShow] = [] { didSet { invalidateTVShowCache() } }
    var isLoadingTVShows = true
    var tvShowsError: String?
    var tvShowsTotalCount = 0

    // Caching
    var lastMoviesSync: Date?
    var lastTVShowsSync: Date?

    // Sorting
    var movieSortField: SortField = .title { didSet { invalidateMovieCache() } }
    var movieSortAscending = true { didSet { invalidateMovieCache() } }
    var tvShowSortField: SortField = .title { didSet { invalidateTVShowCache() } }
    var tvShowSortAscending = true { didSet { invalidateTVShowCache() } }

    // Filtering
    var movieFilter: LibraryFilter = .all { didSet { invalidateMovieCache() } }
    var tvShowFilter: LibraryFilter = .all { didSet { invalidateTVShowCache() } }
    var selectedMovieGenres: Set<String> = [] { didSet { invalidateMovieCache() } }
    var selectedTVShowGenres: Set<String> = [] { didSet { invalidateTVShowCache() } }

    // Memoized filter+sort results. Marked @ObservationIgnored so writes from
    // inside the computed-property getter don't generate observation events
    // (which would cause re-render loops).
    @ObservationIgnored private var cachedFilteredMovies: [Movie]?
    @ObservationIgnored private var cachedFilteredTVShows: [TVShow]?

    private func invalidateMovieCache() { cachedFilteredMovies = nil }
    private func invalidateTVShowCache() { cachedFilteredTVShows = nil }

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

        // Leave the loading flags ON so the skeleton stays up while the new
        // host's data is fetched — flipping them off here would briefly render
        // the empty state between hosts.
        isLoadingMovies = true
        isLoadingTVShows = true
    }

    /// Shuffle movies in-place for random sort
    func shuffleMovies() {
        movies.shuffle()
        // didSet on `movies` already invalidates the cache, but be explicit
        // for readers: the new order is what filteredMovies should reflect.
    }

    /// Shuffle TV shows in-place for random sort
    func shuffleTVShows() {
        tvShows.shuffle()
    }

    // MARK: - Filtering (chains off sorted)

    var filteredMovies: [Movie] {
        if let cached = cachedFilteredMovies { return cached }
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
        cachedFilteredMovies = source
        return source
    }

    var filteredTVShows: [TVShow] {
        if let cached = cachedFilteredTVShows { return cached }
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
        cachedFilteredTVShows = source
        return source
    }
}
