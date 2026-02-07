//
//  Log.swift
//  Kommand
//

import Foundation
import os

extension Logger {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "kommand"

    static let networking = Logger(subsystem: subsystem, category: "networking")
    static let playback = Logger(subsystem: subsystem, category: "playback")
    static let ui = Logger(subsystem: subsystem, category: "ui")
    static let general = Logger(subsystem: subsystem, category: "general")
}
