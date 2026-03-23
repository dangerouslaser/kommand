//
//  PowerAction.swift
//  kodi.remote.xbmc
//

import Foundation

/// All available power actions for the configurable power button
nonisolated enum PowerAction: String, CaseIterable, Codable, Identifiable, Sendable {
    case quitKodi
    case systemShutdown
    case systemSuspend
    case systemReboot

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .quitKodi: return "Quit Kodi"
        case .systemShutdown: return "Shutdown"
        case .systemSuspend: return "Suspend"
        case .systemReboot: return "Reboot"
        }
    }

    var systemImage: String {
        switch self {
        case .quitKodi: return "arrow.clockwise"
        case .systemShutdown: return "power"
        case .systemSuspend: return "moon.fill"
        case .systemReboot: return "arrow.triangle.2.circlepath"
        }
    }

    var confirmationTitle: String {
        switch self {
        case .quitKodi: return "Quit Kodi?"
        case .systemShutdown: return "Shutdown Device?"
        case .systemSuspend: return "Suspend Device?"
        case .systemReboot: return "Reboot Device?"
        }
    }

    var confirmationMessage: String {
        switch self {
        case .quitKodi: return "Kodi will quit. Any playback will be interrupted."
        case .systemShutdown: return "The device will power off completely."
        case .systemSuspend: return "The device will enter sleep mode. Wake it with CEC or Wake-on-LAN."
        case .systemReboot: return "The device will restart. This may take a minute."
        }
    }

    var confirmButtonLabel: String {
        switch self {
        case .quitKodi: return "Quit"
        case .systemShutdown: return "Shutdown"
        case .systemSuspend: return "Suspend"
        case .systemReboot: return "Reboot"
        }
    }

    var isDestructive: Bool {
        switch self {
        case .systemShutdown, .systemReboot: return true
        default: return false
        }
    }
}
