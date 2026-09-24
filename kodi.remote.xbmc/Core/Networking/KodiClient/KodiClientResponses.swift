//
//  KodiClientResponses.swift
//  kodi.remote.xbmc
//

import Foundation

nonisolated struct PlayerSpeedResponse: Decodable, Sendable {
    let speed: Int
}

nonisolated struct AddonDetailsResponse: Decodable, Sendable {
    let addon: AddonInfo

    struct AddonInfo: Decodable, Sendable {
        let addonid: String
        let name: String?
        let enabled: Bool?
    }
}

nonisolated struct SystemInfoResponse: Decodable, Sendable {
    // Using dynamic keys for info labels
    private let values: [String: String]

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        values = try container.decode([String: String].self)
    }

    var cpuTemperature: String? { values["System.CpuTemperature"] }
    var gpuTemperature: String? { values["System.GpuTemperature"] }
    var memoryUsedPercent: String? { values["System.Memory(used.percent)"] }
    var freeSpace: String? { values["System.FreeSpace"] }
    var totalSpace: String? { values["System.TotalSpace"] }
    var usedSpace: String? { values["System.UsedSpace"] }
    var kernelVersion: String? { values["System.KernelVersion"] }
    var osVersionInfo: String? { values["System.OSVersionInfo"] }
    var buildVersion: String? { values["System.BuildVersion"] }
    var friendlyName: String? { values["System.FriendlyName"] }
    var uptime: String? { values["System.Uptime"] }
    var totalUptime: String? { values["System.TotalUptime"] }
}

nonisolated struct DolbyVisionInfoResponse: Decodable, Sendable {
    private let values: [String: String]

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        values = try container.decode([String: String].self)
    }

    /// DV profile number (4, 5, 7, 8)
    var profile: Int? {
        guard let str = values["Player.Process(video.dovi.profile)"], !str.isEmpty else { return nil }
        return Int(str)
    }

    /// Enhancement layer type: "minimum" (MEL), "full" (FEL), or "none"
    var enhancementLayerType: String? {
        let value = values["Player.Process(video.dovi.el.type)"]
        return value?.isEmpty == false ? value : nil
    }

    /// Whether enhancement layer is present
    var hasEnhancementLayer: Bool {
        values["Player.Process(video.dovi.el.present)"]?.lowercased() == "true"
    }

    /// Whether base layer is present
    var hasBaseLayer: Bool {
        values["Player.Process(video.dovi.bl.present)"]?.lowercased() == "true"
    }

    /// Signal compatibility ID (determines profile extension like .1, .2, .4)
    var signalCompatibility: Int? {
        guard let str = values["Player.Process(video.dovi.bl.signal.compatibility)"], !str.isEmpty else { return nil }
        return Int(str)
    }

    /// Returns formatted DV string like "P7 FEL" or "P8.1 MEL"
    var formattedProfile: String? {
        guard let profile = profile else { return nil }

        var result = "P\(profile)"

        // Add compatibility extension for profile 8
        if profile == 8, let compat = signalCompatibility {
            switch compat {
            case 1: result += ".1"
            case 2: result += ".2"
            case 4: result += ".4"
            case 6: result += ".6"
            default: break
            }
        }

        // Add enhancement layer type
        if let elType = enhancementLayerType {
            switch elType.lowercased() {
            case "full": result += " FEL"
            case "minimum": result += " MEL"
            default: break
            }
        }

        return result
    }
}

nonisolated struct PlayerAudioInfoResponse: Decodable, Sendable {
    private let values: [String: String]

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        values = try container.decode([String: String].self)
    }

    /// Raw audio codec string (e.g., "truehd_atmos", "eac3_ddp_atmos", "truehd", "dts")
    var audioCodec: String? {
        let value = values["VideoPlayer.AudioCodec"]
        return value?.isEmpty == false ? value : nil
    }

    /// Whether Atmos is active
    var hasAtmos: Bool {
        guard let codec = audioCodec?.lowercased() else { return false }
        return codec.contains("atmos")
    }

    /// Whether DTS:X is active
    var hasDTSX: Bool {
        guard let codec = audioCodec?.lowercased() else { return false }
        return codec.contains("dtshd_ma_x")
    }
}
