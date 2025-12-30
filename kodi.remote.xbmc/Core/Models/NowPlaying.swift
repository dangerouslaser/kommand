//
//  NowPlaying.swift
//  kodi.remote.xbmc
//

import Foundation

enum MediaType: String, Codable {
    case movie
    case episode
    case song
    case musicvideo
    case unknown

    init(from string: String) {
        switch string.lowercased() {
        case "movie": self = .movie
        case "episode": self = .episode
        case "song": self = .song
        case "musicvideo": self = .musicvideo
        default: self = .unknown
        }
    }
}

struct NowPlayingItem: Equatable {
    let type: MediaType
    let title: String
    let subtitle: String?
    let artworkPath: String?
    let fanartPath: String?
    var duration: TimeInterval
    var position: TimeInterval
    var speed: Int // 0 = paused, 1 = playing, 2+ = fast forward, negative = rewind
    let audioStreams: [AudioStream]
    let subtitles: [Subtitle]
    var currentAudioStreamIndex: Int
    var currentSubtitleIndex: Int
    let videoCodec: String?
    let audioCodec: String?
    let hdrType: String?

    var isPlaying: Bool {
        speed != 0
    }

    var progress: Double {
        guard duration > 0 else { return 0 }
        return position / duration
    }

    var remainingTime: TimeInterval {
        max(0, duration - position)
    }

    static let empty = NowPlayingItem(
        type: .unknown,
        title: "",
        subtitle: nil,
        artworkPath: nil,
        fanartPath: nil,
        duration: 0,
        position: 0,
        speed: 0,
        audioStreams: [],
        subtitles: [],
        currentAudioStreamIndex: 0,
        currentSubtitleIndex: 0,
        videoCodec: nil,
        audioCodec: nil,
        hdrType: nil
    )
}

struct AudioStream: Identifiable, Equatable {
    let id: Int
    let name: String
    let language: String?
    let codec: String?
    let channels: Int?

    var displayName: String {
        var parts: [String] = []
        if !name.isEmpty {
            parts.append(name)
        }
        if let lang = language, !lang.isEmpty {
            parts.append("(\(lang))")
        }
        if let codec = codec {
            parts.append("[\(codec)]")
        }
        return parts.isEmpty ? "Track \(id)" : parts.joined(separator: " ")
    }
}

struct Subtitle: Identifiable, Equatable {
    let id: Int
    let name: String
    let language: String?

    var displayName: String {
        if !name.isEmpty {
            return name
        }
        if let lang = language, !lang.isEmpty {
            return lang
        }
        return "Subtitle \(id)"
    }
}

// MARK: - Time Formatting

extension TimeInterval {
    var formattedDuration: String {
        let totalSeconds = Int(self)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }
}
