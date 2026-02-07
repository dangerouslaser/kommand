//
//  KodiConnectionManager.swift
//  Kommand
//
//  Singleton connection manager that maintains the active Kodi connection.
//  Used by LiveActivityIntents to send commands when the app is in background.
//
//  This runs in the main app's process - intents call this directly.
//

import Foundation

/// Manages the active Kodi connection for Live Activity intents
@MainActor
final class KodiConnectionManager {
    static let shared = KodiConnectionManager()

    private var client: KodiClient?
    private var currentHost: KodiHost?
    private var activePlayerId: Int?

    private init() {}

    // MARK: - Configuration

    /// Configure the connection manager with a host
    func configure(with host: KodiHost) async {
        self.currentHost = host
        self.client = KodiClient()
        await client?.configure(with: host)

        // Also update shared UserDefaults for widget
        updateSharedDefaults(host: host)
    }

    /// Set the active player ID
    func setActivePlayer(id: Int?) {
        self.activePlayerId = id

        // Update shared UserDefaults
        if let defaults = UserDefaults(suiteName: AppGroupConstants.suiteName) {
            if let id = id {
                defaults.set(id, forKey: AppGroupConstants.activePlayerIdKey)
            } else {
                defaults.removeObject(forKey: AppGroupConstants.activePlayerIdKey)
            }
        }
    }

    /// Check if we have an active connection
    var hasActiveConnection: Bool {
        client != nil && currentHost != nil
    }

    /// Get the current player ID
    var playerId: Int? {
        activePlayerId
    }

    // MARK: - Playback Commands

    func playPause() async throws {
        guard let client = client, let playerId = activePlayerId else {
            throw ConnectionError.noActivePlayer
        }
        _ = try await client.playPause(playerId: playerId)
    }

    func stop() async throws {
        guard let client = client, let playerId = activePlayerId else {
            throw ConnectionError.noActivePlayer
        }
        try await client.stop(playerId: playerId)
    }

    func skipNext() async throws {
        guard let client = client, let playerId = activePlayerId else {
            throw ConnectionError.noActivePlayer
        }
        try await client.skipNext(playerId: playerId)
    }

    func skipPrevious() async throws {
        guard let client = client, let playerId = activePlayerId else {
            throw ConnectionError.noActivePlayer
        }
        try await client.skipPrevious(playerId: playerId)
    }

    func seekRelative(seconds: Int) async throws {
        guard let client = client, let playerId = activePlayerId else {
            throw ConnectionError.noActivePlayer
        }
        try await client.seekRelative(playerId: playerId, seconds: seconds)
    }

    // MARK: - Private

    private func updateSharedDefaults(host: KodiHost) {
        guard let defaults = UserDefaults(suiteName: AppGroupConstants.suiteName) else { return }

        defaults.set(host.address, forKey: AppGroupConstants.hostAddressKey)
        defaults.set(host.httpPort, forKey: AppGroupConstants.hostPortKey)
        defaults.set(host.username, forKey: AppGroupConstants.hostUsernameKey)
        defaults.set(host.id.uuidString, forKey: "currentHostId")

        // Password is now shared via Keychain access group — no need to copy to UserDefaults.
        // Clean up any legacy password stored in UserDefaults.
        defaults.removeObject(forKey: AppGroupConstants.hostPasswordKey)
    }

    // MARK: - Errors

    enum ConnectionError: LocalizedError {
        case notConnected
        case noActivePlayer

        var errorDescription: String? {
            switch self {
            case .notConnected: return "Not connected to Kodi"
            case .noActivePlayer: return "No active player"
            }
        }
    }
}
