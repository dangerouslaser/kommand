//
//  KodiClient+TVShows.swift
//  kodi.remote.xbmc
//

import Foundation

extension KodiClient {
    func getTVShows(
        sort: (field: String, ascending: Bool) = ("title", true),
        start: Int = 0,
        limit: Int? = nil
    ) async throws -> TVShowsResponse {
        var params: [String: Any] = [
            "properties": ["title", "year", "rating", "plot", "genre", "studio", "cast",
                          "thumbnail", "fanart", "art", "episode", "watchedepisodes", "season",
                          "playcount", "file", "imdbnumber", "premiered", "dateadded", "lastplayed"],
            "sort": ["method": sort.field, "order": sort.ascending ? "ascending" : "descending"]
        ]
        if let limit {
            params["limits"] = ["start": start, "end": start + limit]
        }
        return try await send(method: "VideoLibrary.GetTVShows", params: params)
    }

    func getTVShowDetails(tvShowId: Int) async throws -> TVShowDetailsResponse {
        try await send(method: "VideoLibrary.GetTVShowDetails", params: [
            "tvshowid": tvShowId,
            "properties": ["title", "year", "rating", "plot", "genre", "studio", "cast",
                          "thumbnail", "fanart", "art", "episode", "watchedepisodes", "season",
                          "playcount", "file", "imdbnumber", "premiered", "dateadded"]
        ])
    }

    func getSeasons(tvShowId: Int) async throws -> SeasonsResponse {
        try await send(method: "VideoLibrary.GetSeasons", params: [
            "tvshowid": tvShowId,
            "properties": ["season", "showtitle", "tvshowid", "episode", "watchedepisodes",
                          "thumbnail", "fanart", "art", "playcount"],
            "sort": ["method": "season", "order": "ascending"]
        ])
    }

    func getEpisodes(
        tvShowId: Int,
        season: Int? = nil,
        start: Int = 0,
        limit: Int = 100
    ) async throws -> EpisodesResponse {
        var params: [String: Any] = [
            "tvshowid": tvShowId,
            "properties": ["title", "episode", "season", "showtitle", "tvshowid", "runtime",
                          "rating", "plot", "director", "writer", "thumbnail", "fanart",
                          "playcount", "resume", "file", "firstaired", "dateadded", "streamdetails"],
            "sort": ["method": "episode", "order": "ascending"],
            "limits": ["start": start, "end": start + limit]
        ]
        if let season = season {
            params["season"] = season
        }
        return try await send(method: "VideoLibrary.GetEpisodes", params: params)
    }

    func getEpisodeDetails(episodeId: Int) async throws -> EpisodeDetailsResponse {
        try await send(method: "VideoLibrary.GetEpisodeDetails", params: [
            "episodeid": episodeId,
            "properties": ["title", "episode", "season", "showtitle", "tvshowid", "runtime",
                          "rating", "plot", "director", "writer", "thumbnail", "fanart",
                          "playcount", "resume", "file", "firstaired", "dateadded", "streamdetails"]
        ])
    }

    func getRecentlyAddedEpisodes(limit: Int = 200) async throws -> EpisodesResponse {
        try await send(method: "VideoLibrary.GetEpisodes", params: [
            "properties": ["title", "episode", "season", "showtitle", "tvshowid", "runtime",
                          "rating", "plot", "director", "writer", "thumbnail", "fanart",
                          "playcount", "resume", "file", "firstaired", "dateadded", "streamdetails"],
            "sort": ["method": "dateadded", "order": "descending"],
            "limits": ["start": 0, "end": limit]
        ])
    }

    func getInProgressEpisodes() async throws -> EpisodesResponse {
        try await send(method: "VideoLibrary.GetEpisodes", params: [
            "properties": ["title", "episode", "season", "showtitle", "tvshowid", "runtime",
                          "rating", "plot", "director", "writer", "thumbnail", "fanart",
                          "playcount", "resume", "file", "firstaired", "dateadded", "streamdetails"],
            "filter": ["field": "inprogress", "operator": "true", "value": ""],
            "sort": ["method": "lastplayed", "order": "descending"]
        ])
    }

    func playEpisode(episodeId: Int, resume: Bool = false) async throws {
        let _: String = try await send(method: "Player.Open", params: [
            "item": ["episodeid": episodeId],
            "options": ["resume": resume]
        ])
    }

    func queueEpisode(episodeId: Int) async throws {
        let _: String = try await send(method: "Playlist.Add", params: [
            "playlistid": 1,
            "item": ["episodeid": episodeId]
        ])
    }

    func setWatched(episodeId: Int, watched: Bool) async throws {
        let _: String = try await send(method: "VideoLibrary.SetEpisodeDetails", params: [
            "episodeid": episodeId,
            "playcount": watched ? 1 : 0
        ])
    }

    func searchTVShows(query: String, limit: Int = 25) async throws -> TVShowsResponse {
        try await send(method: "VideoLibrary.GetTVShows", params: [
            "properties": ["title", "year", "rating", "plot", "genre", "studio", "cast",
                          "thumbnail", "fanart", "art", "episode", "watchedepisodes", "season",
                          "playcount", "file", "imdbnumber", "premiered", "dateadded", "lastplayed"],
            "filter": ["field": "title", "operator": "contains", "value": query],
            "sort": ["method": "title", "order": "ascending"],
            "limits": ["start": 0, "end": limit]
        ])
    }

    func searchEpisodes(query: String, limit: Int = 25) async throws -> EpisodesResponse {
        try await send(method: "VideoLibrary.GetEpisodes", params: [
            "properties": ["title", "episode", "season", "showtitle", "tvshowid", "runtime",
                          "rating", "plot", "director", "writer", "thumbnail", "fanart",
                          "playcount", "resume", "file", "firstaired", "dateadded", "streamdetails"],
            "filter": ["field": "title", "operator": "contains", "value": query],
            "sort": ["method": "title", "order": "ascending"],
            "limits": ["start": 0, "end": limit]
        ])
    }
}
