//
//  SeekForwardIntent.swift
//  Kommand
//

import AppIntents
import ActivityKit

struct SeekForwardIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Seek Forward"
    static let description = IntentDescription("Seek forward 30 seconds")

    @MainActor
    func perform() async throws -> some IntentResult {
        await PlaybackIntentHandler.seekForward()
        return .result()
    }
}
