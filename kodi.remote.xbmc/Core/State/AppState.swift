//
//  AppState.swift
//  kodi.remote.xbmc
//

import Foundation
import SwiftUI

enum ConnectionState: Equatable {
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
    var currentHost: KodiHost?
    var connectionState: ConnectionState = .disconnected
    var nowPlaying: NowPlayingItem?
    var volume: Int = 100
    var isMuted: Bool = false
    var activePlayerId: Int?
    var isCoreELEC: Bool = false

    // Server capabilities
    var serverCapabilities: ServerCapabilities = ServerCapabilities()

    private let hostsKey = "saved_hosts"

    init() {
        loadHosts()
    }

    var hasActivePlayer: Bool {
        activePlayerId != nil
    }

    // MARK: - Host Management

    func loadHosts() {
        if let data = UserDefaults.standard.data(forKey: hostsKey),
           let decoded = try? JSONDecoder().decode([KodiHost].self, from: data) {
            hosts = decoded
            currentHost = hosts.first { $0.isDefault } ?? hosts.first
            return
        }

        hosts = []
        currentHost = nil
    }

    func saveHosts() {
        if let encoded = try? JSONEncoder().encode(hosts) {
            UserDefaults.standard.set(encoded, forKey: hostsKey)
        }
    }

    // MARK: - Add Host

    func addHost(_ host: KodiHost) {
        var newHost = host
        if hosts.isEmpty {
            newHost.isDefault = true
        }
        hosts.append(newHost)
        saveHosts()
        if newHost.isDefault {
            currentHost = newHost
        }
    }

    // MARK: - Update Host

    func updateHost(_ host: KodiHost) {
        if let index = hosts.firstIndex(where: { $0.id == host.id }) {
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
        KeychainHelper.deletePassword(for: host.id)
    }

    // MARK: - Set Default

    func setDefaultHost(_ host: KodiHost) {
        for i in hosts.indices {
            hosts[i].isDefault = (hosts[i].id == host.id)
        }
        currentHost = host
        saveHosts()

        // Reset connection state when switching hosts
        connectionState = .disconnected
        nowPlaying = nil
        activePlayerId = nil
        isCoreELEC = false
        serverCapabilities = ServerCapabilities()
    }
}

// MARK: - Server Capabilities

struct ServerCapabilities {
    var isCoreELEC: Bool = false
    var supportsSuspend: Bool = false
    var supportsDolbyVision: Bool = false
    var supportsHDR10Plus: Bool = false
}
