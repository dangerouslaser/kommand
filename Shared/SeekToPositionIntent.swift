//
//  SeekToPositionIntent.swift
//  Kommand
//

import AppIntents
import ActivityKit

struct SeekToPositionIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Seek to Position"
    static var description = IntentDescription("Seek to a specific position in playback")

    @Parameter(title: "Percentage")
    var percentage: Double

    init() {
        self.percentage = 0
    }

    init(percentage: Double) {
        self.percentage = percentage
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        await PlaybackIntentHandler.seekToPercentage(percentage)
        return .result()
    }
}
