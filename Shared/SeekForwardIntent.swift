//
//  SeekForwardIntent.swift
//  Kommand
//

import AppIntents
import ActivityKit

struct SeekForwardIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Seek Forward"
    static var description = IntentDescription("Seek forward 30 seconds")

    @MainActor
    func perform() async throws -> some IntentResult {
        await PlaybackIntentHandler.seekForward()
        return .result()
    }
}
