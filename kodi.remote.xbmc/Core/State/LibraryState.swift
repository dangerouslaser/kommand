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

    var filteredMovies: [Movie] {
        let filtered: [Movie]
        switch movieFilter {
        case .all:
            filtered = movies
        case .unwatched:
            filtered = movies.filter { !$0.isWatched }
        case .inProgress:
            filtered = movies.filter { $0.hasResume }
        }
        return filtered
    }

    var filteredTVShows: [TVShow] {
        let filtered: [TVShow]
        switch tvShowFilter {
        case .all:
            filtered = tvShows
        case .unwatched:
            filtered = tvShows.filter { !$0.isFullyWatched }
        case .inProgress:
            filtered = tvShows.filter { ($0.watchedepisodes ?? 0) > 0 && !$0.isFullyWatched }
        }
        return filtered
    }
}
