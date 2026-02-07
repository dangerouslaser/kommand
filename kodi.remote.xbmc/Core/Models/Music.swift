//
//  Music.swift
//  kodi.remote.xbmc
//

import Foundation

struct Artist: Identifiable, Codable, Hashable, Sendable {
    let artistid: Int
    let artist: String
    let label: String?
    let description: String?
    let genre: [String]?
    let thumbnail: String?
    let fanart: String?
    let art: MediaArt?

    var id: Int { artistid }

    var displayName: String {
        artist
    }

    var artworkPath: String? {
        art?.thumb ?? art?.fanart ?? thumbnail ?? fanart
    }
}

struct Album: Identifiable, Codable, Hashable, Sendable {
    let albumid: Int
    let title: String
    let label: String?
    let artist: [String]?
    let displayartist: String?
    let year: Int?
    let genre: [String]?
    let rating: Double?
    let thumbnail: String?
    let fanart: String?
    let art: MediaArt?
    let playcount: Int?
    let artistid: [Int]?
    let dateadded: String?

    var id: Int { albumid }

    var artistText: String? {
        displayartist ?? artist?.joined(separator: ", ")
    }

    var artworkPath: String? {
        art?.thumb ?? thumbnail
    }

    var genreText: String? {
        genre?.joined(separator: ", ")
    }
}

struct Song: Identifiable, Codable, Hashable, Sendable {
    let songid: Int
    let title: String
    let label: String?
    let artist: [String]?
    let displayartist: String?
    let album: String?
    let albumid: Int?
    let albumartist: [String]?
    let track: Int?
    let disc: Int?
    let duration: Int? // in seconds
    let year: Int?
    let genre: [String]?
    let rating: Double?
    let playcount: Int?
    let thumbnail: String?
    let fanart: String?
    let art: MediaArt?
    let file: String?
    let dateadded: String?
    let lastplayed: String?

    var id: Int { songid }

    var artistText: String? {
        displayartist ?? artist?.joined(separator: ", ")
    }

    var artworkPath: String? {
        art?.thumb ?? thumbnail
    }

    var formattedDuration: String? {
        guard let duration = duration, duration > 0 else { return nil }
        let minutes = duration / 60
        let seconds = duration % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    var trackNumber: String? {
        guard let track = track else { return nil }
        if let disc = disc, disc > 1 {
            return "\(disc)-\(track)"
        }
        return "\(track)"
    }
}

// MARK: - API Responses

struct ArtistsResponse: Decodable {
    let artists: [Artist]?
    let limits: LimitsResult?
}

struct ArtistDetailsResponse: Decodable {
    let artistdetails: Artist
}

struct AlbumsResponse: Decodable {
    let albums: [Album]?
    let limits: LimitsResult?
}

struct AlbumDetailsResponse: Decodable {
    let albumdetails: Album
}

struct SongsResponse: Decodable {
    let songs: [Song]?
    let limits: LimitsResult?
}

struct SongDetailsResponse: Decodable {
    let songdetails: Song
}

// MARK: - Recently Added

struct RecentlyAddedAlbumsResponse: Decodable {
    let albums: [Album]?
}

struct RecentlyAddedSongsResponse: Decodable {
    let songs: [Song]?
}
