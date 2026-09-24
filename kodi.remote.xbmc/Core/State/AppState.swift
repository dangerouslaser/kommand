//
//  AppState.swift
//  kodi.remote.xbmc
//

import Foundation
import SwiftUI

nonisolated enum ConnectionState: Equatable {
    case disconnected
    case connecting
    case connected
    case error(String)

    var statusColor: Color {
        switch self {
        case .disconnected: return .gray
        case .connecting: return .orange
        case .connected: return .green
        case .error: return .red
        }
    }

    var statusText: String {
        switch self {
        case .disconnected: return "Disconnected"
        case .connecting: return "Connecting..."
        case .connected: return "Connected"
        case .error(let message): return "Error: \(message)"
        }
    }
}

@Observable
final class AppState {
    var hosts: [KodiHost] = []
    private(set) var currentHost: KodiHost? {
        didSet { replaceConnection() }
    }
    var connectionState: ConnectionState = .disconnected
    var nowPlaying: NowPlayingItem?
    var volume: Int = 100
    var isMuted: Bool = false
    var activePlayerId: Int?
    var isCoreELEC: Bool = false

    // One immutable client/model pair per host session. Views never reconfigure it.
    private(set) var client = KodiClient()
    private(set) var remote = RemoteViewModel()
    private(set) var connectionRevision = UUID()

    // Library update signal — set by WebSocket when VideoLibrary.OnUpdate fires
    var libraryUpdateSignal: Date?

    // Server capabilities
    var serverCapabilities: ServerCapabilities = ServerCapabilities()

    private let hostsKey = "saved_hosts"
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        loadHosts()
    }

    var hasActivePlayer: Bool {
        activePlayerId != nil
    }

    // MARK: - Host Management

    func loadHosts() {
        if let data = defaults.data(forKey: hostsKey),
           let decoded = try? JSONDecoder().decode([KodiHost].self, from: data) {
            hosts = decoded
            // Migrate before taking the session's credential snapshot.
            KeychainService.migrateFromUserDefaults(hostIds: hosts.map(\.id))
            currentHost = hosts.first { $0.isDefault } ?? hosts.first
            return
        }

        hosts = []
        currentHost = nil
    }

    func saveHosts() {
        if let encoded = try? JSONEncoder().encode(hosts) {
            defaults.set(encoded, forKey: hostsKey)
        }
    }

    // MARK: - Add Host

    /// Returns `false` when an address+port duplicate already exists. The caller is expected
    /// to surface a warning. We don't throw because the only failure mode is "already present"
    /// and the view layer wants to render a friendly message either way.
    @discardableResult
    func addHost(_ host: KodiHost, password: String? = nil) -> Bool {
        if hosts.contains(where: { $0.address == host.address && $0.httpPort == host.httpPort }) {
            return false
        }
        var newHost = host
        if hosts.isEmpty {
            newHost.isDefault = true
        }
        if let password, !password.isEmpty {
            KeychainService.setPassword(password, for: newHost.id)
        }
        hosts.append(newHost)
        saveHosts()
        if newHost.isDefault {
            currentHost = newHost
        }
        return true
    }

    // MARK: - Update Host

    func updateHost(_ host: KodiHost, password: String? = nil) {
        if let index = hosts.firstIndex(where: { $0.id == host.id }) {
            if let password, !password.isEmpty {
                KeychainService.setPassword(password, for: host.id)
            }
            hosts[index] = host
            saveHosts()
            if host.id == currentHost?.id {
                currentHost = host
            }
        }
    }

    // MARK: - Delete Host

    func deleteHost(_ host: KodiHost) {
        hosts.removeAll { $0.id == host.id }
        if currentHost?.id == host.id {
            currentHost = hosts.first
        }
        saveHosts()

        // Clean up credentials
        KeychainService.deletePassword(for: host.id)
    }

    // MARK: - Set Default

    func setDefaultHost(_ host: KodiHost) {
        for i in hosts.indices {
            hosts[i].isDefault = (hosts[i].id == host.id)
        }
        currentHost = hosts.first { $0.id == host.id }
        saveHosts()
    }

    private func replaceConnection() {
        let previousClient = client
        remote.stopPolling()
        client = KodiClient(host: currentHost)
        remote = RemoteViewModel()
        remote.configure(appState: self)
        connectionRevision = UUID()

        connectionState = currentHost == nil ? .disconnected : .connecting
        nowPlaying = nil
        activePlayerId = nil
        volume = 100
        isMuted = false
        isCoreELEC = false
        serverCapabilities = ServerCapabilities()
        libraryUpdateSignal = nil

        LiveActivityManager.shared.endActivity()
        KodiConnectionManager.shared.configure(host: currentHost, client: client)
        Task { await previousClient.cancelInFlightWork() }
    }
}

// MARK: - Server Capabilities

nonisolated struct ServerCapabilities {
    var isCoreELEC: Bool = false
    var supportsSuspend: Bool = false
    var supportsDolbyVision: Bool = false
    var supportsHDR10Plus: Bool = false
}
