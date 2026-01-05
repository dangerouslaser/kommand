//
//  SkipForwardIntent.swift
//  Kommand
//

import AppIntents
import ActivityKit

struct SkipForwardIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Skip Forward"
    static var description = IntentDescription("Skip to next item")

    @MainActor
    func perform() async throws -> some IntentResult {
        await PlaybackIntentHandler.skipNext()
        return .result()
    }
}
