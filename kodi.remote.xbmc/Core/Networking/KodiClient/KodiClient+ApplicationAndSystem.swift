//
//  KodiClient+ApplicationAndSystem.swift
//  kodi.remote.xbmc
//

import Foundation

extension KodiClient {
    // MARK: - Application Commands

    func getVolume() async throws -> VolumeResponse {
        try await send(method: "Application.GetProperties", params: ["properties": ["volume", "muted"]])
    }

    func setVolume(_ volume: Int) async throws -> Int {
        try await send(method: "Application.SetVolume", params: ["volume": volume])
    }

    func setMute(_ mute: Bool) async throws -> Bool {
        try await send(method: "Application.SetMute", params: ["mute": mute])
    }

    func toggleMute() async throws -> Bool {
        try await send(method: "Application.SetMute", params: ["mute": "toggle"])
    }

    // MARK: - System Commands

    func quit() async throws {
        let _: String = try await send(method: "Application.Quit")
    }

    func suspend() async throws {
        let _: String = try await send(method: "System.Suspend")
    }

    func shutdown() async throws {
        let _: String = try await send(method: "System.Shutdown")
    }

    func reboot() async throws {
        let _: String = try await send(method: "System.Reboot")
    }

    // MARK: - CoreELEC Detection & System Info

    func detectCoreELEC() async -> Bool {
        do {
            let _: AddonDetailsResponse = try await send(method: "Addons.GetAddonDetails", params: [
                "addonid": "service.coreelec.settings"
            ])
            return true
        } catch {
            return false
        }
    }

    func getSystemInfo() async throws -> SystemInfoResponse {
        try await send(method: "XBMC.GetInfoLabels", params: [
            "labels": [
                "System.CpuTemperature",
                "System.GpuTemperature",
                "System.Memory(used.percent)",
                "System.FreeSpace",
                "System.TotalSpace",
                "System.UsedSpace",
                "System.KernelVersion",
                "System.OSVersionInfo",
                "System.BuildVersion",
                "System.FriendlyName",
                "System.Uptime",
                "System.TotalUptime"
            ]
        ])
    }

    func getApplicationProperties() async throws -> ApplicationPropertiesResponse {
        try await send(method: "Application.GetProperties", params: [
            "properties": ["name", "version"]
        ])
    }
}
