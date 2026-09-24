//
//  KodiClient+Movies.swift
//  kodi.remote.xbmc
//

import Foundation

extension KodiClient {
    // MARK: - Video Library

    func getMovies(
        sort: (field: String, ascending: Bool) = ("title", true),
        start: Int = 0,
        limit: Int? = nil
    ) async throws -> MoviesResponse {
        var params: [String: Any] = [
            "properties": ["title", "year", "runtime", "rating", "plot", "genre", "director",
                          "writer", "studio", "tagline", "cast", "thumbnail", "fanart", "art",
                          "playcount", "resume", "file", "trailer", "mpaa", "imdbnumber",
                          "dateadded", "lastplayed", "streamdetails"],
            "sort": ["method": sort.field, "order": sort.ascending ? "ascending" : "descending"]
        ]
        if let limit {
            params["limits"] = ["start": start, "end": start + limit]
        }
        return try await send(method: "VideoLibrary.GetMovies", params: params)
    }

    func getMoviesByActor(actorName: String) async throws -> MoviesResponse {
        try await send(method: "VideoLibrary.GetMovies", params: [
            "properties": ["title", "year", "runtime", "rating", "plot", "genre", "director",
                          "writer", "studio", "tagline", "cast", "thumbnail", "fanart", "art",
                          "playcount", "resume", "file", "trailer", "mpaa", "imdbnumber",
                          "dateadded", "lastplayed", "streamdetails"],
            "filter": ["actor": actorName],
            "sort": ["method": "year", "order": "descending"]
        ])
    }

    func getMovieDetails(movieId: Int) async throws -> MovieDetailsResponse {
        try await send(method: "VideoLibrary.GetMovieDetails", params: [
            "movieid": movieId,
            "properties": ["title", "year", "runtime", "rating", "plot", "genre", "director",
                          "writer", "studio", "tagline", "cast", "thumbnail", "fanart", "art",
                          "playcount", "resume", "file", "trailer", "mpaa", "imdbnumber",
                          "dateadded", "lastplayed", "streamdetails"]
        ])
    }

    func getRecentlyAddedMovies(limit: Int = 25) async throws -> MoviesResponse {
        try await send(method: "VideoLibrary.GetRecentlyAddedMovies", params: [
            "properties": ["title", "year", "runtime", "rating", "plot", "genre", "director",
                          "writer", "studio", "tagline", "cast", "thumbnail", "fanart", "art",
                          "playcount", "resume", "file", "trailer", "mpaa", "imdbnumber",
                          "dateadded", "lastplayed", "streamdetails"],
            "limits": ["start": 0, "end": limit]
        ])
    }

    func getInProgressMovies() async throws -> MoviesResponse {
        try await send(method: "VideoLibrary.GetMovies", params: [
            "properties": ["title", "year", "runtime", "rating", "plot", "genre", "director",
                          "writer", "studio", "tagline", "cast", "thumbnail", "fanart", "art",
                          "playcount", "resume", "file", "trailer", "mpaa", "imdbnumber",
                          "dateadded", "lastplayed", "streamdetails"],
            "filter": ["field": "inprogress", "operator": "true", "value": ""],
            "sort": ["method": "lastplayed", "order": "descending"]
        ])
    }

    // MARK: - Playback from Library

    func playMovie(movieId: Int, resume: Bool = false) async throws {
        let _: String = try await send(method: "Player.Open", params: [
            "item": ["movieid": movieId],
            "options": ["resume": resume]
        ])
    }

    func queueMovie(movieId: Int) async throws {
        let _: String = try await send(method: "Playlist.Add", params: [
            "playlistid": 1,
            "item": ["movieid": movieId]
        ])
    }

    func setWatched(movieId: Int, watched: Bool) async throws {
        let _: String = try await send(method: "VideoLibrary.SetMovieDetails", params: [
            "movieid": movieId,
            "playcount": watched ? 1 : 0
        ])
    }

    // MARK: - Search

    func searchMovies(query: String, limit: Int = 25) async throws -> MoviesResponse {
        try await send(method: "VideoLibrary.GetMovies", params: [
            "properties": ["title", "year", "runtime", "rating", "plot", "genre", "director",
                          "writer", "studio", "tagline", "cast", "thumbnail", "fanart", "art",
                          "playcount", "resume", "file", "trailer", "mpaa", "imdbnumber",
                          "dateadded", "lastplayed", "streamdetails"],
            "filter": ["field": "title", "operator": "contains", "value": query],
            "sort": ["method": "title", "order": "ascending"],
            "limits": ["start": 0, "end": limit]
        ])
    }
}
