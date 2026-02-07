//
//  JSONRPCModels.swift
//  kodi.remote.xbmc
//

import Foundation

// MARK: - JSON-RPC Request/Response

nonisolated struct JSONRPCRequest: Encodable, @unchecked Sendable {
    let jsonrpc: String = "2.0"
    let method: String
    let params: [String: AnyCodable]
    let id: Int

    init(method: String, params: [String: Any] = [:], id: Int = 1) {
        self.method = method
        self.params = params.mapValues { AnyCodable($0) }
        self.id = id
    }
}

nonisolated struct JSONRPCResponse<T: Decodable & Sendable>: Decodable, Sendable {
    let jsonrpc: String
    let id: Int?
    let result: T?
    let error: JSONRPCError?
}

nonisolated struct JSONRPCError: Decodable, Error, @unchecked Sendable {
    let code: Int
    let message: String
    let data: AnyCodable?
}

nonisolated struct JSONRPCNotification: Decodable, @unchecked Sendable {
    let jsonrpc: String
    let method: String
    let params: NotificationParams?

    nonisolated struct NotificationParams: Decodable, @unchecked Sendable {
        let sender: String?
        let data: AnyCodable?
    }
}

// MARK: - AnyCodable for flexible JSON handling

nonisolated struct AnyCodable: Codable, @unchecked Sendable {
    let value: Any

    init(_ value: Any) {
        self.value = value
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if container.decodeNil() {
            value = NSNull()
        } else if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let string = try? container.decode(String.self) {
            value = string
        } else if let array = try? container.decode([AnyCodable].self) {
            value = array.map { $0.value }
        } else if let dict = try? container.decode([String: AnyCodable].self) {
            value = dict.mapValues { $0.value }
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unable to decode value")
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        switch value {
        case is NSNull:
            try container.encodeNil()
        case let bool as Bool:
            try container.encode(bool)
        case let int as Int:
            try container.encode(int)
        case let double as Double:
            try container.encode(double)
        case let string as String:
            try container.encode(string)
        case let array as [Any]:
            try container.encode(array.map { AnyCodable($0) })
        case let dict as [String: Any]:
            try container.encode(dict.mapValues { AnyCodable($0) })
        default:
            throw EncodingError.invalidValue(value, EncodingError.Context(codingPath: [], debugDescription: "Unable to encode value"))
        }
    }
}

// MARK: - Kodi Notifications

nonisolated enum KodiNotification: String, CaseIterable {
    case playerOnPlay = "Player.OnPlay"
    case playerOnPause = "Player.OnPause"
    case playerOnStop = "Player.OnStop"
    case playerOnSeek = "Player.OnSeek"
    case playerOnSpeedChanged = "Player.OnSpeedChanged"
    case playerOnPropertyChanged = "Player.OnPropertyChanged"
    case applicationOnVolumeChanged = "Application.OnVolumeChanged"
    case playlistOnAdd = "Playlist.OnAdd"
    case playlistOnRemove = "Playlist.OnRemove"
    case playlistOnClear = "Playlist.OnClear"
    case videoLibraryOnUpdate = "VideoLibrary.OnUpdate"
    case audioLibraryOnUpdate = "AudioLibrary.OnUpdate"
}

// MARK: - API Response Types

nonisolated struct PingResponse: Decodable, Sendable {
    // Ping returns just "pong" string
}

nonisolated struct ActivePlayersResponse: Decodable, Sendable {
    let playerid: Int
    let playertype: String
    let type: String
}

nonisolated struct VolumeResponse: Decodable, Sendable {
    let volume: Int
    let muted: Bool
}

nonisolated struct PlayerPropertiesResponse: Decodable, Sendable {
    let time: TimeInfo?
    let totaltime: TimeInfo?
    let percentage: Double?
    let speed: Int?
    let playlistid: Int?
    let position: Int?
    let shuffled: Bool?
    let `repeat`: String?
    let currentaudiostream: AudioStreamInfo?
    let currentsubtitle: SubtitleInfo?
    let subtitleenabled: Bool?
    let audiostreams: [AudioStreamInfo]?
    let subtitles: [SubtitleInfo]?
    let currentvideostream: VideoStreamInfo?

    struct TimeInfo: Decodable, Sendable {
        let hours: Int
        let minutes: Int
        let seconds: Int
        let milliseconds: Int

        var totalSeconds: TimeInterval {
            TimeInterval(hours * 3600 + minutes * 60 + seconds) + TimeInterval(milliseconds) / 1000.0
        }
    }

    struct AudioStreamInfo: Decodable, Sendable {
        let index: Int?
        let name: String?
        let language: String?
        let codec: String?
        let channels: Int?
    }

    struct SubtitleInfo: Decodable, Sendable {
        let index: Int?
        let name: String?
        let language: String?
    }

    struct VideoStreamInfo: Decodable, Sendable {
        let codec: String?
        let width: Int?
        let height: Int?
        let hdrtype: String?
    }
}

nonisolated struct PlayerItemResponse: Decodable, Sendable {
    let item: MediaItem

    struct MediaItem: Decodable, Sendable {
        let id: Int?
        let type: String
        let label: String?
        let title: String?
        let artist: [String]?
        let album: String?
        let showtitle: String?
        let season: Int?
        let episode: Int?
        let year: Int?
        let runtime: Int?
        let thumbnail: String?
        let fanart: String?
        let file: String?
        let art: MediaArt?
        let streamdetails: StreamDetails?

        /// Returns the best available artwork path
        var artworkPath: String? {
            art?.poster ?? art?.thumb ?? thumbnail ?? fanart
        }
    }

    struct StreamDetails: Decodable, Sendable {
        let video: [VideoStreamDetail]?
        let audio: [AudioStreamDetail]?
        let subtitle: [SubtitleStreamDetail]?
    }

    struct VideoStreamDetail: Decodable, Sendable {
        let codec: String?
        let width: Int?
        let height: Int?
        let hdrtype: String?
        let aspect: Double?
        let duration: Int?
        let stereomode: String?
    }

    struct AudioStreamDetail: Decodable, Sendable {
        let codec: String?
        let channels: Int?
        let language: String?
    }

    struct SubtitleStreamDetail: Decodable, Sendable {
        let language: String?
    }

    struct MediaArt: Decodable, Sendable {
        let poster: String?
        let thumb: String?
        let fanart: String?
        let banner: String?

        enum CodingKeys: String, CodingKey {
            case poster
            case thumb
            case fanart
            case banner
            case tvshowPoster = "tvshow.poster"
            case seasonPoster = "season.poster"
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            poster = try container.decodeIfPresent(String.self, forKey: .poster)
                ?? container.decodeIfPresent(String.self, forKey: .tvshowPoster)
                ?? container.decodeIfPresent(String.self, forKey: .seasonPoster)
            thumb = try container.decodeIfPresent(String.self, forKey: .thumb)
            fanart = try container.decodeIfPresent(String.self, forKey: .fanart)
            banner = try container.decodeIfPresent(String.self, forKey: .banner)
        }
    }
}

nonisolated struct ApplicationPropertiesResponse: Decodable, Sendable {
    let volume: Int?
    let muted: Bool?
    let name: String?
    let version: VersionInfo?

    struct VersionInfo: Decodable, Sendable {
        let major: Int
        let minor: Int
        let revision: String?
        let tag: String?

        var displayVersion: String {
            let version = "\(major).\(minor)"
            if let tag = tag, !tag.isEmpty, tag != "stable" {
                return "\(version) (\(tag))"
            }
            return version
        }
    }
}
