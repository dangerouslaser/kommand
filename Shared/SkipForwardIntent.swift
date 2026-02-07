//
//  SkipForwardIntent.swift
//  Kommand
//

import AppIntents
import ActivityKit

struct SkipForwardIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Skip Forward"
    static let description = IntentDescription("Skip to next item")

    @MainActor
    func perform() async throws -> some IntentResult {
        await PlaybackIntentHandler.skipNext()
        return .result()
    }
}
