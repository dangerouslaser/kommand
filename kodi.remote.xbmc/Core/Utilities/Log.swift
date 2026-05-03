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
    private static let subsystem = "group.decent.mid.range.kommand"

    static let networking = Logger(subsystem: subsystem, category: "networking")
    static let playback = Logger(subsystem: subsystem, category: "playback")
    static let ui = Logger(subsystem: subsystem, category: "ui")
    static let general = Logger(subsystem: subsystem, category: "general")
}
