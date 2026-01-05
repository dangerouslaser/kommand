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
        await sendCommand("Player.GoTo", extraParams: ["to": "next"])
        // No UI update needed - title will change on next poll
    }

    @MainActor
    static func skipPrevious() async {
        await sendCommand("Player.GoTo", extraParams: ["to": "previous"])
        // No UI update needed - title will change on next poll
    }

    @MainActor
    static func seekForward() async {
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
        }
    }

    // MARK: - Command Sending

    @discardableResult
    @MainActor
    private static func sendCommand(_ method: String, extraParams: [String: Any] = [:]) async -> Bool {
        guard let defaults = UserDefaults(suiteName: AppGroupConstants.suiteName) else {
            return false
        }

        defaults.synchronize()

        guard let address = defaults.string(forKey: AppGroupConstants.hostAddressKey),
              !address.isEmpty else {
            return false
        }

        guard defaults.object(forKey: AppGroupConstants.activePlayerIdKey) != nil else {
            return false
        }
        let playerId = defaults.integer(forKey: AppGroupConstants.activePlayerIdKey)

        var port = defaults.integer(forKey: AppGroupConstants.hostPortKey)
        if port == 0 { port = 8080 }

        guard let url = URL(string: "http://\(address):\(port)/jsonrpc") else {
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
                return httpResponse.statusCode == 200
            }
            return false
        } catch {
            return false
        }
    }
}
