//
//  KodiClient+Player.swift
//  kodi.remote.xbmc
//

import Foundation

extension KodiClient {
    // MARK: - Player Commands

    func getActivePlayers() async throws -> [ActivePlayersResponse] {
        try await send(method: "Player.GetActivePlayers")
    }

    func getPlayerProperties(playerId: Int) async throws -> PlayerPropertiesResponse {
        try await send(method: "Player.GetProperties", params: [
            "playerid": playerId,
            "properties": ["time", "totaltime", "percentage", "speed", "playlistid",
                          "position", "shuffled", "repeat", "currentaudiostream",
                          "currentsubtitle", "subtitleenabled", "audiostreams", "subtitles", "currentvideostream"]
        ])
    }

    func getPlayerItem(playerId: Int) async throws -> PlayerItemResponse {
        try await send(method: "Player.GetItem", params: [
            "playerid": playerId,
            "properties": ["title", "artist", "album", "showtitle", "season", "episode",
                          "year", "runtime", "thumbnail", "fanart", "file", "art", "streamdetails"]
        ])
    }

    func playPause(playerId: Int) async throws -> PlayerSpeedResponse {
        try await send(method: "Player.PlayPause", params: ["playerid": playerId])
    }

    func stop(playerId: Int) async throws {
        let _: String = try await send(method: "Player.Stop", params: ["playerid": playerId])
    }

    func seek(playerId: Int, percentage: Double) async throws {
        let _: PlayerPropertiesResponse = try await send(method: "Player.Seek", params: [
            "playerid": playerId,
            "value": ["percentage": percentage]
        ])
    }

    func seekRelative(playerId: Int, seconds: Int) async throws {
        let _: PlayerPropertiesResponse = try await send(method: "Player.Seek", params: [
            "playerid": playerId,
            "value": ["seconds": seconds]
        ])
    }

    func skipNext(playerId: Int) async throws {
        let _: String = try await send(method: "Player.GoTo", params: [
            "playerid": playerId,
            "to": "next"
        ])
    }

    func skipPrevious(playerId: Int) async throws {
        let _: String = try await send(method: "Player.GoTo", params: [
            "playerid": playerId,
            "to": "previous"
        ])
    }

    func setAudioStream(playerId: Int, streamIndex: Int) async throws {
        let _: String = try await send(method: "Player.SetAudioStream", params: [
            "playerid": playerId,
            "stream": streamIndex
        ])
    }

    func setSubtitle(playerId: Int, subtitleIndex: Int) async throws {
        let _: String = try await send(method: "Player.SetSubtitle", params: [
            "playerid": playerId,
            "subtitle": subtitleIndex,
            "enable": true
        ])
    }

    func disableSubtitles(playerId: Int) async throws {
        let _: String = try await send(method: "Player.SetSubtitle", params: [
            "playerid": playerId,
            "subtitle": "off"
        ])
    }

    func getDolbyVisionInfo() async throws -> DolbyVisionInfoResponse {
        try await send(method: "XBMC.GetInfoLabels", params: [
            "labels": [
                "Player.Process(video.dovi.profile)",
                "Player.Process(video.dovi.el.type)",
                "Player.Process(video.dovi.el.present)",
                "Player.Process(video.dovi.bl.present)",
                "Player.Process(video.dovi.bl.signal.compatibility)"
            ]
        ])
    }

    func getPlayerAudioInfo() async throws -> PlayerAudioInfoResponse {
        try await send(method: "XBMC.GetInfoLabels", params: [
            "labels": [
                "VideoPlayer.AudioCodec"
            ]
        ])
    }
}
