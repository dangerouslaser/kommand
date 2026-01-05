//
//  PlayPauseIntent.swift
//  Kommand
//
//  Live Activity intent for play/pause control.
//  This file must be in BOTH targets (main app and widget extension).
//  The perform() only executes in the main app's process.
//

import AppIntents
import ActivityKit

struct PlayPauseIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Play/Pause"
    static var description = IntentDescription("Toggle playback on Kodi")

    @MainActor
    func perform() async throws -> some IntentResult {
        // This code only runs in the main app's process
        // Widget extension compiles this but never executes it
        await PlaybackIntentHandler.playPause()
        return .result()
    }
}
