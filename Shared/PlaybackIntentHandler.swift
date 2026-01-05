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
        // Record that an intent action is happening (prevents polling from overwriting)
        AppGroupConstants.recordIntentAction()

        // Player.PlayPause returns the new speed (0 = paused, 1 = playing)
        if let speed = await sendPlayPauseCommand() {
            let isPlaying = speed != 0
            await updateActivityState { state in
                state.isPlaying = isPlaying
                state.lastUpdated = Date() // Reset timer reference
            }
        }
    }

    @MainActor
    static func stop() async {
        let success = await sendCommand("Player.Stop")
        if success {
            await updateActivityState { state in
                state.isPlaying = false
                state.lastUpdated = Date()
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
        // Record intent action to prevent polling from overwriting
        AppGroupConstants.recordIntentAction()

        let success = await sendCommand("Player.Seek", extraParams: ["value": ["seconds": 30]])
        if success {
            let now = Date()
            await updateActivityState { state in
                // Calculate estimated current position before seeking
                let estimatedElapsed = state.isPlaying
                    ? state.elapsedTime + now.timeIntervalSince(state.lastUpdated)
                    : state.elapsedTime
                state.elapsedTime = min(estimatedElapsed + 30, state.totalDuration)
                state.lastUpdated = now
            }
        }
    }

    @MainActor
    static func seekBackward() async {
        // Record intent action to prevent polling from overwriting
        AppGroupConstants.recordIntentAction()

        let success = await sendCommand("Player.Seek", extraParams: ["value": ["seconds": -30]])
        if success {
            let now = Date()
            await updateActivityState { state in
                // Calculate estimated current position before seeking
                let estimatedElapsed = state.isPlaying
                    ? state.elapsedTime + now.timeIntervalSince(state.lastUpdated)
                    : state.elapsedTime
                state.elapsedTime = max(estimatedElapsed - 30, 0)
                state.lastUpdated = now
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

    /// Send PlayPause and return the resulting speed (0 = paused, non-zero = playing)
    @MainActor
    private static func sendPlayPauseCommand() async -> Int? {
        guard let defaults = UserDefaults(suiteName: AppGroupConstants.suiteName) else {
            return nil
        }

        defaults.synchronize()

        guard let address = defaults.string(forKey: AppGroupConstants.hostAddressKey),
              !address.isEmpty else {
            return nil
        }

        guard defaults.object(forKey: AppGroupConstants.activePlayerIdKey) != nil else {
            return nil
        }
        let playerId = defaults.integer(forKey: AppGroupConstants.activePlayerIdKey)

        var port = defaults.integer(forKey: AppGroupConstants.hostPortKey)
        if port == 0 { port = 8080 }

        guard let url = URL(string: "http://\(address):\(port)/jsonrpc") else {
            return nil
        }

        let body: [String: Any] = [
            "jsonrpc": "2.0",
            "method": "Player.PlayPause",
            "params": ["playerid": playerId],
            "id": 1
        ]

        guard let jsonData = try? JSONSerialization.data(withJSONObject: body) else {
            return nil
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = jsonData
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 5

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
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                return nil
            }

            // Parse response: {"id":1,"jsonrpc":"2.0","result":{"speed":1}}
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let result = json["result"] as? [String: Any],
               let speed = result["speed"] as? Int {
                return speed
            }

            return nil
        } catch {
            return nil
        }
    }

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
