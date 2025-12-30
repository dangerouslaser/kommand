//
//  Movie.swift
//  kodi.remote.xbmc
//

import Foundation

struct Movie: Identifiable, Codable, Hashable {
    let movieid: Int
    let title: String
    let year: Int?
    let runtime: Int? // in seconds
    let rating: Double?
    let plot: String?
    let genre: [String]?
    let director: [String]?
    let writer: [String]?
    let studio: [String]?
    let tagline: String?
    let cast: [CastMember]?
    let thumbnail: String?
    let fanart: String?
    let art: MediaArt?
    let playcount: Int?
    let resume: ResumePoint?
    let file: String?
    let trailer: String?
    let mpaa: String?
    let imdbnumber: String?
    let dateadded: String?
    let lastplayed: String?
    let streamdetails: StreamDetails?

    var id: Int { movieid }

    /// Returns the best image for a poster (prefers art.poster over thumbnail)
    var posterPath: String? {
        art?.poster ?? thumbnail
    }

    /// Returns the best image for a background
    var fanartPath: String? {
        art?.fanart ?? fanart
    }

    /// Returns the clearlogo path if available
    var clearlogoPath: String? {
        art?.clearlogo
    }

    var isWatched: Bool {
        (playcount ?? 0) > 0
    }

    var hasResume: Bool {
        guard let resume = resume else { return false }
        return resume.position > 0
    }

    var formattedRuntime: String? {
        guard let runtime = runtime, runtime > 0 else { return nil }
        let hours = runtime / 3600
        let minutes = (runtime % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }

    var formattedRating: String? {
        guard let rating = rating, rating > 0 else { return nil }
        return String(format: "%.1f", rating)
    }

    var genreText: String? {
        genre?.joined(separator: ", ")
    }

    var directorText: String? {
        director?.joined(separator: ", ")
    }
}

struct CastMember: Codable, Hashable, Identifiable {
    let name: String
    let role: String?
    let thumbnail: String?
    let order: Int?

    var id: String { name }
}

struct ResumePoint: Codable, Hashable {
    let position: Double // in seconds
    let total: Double

    var progress: Double {
        guard total > 0 else { return 0 }
        return position / total
    }

    var formattedPosition: String {
        TimeInterval(position).formattedDuration
    }
}

// MARK: - API Response

struct MoviesResponse: Decodable {
    let movies: [Movie]?
    let limits: LimitsResult?
}

struct MovieDetailsResponse: Decodable {
    let moviedetails: Movie
}

struct LimitsResult: Decodable {
    let start: Int
    let end: Int
    let total: Int
}

struct MediaArt: Codable, Hashable {
    let poster: String?
    let fanart: String?
    let thumb: String?
    let banner: String?
    let landscape: String?
    let clearlogo: String?
    let clearart: String?
}

// MARK: - Stream Details

struct StreamDetails: Codable, Hashable {
    let video: [VideoStream]?
    let audio: [AudioStreamDetail]?
    let subtitle: [SubtitleStream]?

    /// Returns the primary video stream (first one)
    var primaryVideo: VideoStream? {
        video?.first
    }

    /// Returns the primary audio stream (first one)
    var primaryAudio: AudioStreamDetail? {
        audio?.first
    }
}

struct VideoStream: Codable, Hashable {
    let codec: String?
    let aspect: Double?
    let width: Int?
    let height: Int?
    let duration: Int?
    let stereomode: String?
    let hdrtype: String?

    /// Returns a formatted resolution string (e.g., "4K", "1080p", "720p")
    var resolutionLabel: String? {
        guard let height = height else { return nil }
        if height >= 2160 { return "4K" }
        if height >= 1080 { return "1080p" }
        if height >= 720 { return "720p" }
        if height >= 480 { return "480p" }
        return "\(height)p"
    }

    /// Returns the HDR format label
    var hdrLabel: String? {
        guard let hdr = hdrtype, !hdr.isEmpty else { return nil }
        switch hdr.lowercased() {
        case "dolbyvision": return "Dolby Vision"
        case "hdr10": return "HDR10"
        case "hdr10plus": return "HDR10+"
        case "hlg": return "HLG"
        default: return hdr.uppercased()
        }
    }

    /// Returns a short HDR badge text
    var hdrBadge: String? {
        guard let hdr = hdrtype, !hdr.isEmpty else { return nil }
        switch hdr.lowercased() {
        case "dolbyvision": return "DV"
        case "hdr10": return "HDR10"
        case "hdr10plus": return "HDR10+"
        case "hlg": return "HLG"
        default: return "HDR"
        }
    }

    /// Returns the video codec label
    var codecLabel: String? {
        guard let codec = codec, !codec.isEmpty else { return nil }
        switch codec.lowercased() {
        case "hevc", "h265": return "HEVC"
        case "h264", "avc1", "avc": return "H.264"
        case "av1": return "AV1"
        case "vp9": return "VP9"
        case "mpeg2video": return "MPEG-2"
        case "vc1": return "VC-1"
        default: return codec.uppercased()
        }
    }
}

struct AudioStreamDetail: Codable, Hashable {
    let codec: String?
    let channels: Int?
    let language: String?

    /// Returns the audio codec label
    var codecLabel: String? {
        guard let codec = codec, !codec.isEmpty else { return nil }
        switch codec.lowercased() {
        case "truehd": return "TrueHD"
        case "dtshd_ma": return "DTS-HD MA"
        case "dtshd_hra": return "DTS-HD HRA"
        case "dts": return "DTS"
        case "ac3", "eac3": return codec.lowercased() == "eac3" ? "Dolby Digital+" : "Dolby Digital"
        case "aac": return "AAC"
        case "flac": return "FLAC"
        case "pcm", "pcm_s16le", "pcm_s24le": return "PCM"
        default: return codec.uppercased()
        }
    }

    /// Returns the channel layout label (e.g., "7.1", "5.1", "Stereo")
    var channelLabel: String? {
        guard let channels = channels else { return nil }
        switch channels {
        case 1: return "Mono"
        case 2: return "Stereo"
        case 6: return "5.1"
        case 8: return "7.1"
        default: return "\(channels)ch"
        }
    }

    /// Returns combined audio info
    var displayLabel: String? {
        var parts: [String] = []
        if let codec = codecLabel { parts.append(codec) }
        if let channels = channelLabel { parts.append(channels) }
        return parts.isEmpty ? nil : parts.joined(separator: " ")
    }
}

struct SubtitleStream: Codable, Hashable {
    let language: String?
}
