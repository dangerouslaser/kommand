//
//  NowPlayingMediaMetadata.swift
//  kodi.remote.xbmc
//

import SwiftUI

struct NowPlayingMediaMetadata {
    let item: NowPlayingItem
    let showDolbyVisionProfile: Bool

    var colorspaceBadge: String {
        if let hdr = item.hdrType, !hdr.isEmpty {
            return formatHDR(hdr)
        }
        return "SDR"
    }

    var colorspaceBadgeColor: Color {
        guard let hdr = item.hdrType?.lowercased(), !hdr.isEmpty else {
            return .white.opacity(0.6)
        }
        switch hdr {
        case "dolbyvision": return .purple
        case "hdr10", "hdr10plus": return .orange
        case "hlg": return .green
        default: return .orange
        }
    }

    var hasFEL: Bool {
        item.dolbyVisionProfile?.contains("FEL") == true
    }

    var formattedResolution: String? {
        guard let width = item.videoWidth, let height = item.videoHeight else { return nil }
        if width >= 3840 {
            return "4K"
        } else if width >= 1920 {
            return "1080p"
        } else if width >= 1280 {
            return "720p"
        } else if width >= 720 {
            return "480p"
        }
        return "\(width)x\(height)"
    }

    var videoInfoString: String {
        var parts: [String] = []
        if let codec = item.videoCodec {
            parts.append(formatVideoCodec(codec))
        }
        if let width = item.videoWidth, let height = item.videoHeight {
            parts.append("\(width)x\(height)")
        }
        if let hdr = item.hdrType, !hdr.isEmpty {
            parts.append(formatHDRFull(hdr))
        } else {
            parts.append("SDR")
        }
        return parts.joined(separator: " • ")
    }

    func formatAudioCodecShort(_ codec: String?) -> String {
        guard let codec else { return "" }
        let lower = codec.lowercased()

        if lower.contains("truehd") {
            return "TrueHD"
        } else if lower.contains("dts") {
            if lower.contains("hd") || lower.contains("ma") {
                return "DTS-HD"
            } else if lower.contains("x") {
                return "DTS:X"
            }
            return "DTS"
        } else if lower.contains("eac3") || lower.contains("ec3") || lower.contains("ddp") {
            return "DD+"
        } else if lower.contains("ac3") || lower.contains("dolby") {
            return "DD"
        } else if lower.contains("aac") {
            return "AAC"
        } else if lower.contains("flac") {
            return "FLAC"
        } else if lower.contains("pcm") {
            return "PCM"
        }
        return codec.uppercased()
    }

    func formatAudioCodecFull(_ codec: String?, channels: Int?) -> String {
        guard let codec else { return "Unknown" }
        let lower = codec.lowercased()
        var name: String

        if lower.contains("truehd") {
            name = "Dolby TrueHD"
        } else if lower.contains("dts") {
            if lower.contains("hd") && lower.contains("ma") {
                name = "DTS-HD Master Audio"
            } else if lower.contains("hd") {
                name = "DTS-HD"
            } else if lower.contains("x") {
                name = "DTS:X"
            } else {
                name = "DTS"
            }
        } else if lower.contains("eac3") || lower.contains("ec3") || lower.contains("ddp") {
            name = "Dolby Digital Plus"
        } else if lower.contains("ac3") {
            name = "Dolby Digital"
        } else if lower.contains("aac") {
            name = "AAC"
        } else if lower.contains("flac") {
            name = "FLAC"
        } else if lower.contains("pcm") {
            name = "PCM"
        } else {
            name = codec.uppercased()
        }

        if let channels {
            name += " \(formatChannels(channels))"
        }

        if item.hasAtmos {
            name += " (Atmos)"
        }

        return name
    }

    private func formatHDR(_ type: String) -> String {
        switch type.lowercased() {
        case "dolbyvision": return "DV"
        case "hdr10": return "HDR10"
        case "hdr10plus": return "HDR10+"
        case "hlg": return "HLG"
        default: return type.uppercased()
        }
    }

    private func formatHDRFull(_ type: String) -> String {
        switch type.lowercased() {
        case "dolbyvision":
            if showDolbyVisionProfile, let dvProfile = item.dolbyVisionProfile {
                return "DV \(dvProfile)"
            }
            return "DV"
        case "hdr10": return "HDR10"
        case "hdr10plus": return "HDR10+"
        case "hlg": return "HLG"
        default: return type.uppercased()
        }
    }

    private func formatVideoCodec(_ codec: String) -> String {
        switch codec.lowercased() {
        case "hevc", "h265": return "HEVC"
        case "h264", "avc": return "H.264"
        case "av1": return "AV1"
        case "vp9": return "VP9"
        case "mpeg2video": return "MPEG-2"
        default: return codec.uppercased()
        }
    }

    private func formatChannels(_ channels: Int) -> String {
        switch channels {
        case 1: return "1.0"
        case 2: return "2.0"
        case 6: return "5.1"
        case 8: return "7.1"
        default: return "\(channels)ch"
        }
    }
}
