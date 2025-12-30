//
//  TVShow.swift
//  kodi.remote.xbmc
//

import Foundation

struct TVShow: Identifiable, Codable, Hashable {
    let tvshowid: Int
    let title: String
    let year: Int?
    let rating: Double?
    let plot: String?
    let genre: [String]?
    let studio: [String]?
    let cast: [CastMember]?
    let thumbnail: String?
    let fanart: String?
    let art: MediaArt?
    let episode: Int? // total episode count
    let watchedepisodes: Int?
    let season: Int? // total season count
    let playcount: Int?
    let file: String?
    let imdbnumber: String?
    let premiered: String?
    let dateadded: String?

    var id: Int { tvshowid }

    var posterPath: String? {
        art?.poster ?? thumbnail
    }

    var fanartPath: String? {
        art?.fanart ?? fanart
    }

    /// Returns the clearlogo path if available
    var clearlogoPath: String? {
        art?.clearlogo
    }

    var isFullyWatched: Bool {
        guard let total = episode, let watched = watchedepisodes else { return false }
        return watched >= total
    }

    var unwatchedCount: Int {
        guard let total = episode, let watched = watchedepisodes else { return 0 }
        return max(0, total - watched)
    }

    var formattedRating: String? {
        guard let rating = rating, rating > 0 else { return nil }
        return String(format: "%.1f", rating)
    }

    var genreText: String? {
        genre?.joined(separator: ", ")
    }
}

struct Season: Identifiable, Codable, Hashable {
    let seasonid: Int
    let season: Int
    let showtitle: String?
    let tvshowid: Int?
    let episode: Int? // episode count in season
    let watchedepisodes: Int?
    let thumbnail: String?
    let fanart: String?
    let art: MediaArt?
    let playcount: Int?

    var id: Int { seasonid }

    var posterPath: String? {
        art?.poster ?? thumbnail
    }

    var displayName: String {
        if season == 0 {
            return "Specials"
        }
        return "Season \(season)"
    }

    var isFullyWatched: Bool {
        guard let total = episode, let watched = watchedepisodes else { return false }
        return watched >= total
    }

    var unwatchedCount: Int {
        guard let total = episode, let watched = watchedepisodes else { return 0 }
        return max(0, total - watched)
    }
}

struct Episode: Identifiable, Codable, Hashable {
    let episodeid: Int
    let title: String
    let episode: Int
    let season: Int
    let showtitle: String?
    let tvshowid: Int?
    let runtime: Int?
    let rating: Double?
    let plot: String?
    let director: [String]?
    let writer: [String]?
    let thumbnail: String?
    let fanart: String?
    let playcount: Int?
    let resume: ResumePoint?
    let file: String?
    let firstaired: String?
    let dateadded: String?
    let streamdetails: StreamDetails?

    var id: Int { episodeid }

    var isWatched: Bool {
        (playcount ?? 0) > 0
    }

    var hasResume: Bool {
        guard let resume = resume else { return false }
        return resume.position > 0
    }

    var episodeNumber: String {
        String(format: "S%02dE%02d", season, episode)
    }

    var formattedRuntime: String? {
        guard let runtime = runtime, runtime > 0 else { return nil }
        let minutes = runtime / 60
        return "\(minutes)m"
    }

    var formattedRating: String? {
        guard let rating = rating, rating > 0 else { return nil }
        return String(format: "%.1f", rating)
    }
}

// MARK: - API Responses

struct TVShowsResponse: Decodable {
    let tvshows: [TVShow]?
    let limits: LimitsResult?
}

struct TVShowDetailsResponse: Decodable {
    let tvshowdetails: TVShow
}

struct SeasonsResponse: Decodable {
    let seasons: [Season]?
    let limits: LimitsResult?
}

struct EpisodesResponse: Decodable {
    let episodes: [Episode]?
    let limits: LimitsResult?
}

struct EpisodeDetailsResponse: Decodable {
    let episodedetails: Episode
}
