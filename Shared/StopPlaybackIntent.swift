//
//  StopPlaybackIntent.swift
//  Kommand
//

import AppIntents
import ActivityKit

struct StopPlaybackIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Stop"
    static var description = IntentDescription("Stop playback on Kodi")

    @MainActor
    func perform() async throws -> some IntentResult {
        await PlaybackIntentHandler.stop()
        return .result()
    }
}
