//
//  SeekBackwardIntent.swift
//  Kommand
//

import AppIntents
import ActivityKit

struct SeekBackwardIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Seek Backward"
    static let description = IntentDescription("Seek backward 10 seconds")

    @MainActor
    func perform() async throws -> some IntentResult {
        await PlaybackIntentHandler.seekBackward()
        return .result()
    }
}
