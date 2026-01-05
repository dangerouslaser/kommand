//
//  PlaybackIntentHandler.swift
//  Kommand
//
//  Handles playback commands from Live Activity intents.
//  This file is shared between main app and widget extension.
//
//  Uses direct HTTP requests to Kodi with connection info from App Group UserDefaults.
//  Includes optimistic UI updates for instant feedback.
//

import Foundation
import ActivityKit

/// Handles playback commands from Live Activity intents
enum PlaybackIntentHandler {

    @MainActor
    static func playPause() async {
        print("[PlaybackIntentHandler] playPause called")
        let success = await sendCommand("Player.PlayPause")
        if success {
            // Optimistic update: toggle isPlaying immediately
            await updateActivityState { state in
                state.isPlaying = !state.isPlaying
            }
        }
    }

    @MainActor
    static func stop() async {
        print("[PlaybackIntentHandler] stop called")
        let success = await sendCommand("Player.Stop")
        if success {
            // Optimistic update: set isPlaying to false
            await updateActivityState { state in
                state.isPlaying = false
            }
        }
    }

    @MainActor
    static func skipNext() async {
        print("[PlaybackIntentHandler] skipNext called")
        await sendCommand("Player.GoTo", extraParams: ["to": "next"])
        // No UI update needed - title will change on next poll
    }

    @MainActor
    static func skipPrevious() async {
        print("[PlaybackIntentHandler] skipPrevious called")
        await sendCommand("Player.GoTo", extraParams: ["to": "previous"])
        // No UI update needed - title will change on next poll
    }

    @MainActor
    static func seekForward() async {
        print("[PlaybackIntentHandler] seekForward called")
        let success = await sendCommand("Player.Seek", extraParams: ["value": ["seconds": 30]])
        if success {
            // Optimistic update: advance elapsed time
            await updateActivityState { state in
                state.elapsedTime = min(state.elapsedTime + 30, state.totalDuration)
            }
        }
    }

    @MainActor
    static func seekBackward() async {
        print("[PlaybackIntentHandler] seekBackward called")
        let success = await sendCommand("Player.Seek", extraParams: ["value": ["seconds": -10]])
        if success {
            // Optimistic update: rewind elapsed time
            await updateActivityState { state in
                state.elapsedTime = max(state.elapsedTime - 10, 0)
            }
        }
    }

    // MARK: - Optimistic UI Updates

    /// Update the Live Activity state immediately for instant feedback
    @MainActor
    private static func updateActivityState(_ update: (inout NowPlayingAttributes.ContentState) -> Void) async {
        // Get all running activities for our app
        let activities = Activity<NowPlayingAttributes>.activities

        for activity in activities {
            var updatedState = activity.content.state
            update(&updatedState)

            await activity.update(
                ActivityContent(state: updatedState, staleDate: nil)
            )
            print("[PlaybackIntentHandler] Live Activity updated optimistically")
        }
    }

    // MARK: - Command Sending

    @discardableResult
    @MainActor
    private static func sendCommand(_ method: String, extraParams: [String: Any] = [:]) async -> Bool {
        guard let defaults = UserDefaults(suiteName: AppGroupConstants.suiteName) else {
            print("[PlaybackIntentHandler] ERROR: Cannot create UserDefaults")
            return false
        }

        defaults.synchronize()

        guard let address = defaults.string(forKey: AppGroupConstants.hostAddressKey),
              !address.isEmpty else {
            print("[PlaybackIntentHandler] ERROR: No host address")
            return false
        }

        guard defaults.object(forKey: AppGroupConstants.activePlayerIdKey) != nil else {
            print("[PlaybackIntentHandler] ERROR: No active player ID")
            return false
        }
        let playerId = defaults.integer(forKey: AppGroupConstants.activePlayerIdKey)

        var port = defaults.integer(forKey: AppGroupConstants.hostPortKey)
        if port == 0 { port = 8080 }

        guard let url = URL(string: "http://\(address):\(port)/jsonrpc") else {
            print("[PlaybackIntentHandler] ERROR: Invalid URL")
            return false
        }

        var params: [String: Any] = ["playerid": playerId]
        for (key, value) in extraParams {
            params[key] = value
        }

        let body: [String: Any] = [
            "jsonrpc": "2.0",
            "method": method,
            "params": params,
            "id": 1
        ]

        guard let jsonData = try? JSONSerialization.data(withJSONObject: body) else {
            print("[PlaybackIntentHandler] ERROR: JSON serialization failed")
            return false
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = jsonData
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 5 // Shorter timeout for responsiveness

        // Add basic auth if credentials are set
        if let username = defaults.string(forKey: AppGroupConstants.hostUsernameKey),
           !username.isEmpty {
            let password = defaults.string(forKey: AppGroupConstants.hostPasswordKey) ?? ""
            let credentials = "\(username):\(password)"
            if let credentialsData = credentials.data(using: .utf8) {
                let base64 = credentialsData.base64EncodedString()
                request.setValue("Basic \(base64)", forHTTPHeaderField: "Authorization")
            }
        }

        do {
            let (_, response) = try await URLSession.shared.data(for: request)

            if let httpResponse = response as? HTTPURLResponse {
                let success = httpResponse.statusCode == 200
                print("[PlaybackIntentHandler] \(method) HTTP \(httpResponse.statusCode)")
                return success
            }
            return false
        } catch {
            print("[PlaybackIntentHandler] Network error: \(error.localizedDescription)")
            return false
        }
    }
}
