//
//  SkipBackwardIntent.swift
//  Kommand
//

import AppIntents
import ActivityKit

struct SkipBackwardIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Skip Backward"
    static let description = IntentDescription("Skip to previous item")

    @MainActor
    func perform() async throws -> some IntentResult {
        await PlaybackIntentHandler.skipPrevious()
        return .result()
    }
}
