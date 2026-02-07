//
//  PVR.swift
//  kodi.remote.xbmc
//

import Foundation

// MARK: - Channel

nonisolated struct PVRChannel: Identifiable, Codable, Hashable, Sendable {
    let channelid: Int
    let label: String
    let channeltype: String // "tv" or "radio"
    let thumbnail: String?
    let hidden: Bool?
    let locked: Bool?
    let channel: String? // Channel number
    let broadcastnow: EPGEvent?
    let broadcastnext: EPGEvent?
    let isrecording: Bool?

    var id: Int { channelid }

    var isTV: Bool {
        channeltype == "tv"
    }

    var isRadio: Bool {
        channeltype == "radio"
    }

    var channelNumber: String? {
        channel
    }
}

// MARK: - Channel Group

nonisolated struct PVRChannelGroup: Identifiable, Codable, Hashable, Sendable {
    let channelgroupid: Int
    let label: String
    let channeltype: String // "tv" or "radio"

    var id: Int { channelgroupid }

    var isTV: Bool {
        channeltype == "tv"
    }
}

// MARK: - EPG Event (Program)

nonisolated struct EPGEvent: Identifiable, Codable, Hashable, Sendable {
    let broadcastid: Int
    let title: String
    let starttime: String?
    let endtime: String?
    let runtime: Int? // in seconds
    let plot: String?
    let plotoutline: String?
    let genre: [String]?
    let episodename: String?
    let episodenum: Int?
    let episodepart: Int?
    let firstaired: String?
    let hastimer: Bool?
    let hasrecording: Bool?
    let isactive: Bool?
    let wasactive: Bool?
    let progresspercentage: Double?

    var id: Int { broadcastid }

    var startDate: Date? {
        guard let starttime = starttime else { return nil }
        return ISO8601DateFormatter().date(from: starttime) ?? parseKodiDate(starttime)
    }

    var endDate: Date? {
        guard let endtime = endtime else { return nil }
        return ISO8601DateFormatter().date(from: endtime) ?? parseKodiDate(endtime)
    }

    var formattedTime: String? {
        guard let start = startDate else { return nil }
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: start)
    }

    var formattedTimeRange: String? {
        guard let start = startDate, let end = endDate else { return nil }
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return "\(formatter.string(from: start)) - \(formatter.string(from: end))"
    }

    var genreText: String? {
        genre?.joined(separator: ", ")
    }

    private func parseKodiDate(_ dateString: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter.date(from: dateString)
    }
}

// MARK: - Recording

nonisolated struct PVRRecording: Identifiable, Codable, Hashable, Sendable {
    let recordingid: Int
    let title: String
    let channel: String?
    let starttime: String?
    let endtime: String?
    let runtime: Int? // in seconds
    let plot: String?
    let plotoutline: String?
    let genre: [String]?
    let playcount: Int?
    let resume: ResumePoint?
    let directory: String?
    let icon: String?
    let art: MediaArt?
    let streamurl: String?
    let isdeleted: Bool?
    let radio: Bool?

    var id: Int { recordingid }

    var artworkPath: String? {
        art?.thumb ?? art?.poster ?? icon
    }

    var isWatched: Bool {
        (playcount ?? 0) > 0
    }

    var hasResume: Bool {
        guard let resume = resume else { return false }
        return resume.position > 0
    }

    var recordingDate: Date? {
        guard let starttime = starttime else { return nil }
        return ISO8601DateFormatter().date(from: starttime) ?? parseKodiDate(starttime)
    }

    var formattedDate: String? {
        guard let date = recordingDate else { return nil }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
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

    var genreText: String? {
        genre?.joined(separator: ", ")
    }

    private func parseKodiDate(_ dateString: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter.date(from: dateString)
    }
}

// MARK: - Timer

nonisolated struct PVRTimer: Identifiable, Codable, Hashable, Sendable {
    let timerid: Int
    let title: String
    let summary: String?
    let channelid: Int?
    let starttime: String?
    let endtime: String?
    let state: String? // "scheduled", "recording", "completed", etc.
    let ismanual: Bool?
    let isreadonly: Bool?
    let isrecording: Bool?
    let hastimerrules: Bool?
    let directory: String?
    let priority: Int?
    let lifetime: Int?
    let preventduplicates: Bool?
    let startmargin: Int?
    let endmargin: Int?

    var id: Int { timerid }

    var startDate: Date? {
        guard let starttime = starttime else { return nil }
        return ISO8601DateFormatter().date(from: starttime) ?? parseKodiDate(starttime)
    }

    var endDate: Date? {
        guard let endtime = endtime else { return nil }
        return ISO8601DateFormatter().date(from: endtime) ?? parseKodiDate(endtime)
    }

    var formattedTime: String? {
        guard let start = startDate else { return nil }
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: start)
    }

    var stateText: String {
        switch state?.lowercased() {
        case "scheduled": return "Scheduled"
        case "recording": return "Recording"
        case "completed": return "Completed"
        case "cancelled": return "Cancelled"
        case "conflict_ok": return "Conflict (OK)"
        case "conflict_notok": return "Conflict"
        case "error": return "Error"
        case "disabled": return "Disabled"
        default: return state ?? "Unknown"
        }
    }

    var isActive: Bool {
        state?.lowercased() == "recording"
    }

    var isScheduled: Bool {
        state?.lowercased() == "scheduled"
    }

    private func parseKodiDate(_ dateString: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter.date(from: dateString)
    }
}

// MARK: - API Responses

nonisolated struct PVRChannelGroupsResponse: Decodable, Sendable {
    let channelgroups: [PVRChannelGroup]?
}

nonisolated struct PVRChannelsResponse: Decodable, Sendable {
    let channels: [PVRChannel]?
    let limits: LimitsResult?
}

nonisolated struct PVRRecordingsResponse: Decodable, Sendable {
    let recordings: [PVRRecording]?
    let limits: LimitsResult?
}

nonisolated struct PVRTimersResponse: Decodable, Sendable {
    let timers: [PVRTimer]?
    let limits: LimitsResult?
}

nonisolated struct PVRBroadcastsResponse: Decodable, Sendable {
    let broadcasts: [EPGEvent]?
    let limits: LimitsResult?
}

// MARK: - PVR Properties Response

nonisolated struct PVRPropertiesResponse: Decodable, Sendable {
    let available: Bool?
    let recording: Bool?
    let scanning: Bool?
}
