//
//  Log.swift
//  Kommand
//

import Foundation
import os

extension Logger {
    // Pin the subsystem to the App Group id so logs from the main app and the
    // Live Activity widget extension land in the same Console.app bucket. Using
    // Bundle.main.bundleIdentifier would split logs across two subsystems
    // (the host app's vs the extension's) and make diagnosis harder.
    nonisolated private static let subsystem = "group.decent.mid.range.kommand"

    // nonisolated so non-main actors (e.g. KodiClient, ImageCacheService) can
    // log without an actor hop. Logger is Sendable and thread-safe.
    nonisolated static let networking = Logger(subsystem: subsystem, category: "networking")
    nonisolated static let playback = Logger(subsystem: subsystem, category: "playback")
    nonisolated static let ui = Logger(subsystem: subsystem, category: "ui")
    nonisolated static let general = Logger(subsystem: subsystem, category: "general")
}
