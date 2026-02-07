//
//  Music.swift
//  kodi.remote.xbmc
//

import Foundation

nonisolated struct Artist: Identifiable, Codable, Hashable, Sendable {
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

nonisolated struct Album: Identifiable, Codable, Hashable, Sendable {
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

nonisolated struct Song: Identifiable, Codable, Hashable, Sendable {
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

nonisolated struct ArtistsResponse: Decodable, Sendable {
    let artists: [Artist]?
    let limits: LimitsResult?
}

nonisolated struct ArtistDetailsResponse: Decodable, Sendable {
    let artistdetails: Artist
}

nonisolated struct AlbumsResponse: Decodable, Sendable {
    let albums: [Album]?
    let limits: LimitsResult?
}

nonisolated struct AlbumDetailsResponse: Decodable, Sendable {
    let albumdetails: Album
}

nonisolated struct SongsResponse: Decodable, Sendable {
    let songs: [Song]?
    let limits: LimitsResult?
}

nonisolated struct SongDetailsResponse: Decodable, Sendable {
    let songdetails: Song
}

// MARK: - Recently Added

nonisolated struct RecentlyAddedAlbumsResponse: Decodable, Sendable {
    let albums: [Album]?
}

nonisolated struct RecentlyAddedSongsResponse: Decodable, Sendable {
    let songs: [Song]?
}
