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
        }
    }

    func saveHosts() {
        if let encoded = try? JSONEncoder().encode(hosts) {
            UserDefaults.standard.set(encoded, forKey: hostsKey)
        }
    }

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

    func updateHost(_ host: KodiHost) {
        if let index = hosts.firstIndex(where: { $0.id == host.id }) {
            hosts[index] = host
            saveHosts()
            if host.id == currentHost?.id {
                currentHost = host
            }
        }
    }

    func deleteHost(_ host: KodiHost) {
        hosts.removeAll { $0.id == host.id }
        if currentHost?.id == host.id {
            currentHost = hosts.first
        }
        saveHosts()
    }

    func setDefaultHost(_ host: KodiHost) {
        for i in hosts.indices {
            hosts[i].isDefault = (hosts[i].id == host.id)
        }
        currentHost = host
        saveHosts()
    }
}
