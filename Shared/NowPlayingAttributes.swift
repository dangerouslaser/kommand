//
//  NowPlayingAttributes.swift
//  Kommand
//
//  Shared between main app and widget extension for Live Activities.
//

import ActivityKit
import Foundation

struct NowPlayingAttributes: ActivityAttributes {
    // ContentState contains the dynamic data that can change during the activity
    // NOTE: Limited to 4KB total - do NOT include image data or paths
    public struct ContentState: Codable, Hashable {
        var title: String
        var subtitle: String
        var hasPoster: Bool         // Simple flag - widget loads from fixed file
        var hasFanart: Bool         // Simple flag - widget loads from fixed file
        var elapsedTime: TimeInterval
        var totalDuration: TimeInterval
        var isPlaying: Bool

        // Timestamp when elapsedTime was captured - used for live progress estimation
        // When playing, progress = elapsedTime + (now - lastUpdated)
        var lastUpdated: Date

        // Codec/quality info for badges
        var hdrType: String?        // "dolbyvision", "hdr10", etc.
        var resolution: String?     // "4K", "1080p", etc.
        var audioCodec: String?     // "TrueHD", "DD+", etc.
        var hasAtmos: Bool
    }

    // Static attributes that don't change during the activity lifetime
    var mediaType: String // "movie", "episode", "song", "musicvideo"
    var hostName: String  // Name of the Kodi host for display
}

// MARK: - App Group Constants

enum AppGroupConstants {
    static let suiteName = "group.decent.mid.range.kommand"

    // Keys for shared UserDefaults (non-image data only)
    static let hostAddressKey = "currentHostAddress"
    static let hostPortKey = "currentHostPort"
    static let hostUsernameKey = "currentHostUsername"
    static let hostPasswordKey = "currentHostPassword"
    static let activePlayerIdKey = "activePlayerId"
    static let lastIntentActionKey = "lastIntentActionTime"

    /// Cooldown period after an intent action during which polling won't update isPlaying
    static let intentCooldownSeconds: TimeInterval = 3.0

    /// Record that an intent action was just performed
    static func recordIntentAction() {
        UserDefaults(suiteName: suiteName)?.set(Date().timeIntervalSince1970, forKey: lastIntentActionKey)
    }

    /// Check if we're within the cooldown period after an intent action
    static var isWithinIntentCooldown: Bool {
        guard let defaults = UserDefaults(suiteName: suiteName),
              let lastAction = defaults.object(forKey: lastIntentActionKey) as? TimeInterval else {
            return false
        }
        let elapsed = Date().timeIntervalSince1970 - lastAction
        return elapsed < intentCooldownSeconds
    }

    // Fixed filenames for Live Activity images
    // Using fixed names simplifies everything - no need to pass paths in ContentState
    static let posterFilename = "live_activity_poster.jpg"
    static let fanartFilename = "live_activity_fanart.jpg"

    /// Get the App Group container URL
    static var containerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: suiteName)
    }

    /// Fixed URL for the poster image file
    static var posterURL: URL? {
        containerURL?.appendingPathComponent(posterFilename)
    }

    /// Fixed URL for the fanart image file
    static var fanartURL: URL? {
        containerURL?.appendingPathComponent(fanartFilename)
    }

    /// Check if poster file exists and is readable
    static var hasPoster: Bool {
        guard let url = posterURL else { return false }
        return FileManager.default.fileExists(atPath: url.path)
    }

    /// Check if fanart file exists and is readable
    static var hasFanart: Bool {
        guard let url = fanartURL else { return false }
        return FileManager.default.fileExists(atPath: url.path)
    }

    /// Delete cached artwork files
    static func clearCachedArtwork() {
        if let posterURL = posterURL {
            try? FileManager.default.removeItem(at: posterURL)
        }
        if let fanartURL = fanartURL {
            try? FileManager.default.removeItem(at: fanartURL)
        }
    }
}
