//
//  KodiClient+PVR.swift
//  kodi.remote.xbmc
//

import Foundation

extension KodiClient {
    // MARK: - PVR

    func getPVRProperties() async throws -> PVRPropertiesResponse {
        try await send(method: "PVR.GetProperties", params: [
            "properties": ["available", "recording", "scanning"]
        ])
    }

    func getTVChannelGroups() async throws -> PVRChannelGroupsResponse {
        try await send(method: "PVR.GetChannelGroups", params: [
            "channeltype": "tv"
        ])
    }

    func getRadioChannelGroups() async throws -> PVRChannelGroupsResponse {
        try await send(method: "PVR.GetChannelGroups", params: [
            "channeltype": "radio"
        ])
    }

    func getChannels(groupId: Int) async throws -> PVRChannelsResponse {
        try await send(method: "PVR.GetChannels", params: [
            "channelgroupid": groupId,
            "properties": ["channeltype", "thumbnail", "hidden", "locked", "channel",
                          "broadcastnow", "broadcastnext", "isrecording"]
        ])
    }

    func getRecordings() async throws -> PVRRecordingsResponse {
        try await send(method: "PVR.GetRecordings", params: [
            "properties": ["title", "channel", "starttime", "endtime", "runtime",
                          "plot", "plotoutline", "genre", "playcount", "resume",
                          "directory", "icon", "art", "streamurl", "isdeleted", "radio"]
        ])
    }

    func getTimers() async throws -> PVRTimersResponse {
        try await send(method: "PVR.GetTimers", params: [
            "properties": ["title", "summary", "channelid", "starttime", "endtime",
                          "state", "ismanual", "isreadonly", "isrecording", "hastimerrules",
                          "directory", "priority", "lifetime", "preventduplicates",
                          "startmargin", "endmargin"]
        ])
    }

    func getBroadcasts(channelId: Int) async throws -> PVRBroadcastsResponse {
        try await send(method: "PVR.GetBroadcasts", params: [
            "channelid": channelId,
            "properties": ["title", "starttime", "endtime", "runtime", "plot", "plotoutline",
                          "genre", "episodename", "episodenum", "episodepart", "firstaired",
                          "hastimer", "hasrecording", "isactive", "wasactive", "progresspercentage"]
        ])
    }

    func playChannel(channelId: Int) async throws {
        let _: String = try await send(method: "Player.Open", params: [
            "item": ["channelid": channelId]
        ])
    }

    func playRecording(recordingId: Int, resume: Bool = false) async throws {
        let _: String = try await send(method: "Player.Open", params: [
            "item": ["recordingid": recordingId],
            "options": ["resume": resume]
        ])
    }

    func deleteRecording(recordingId: Int) async throws {
        let _: String = try await send(method: "PVR.DeleteRecording", params: [
            "recordingid": recordingId
        ])
    }

    func addTimer(broadcastId: Int) async throws {
        let _: String = try await send(method: "PVR.AddTimer", params: [
            "broadcastid": broadcastId
        ])
    }

    func deleteTimer(timerId: Int) async throws {
        let _: String = try await send(method: "PVR.DeleteTimer", params: [
            "timerid": timerId
        ])
    }

    func recordNow(channelId: Int) async throws {
        let _: String = try await send(method: "PVR.Record", params: [
            "record": "toggle",
            "channel": channelId
        ])
    }

    func getAllTVChannels() async throws -> PVRChannelsResponse {
        // Use "alltv" to get all TV channels regardless of channel group
        try await send(method: "PVR.GetChannels", params: [
            "channelgroupid": "alltv",
            "properties": ["channeltype", "thumbnail", "hidden", "locked", "channel",
                          "broadcastnow", "broadcastnext", "isrecording"]
        ])
    }
}
