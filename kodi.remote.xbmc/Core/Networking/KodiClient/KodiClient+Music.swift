//
//  KodiClient+Music.swift
//  kodi.remote.xbmc
//

import Foundation

extension KodiClient {
    // MARK: - Audio Library

    func getArtists(
        sort: (field: String, ascending: Bool) = ("artist", true),
        start: Int = 0,
        limit: Int = 500
    ) async throws -> ArtistsResponse {
        try await send(method: "AudioLibrary.GetArtists", params: [
            "properties": ["description", "genre", "thumbnail", "fanart", "art"],
            "sort": ["method": sort.field, "order": sort.ascending ? "ascending" : "descending"],
            "limits": ["start": start, "end": start + limit]
        ])
    }

    func getAlbums(
        artistId: Int? = nil,
        sort: (field: String, ascending: Bool) = ("title", true),
        start: Int = 0,
        limit: Int = 500
    ) async throws -> AlbumsResponse {
        var params: [String: Any] = [
            "properties": ["title", "artist", "displayartist", "year", "genre", "rating",
                          "thumbnail", "fanart", "art", "playcount", "artistid", "dateadded"],
            "sort": ["method": sort.field, "order": sort.ascending ? "ascending" : "descending"],
            "limits": ["start": start, "end": start + limit]
        ]
        if let artistId = artistId {
            params["filter"] = ["artistid": artistId]
        }
        return try await send(method: "AudioLibrary.GetAlbums", params: params)
    }

    func getRecentlyAddedAlbums(limit: Int = 25) async throws -> AlbumsResponse {
        try await send(method: "AudioLibrary.GetRecentlyAddedAlbums", params: [
            "properties": ["title", "artist", "displayartist", "year", "genre", "rating",
                          "thumbnail", "fanart", "art", "playcount", "artistid", "dateadded"],
            "limits": ["start": 0, "end": limit]
        ])
    }

    func getSongs(
        albumId: Int? = nil,
        artistId: Int? = nil,
        sort: (field: String, ascending: Bool) = ("track", true),
        start: Int = 0,
        limit: Int = 500
    ) async throws -> SongsResponse {
        var params: [String: Any] = [
            "properties": ["title", "artist", "displayartist", "album", "albumid", "albumartist",
                          "track", "disc", "duration", "year", "genre", "rating", "playcount",
                          "thumbnail", "fanart", "art", "file", "dateadded", "lastplayed"],
            "sort": ["method": sort.field, "order": sort.ascending ? "ascending" : "descending"],
            "limits": ["start": start, "end": start + limit]
        ]
        if let albumId = albumId {
            params["filter"] = ["albumid": albumId]
        } else if let artistId = artistId {
            params["filter"] = ["artistid": artistId]
        }
        return try await send(method: "AudioLibrary.GetSongs", params: params)
    }

    func getRecentlyAddedSongs(limit: Int = 25) async throws -> SongsResponse {
        try await send(method: "AudioLibrary.GetRecentlyAddedSongs", params: [
            "properties": ["title", "artist", "displayartist", "album", "albumid", "albumartist",
                          "track", "disc", "duration", "year", "genre", "rating", "playcount",
                          "thumbnail", "fanart", "art", "file", "dateadded", "lastplayed"],
            "limits": ["start": 0, "end": limit]
        ])
    }

    // MARK: - Audio Playback

    func playAlbum(albumId: Int, shuffle: Bool = false) async throws {
        // Clear playlist, add album, then play
        let _: String = try await send(method: "Playlist.Clear", params: ["playlistid": 0])
        let _: String = try await send(method: "Playlist.Add", params: [
            "playlistid": 0,
            "item": ["albumid": albumId]
        ])
        let _: String = try await send(method: "Player.Open", params: [
            "item": ["playlistid": 0],
            "options": ["shuffled": shuffle]
        ])
    }

    func playSong(songId: Int) async throws {
        let _: String = try await send(method: "Player.Open", params: [
            "item": ["songid": songId]
        ])
    }

    func queueAlbum(albumId: Int) async throws {
        let _: String = try await send(method: "Playlist.Add", params: [
            "playlistid": 0,
            "item": ["albumid": albumId]
        ])
    }

    func queueSong(songId: Int) async throws {
        let _: String = try await send(method: "Playlist.Add", params: [
            "playlistid": 0,
            "item": ["songid": songId]
        ])
    }

    func playArtist(artistId: Int, shuffle: Bool = true) async throws {
        let _: String = try await send(method: "Playlist.Clear", params: ["playlistid": 0])
        let _: String = try await send(method: "Playlist.Add", params: [
            "playlistid": 0,
            "item": ["artistid": artistId]
        ])
        let _: String = try await send(method: "Player.Open", params: [
            "item": ["playlistid": 0],
            "options": ["shuffled": shuffle]
        ])
    }
}
