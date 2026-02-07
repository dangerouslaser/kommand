//
//  KodiClient.swift
//  kodi.remote.xbmc
//

import Foundation

actor KodiClient {
    private var host: KodiHost?
    private var passwordOverride: String?
    private var session: URLSession
    private var requestId: Int = 0
    private var webSocketManager: WebSocketManager?

    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 10
        config.timeoutIntervalForResource = 30
        self.session = URLSession(configuration: config)
    }

    // MARK: - Connection

    func configure(with host: KodiHost, password: String? = nil) {
        self.host = host
        self.passwordOverride = password
    }

    func testConnection() async throws -> Bool {
        let _: String = try await send(method: "JSONRPC.Ping")
        return true
    }

    // MARK: - WebSocket

    func connectWebSocket() async -> AsyncStream<JSONRPCNotification>? {
        guard let host = host else { return nil }

        webSocketManager = WebSocketManager()
        return await webSocketManager?.connect(to: host)
    }

    func disconnectWebSocket() async {
        await webSocketManager?.disconnect()
        webSocketManager = nil
    }

    var isWebSocketConnected: Bool {
        get async {
            await webSocketManager?.isConnected ?? false
        }
    }

    // MARK: - JSON-RPC

    private func nextRequestId() -> Int {
        requestId += 1
        return requestId
    }

    func send<T: Decodable & Sendable>(method: String, params: [String: Any] = [:]) async throws -> T {
        guard let host = host, let url = host.jsonRPCURL else {
            throw KodiError.notConnected
        }

        let request = JSONRPCRequest(method: method, params: params, id: nextRequestId())
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let username = host.username, !username.isEmpty {
            let password = passwordOverride ?? KeychainHelper.getPassword(for: host.id) ?? ""
            let credentials = "\(username):\(password)"
            if let data = credentials.data(using: .utf8) {
                let base64 = data.base64EncodedString()
                urlRequest.setValue("Basic \(base64)", forHTTPHeaderField: "Authorization")
            }
        }

        let encoder = JSONEncoder()
        urlRequest.httpBody = try encoder.encode(request)

        let (data, response) = try await session.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw KodiError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            throw KodiError.httpError(httpResponse.statusCode)
        }

        let decoder = JSONDecoder()
        let rpcResponse = try decoder.decode(JSONRPCResponse<T>.self, from: data)

        if let error = rpcResponse.error {
            throw KodiError.rpcError(error.code, error.message)
        }

        guard let result = rpcResponse.result else {
            // Some methods return empty result
            if T.self == EmptyResponse.self, let empty = EmptyResponse() as? T {
                return empty
            }
            throw KodiError.noResult
        }

        return result
    }

    // MARK: - Input Commands

    func sendInput(_ action: InputAction) async throws {
        let _: String = try await send(method: "Input.\(action.rawValue)")
    }

    func sendText(_ text: String, done: Bool = true) async throws {
        let _: String = try await send(method: "Input.SendText", params: ["text": text, "done": done])
    }

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
        let _: EmptyResponse = try await send(method: "Player.SetAudioStream", params: [
            "playerid": playerId,
            "stream": streamIndex
        ])
    }

    func setSubtitle(playerId: Int, subtitleIndex: Int) async throws {
        let _: EmptyResponse = try await send(method: "Player.SetSubtitle", params: [
            "playerid": playerId,
            "subtitle": subtitleIndex,
            "enable": true
        ])
    }

    func disableSubtitles(playerId: Int) async throws {
        let _: EmptyResponse = try await send(method: "Player.SetSubtitle", params: [
            "playerid": playerId,
            "subtitle": "off"
        ])
    }

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

    // MARK: - CEC Volume Control (for TV/AVR via HDMI-CEC)

    /// Execute an action via Input.ExecuteAction - used for CEC volume passthrough
    func executeAction(_ action: String) async throws {
        let _: String = try await send(method: "Input.ExecuteAction", params: ["action": action])
    }

    /// Increase volume via CEC (sends to TV/AVR if CEC is configured)
    func cecVolumeUp() async throws {
        try await executeAction("volumeup")
    }

    /// Decrease volume via CEC (sends to TV/AVR if CEC is configured)
    func cecVolumeDown() async throws {
        try await executeAction("volumedown")
    }

    /// Toggle mute via CEC (sends to TV/AVR if CEC is configured)
    func cecMute() async throws {
        try await executeAction("mute")
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

    func getSettingValue(setting: String) async throws -> SettingValueResponse {
        try await send(method: "Settings.GetSettingValue", params: [
            "setting": setting
        ])
    }

    func setSettingValue(setting: String, value: Any) async throws {
        let _: EmptyResponse = try await send(method: "Settings.SetSettingValue", params: [
            "setting": setting,
            "value": value
        ])
    }

    // MARK: - Kodi Settings Browser

    func getSettingSections() async throws -> SettingSectionsResponse {
        try await send(method: "Settings.GetSections", params: [
            "level": "expert"
        ])
    }

    func getSettingCategories(section: String) async throws -> SettingCategoriesResponse {
        try await send(method: "Settings.GetCategories", params: [
            "section": section,
            "level": "expert"
        ])
    }

    func getSettings(section: String? = nil, category: String? = nil) async throws -> SettingsListResponse {
        var params: [String: Any] = ["level": "expert"]
        var filter: [String: String] = [:]
        if let section = section {
            filter["section"] = section
        }
        if let category = category {
            filter["category"] = category
        }
        if !filter.isEmpty {
            params["filter"] = filter
        }
        return try await send(method: "Settings.GetSettings", params: params)
    }

    func resetSettingToDefault(setting: String) async throws {
        let _: String = try await send(method: "Settings.ResetSettingValue", params: [
            "setting": setting
        ])
    }

    // MARK: - Video Library

    func getMovies(
        sort: (field: String, ascending: Bool) = ("title", true),
        start: Int = 0,
        limit: Int = 100
    ) async throws -> MoviesResponse {
        try await send(method: "VideoLibrary.GetMovies", params: [
            "properties": ["title", "year", "runtime", "rating", "plot", "genre", "director",
                          "writer", "studio", "tagline", "cast", "thumbnail", "fanart", "art",
                          "playcount", "resume", "file", "trailer", "mpaa", "imdbnumber",
                          "dateadded", "lastplayed", "streamdetails"],
            "sort": ["method": sort.field, "order": sort.ascending ? "ascending" : "descending"],
            "limits": ["start": start, "end": start + limit]
        ])
    }

    func getMoviesByActor(actorName: String) async throws -> MoviesResponse {
        try await send(method: "VideoLibrary.GetMovies", params: [
            "properties": ["title", "year", "runtime", "rating", "plot", "genre", "director",
                          "writer", "studio", "tagline", "cast", "thumbnail", "fanart", "art",
                          "playcount", "resume", "file", "trailer", "mpaa", "imdbnumber",
                          "dateadded", "lastplayed", "streamdetails"],
            "filter": ["actor": actorName],
            "sort": ["method": "year", "order": "descending"]
        ])
    }

    func getMovieDetails(movieId: Int) async throws -> MovieDetailsResponse {
        try await send(method: "VideoLibrary.GetMovieDetails", params: [
            "movieid": movieId,
            "properties": ["title", "year", "runtime", "rating", "plot", "genre", "director",
                          "writer", "studio", "tagline", "cast", "thumbnail", "fanart", "art",
                          "playcount", "resume", "file", "trailer", "mpaa", "imdbnumber",
                          "dateadded", "lastplayed", "streamdetails"]
        ])
    }

    func getRecentlyAddedMovies(limit: Int = 25) async throws -> MoviesResponse {
        try await send(method: "VideoLibrary.GetRecentlyAddedMovies", params: [
            "properties": ["title", "year", "runtime", "rating", "plot", "genre", "director",
                          "writer", "studio", "tagline", "cast", "thumbnail", "fanart", "art",
                          "playcount", "resume", "file", "trailer", "mpaa", "imdbnumber",
                          "dateadded", "lastplayed", "streamdetails"],
            "limits": ["start": 0, "end": limit]
        ])
    }

    func getInProgressMovies() async throws -> MoviesResponse {
        try await send(method: "VideoLibrary.GetMovies", params: [
            "properties": ["title", "year", "runtime", "rating", "plot", "genre", "director",
                          "writer", "studio", "tagline", "cast", "thumbnail", "fanart", "art",
                          "playcount", "resume", "file", "trailer", "mpaa", "imdbnumber",
                          "dateadded", "lastplayed", "streamdetails"],
            "filter": ["field": "inprogress", "operator": "true", "value": ""],
            "sort": ["method": "lastplayed", "order": "descending"]
        ])
    }

    func getTVShows(
        sort: (field: String, ascending: Bool) = ("title", true),
        start: Int = 0,
        limit: Int = 100
    ) async throws -> TVShowsResponse {
        try await send(method: "VideoLibrary.GetTVShows", params: [
            "properties": ["title", "year", "rating", "plot", "genre", "studio", "cast",
                          "thumbnail", "fanart", "art", "episode", "watchedepisodes", "season",
                          "playcount", "file", "imdbnumber", "premiered", "dateadded"],
            "sort": ["method": sort.field, "order": sort.ascending ? "ascending" : "descending"],
            "limits": ["start": start, "end": start + limit]
        ])
    }

    func getTVShowDetails(tvShowId: Int) async throws -> TVShowDetailsResponse {
        try await send(method: "VideoLibrary.GetTVShowDetails", params: [
            "tvshowid": tvShowId,
            "properties": ["title", "year", "rating", "plot", "genre", "studio", "cast",
                          "thumbnail", "fanart", "art", "episode", "watchedepisodes", "season",
                          "playcount", "file", "imdbnumber", "premiered", "dateadded"]
        ])
    }

    func getSeasons(tvShowId: Int) async throws -> SeasonsResponse {
        try await send(method: "VideoLibrary.GetSeasons", params: [
            "tvshowid": tvShowId,
            "properties": ["season", "showtitle", "tvshowid", "episode", "watchedepisodes",
                          "thumbnail", "fanart", "art", "playcount"],
            "sort": ["method": "season", "order": "ascending"]
        ])
    }

    func getEpisodes(
        tvShowId: Int,
        season: Int? = nil,
        start: Int = 0,
        limit: Int = 100
    ) async throws -> EpisodesResponse {
        var params: [String: Any] = [
            "tvshowid": tvShowId,
            "properties": ["title", "episode", "season", "showtitle", "tvshowid", "runtime",
                          "rating", "plot", "director", "writer", "thumbnail", "fanart",
                          "playcount", "resume", "file", "firstaired", "dateadded", "streamdetails"],
            "sort": ["method": "episode", "order": "ascending"],
            "limits": ["start": start, "end": start + limit]
        ]
        if let season = season {
            params["season"] = season
        }
        return try await send(method: "VideoLibrary.GetEpisodes", params: params)
    }

    func getEpisodeDetails(episodeId: Int) async throws -> EpisodeDetailsResponse {
        try await send(method: "VideoLibrary.GetEpisodeDetails", params: [
            "episodeid": episodeId,
            "properties": ["title", "episode", "season", "showtitle", "tvshowid", "runtime",
                          "rating", "plot", "director", "writer", "thumbnail", "fanart",
                          "playcount", "resume", "file", "firstaired", "dateadded", "streamdetails"]
        ])
    }

    func getRecentlyAddedEpisodes(limit: Int = 25) async throws -> EpisodesResponse {
        try await send(method: "VideoLibrary.GetRecentlyAddedEpisodes", params: [
            "properties": ["title", "episode", "season", "showtitle", "tvshowid", "runtime",
                          "rating", "plot", "director", "writer", "thumbnail", "fanart",
                          "playcount", "resume", "file", "firstaired", "dateadded", "streamdetails"],
            "limits": ["start": 0, "end": limit]
        ])
    }

    func getInProgressEpisodes() async throws -> EpisodesResponse {
        try await send(method: "VideoLibrary.GetEpisodes", params: [
            "properties": ["title", "episode", "season", "showtitle", "tvshowid", "runtime",
                          "rating", "plot", "director", "writer", "thumbnail", "fanart",
                          "playcount", "resume", "file", "firstaired", "dateadded", "streamdetails"],
            "filter": ["field": "inprogress", "operator": "true", "value": ""],
            "sort": ["method": "lastplayed", "order": "descending"]
        ])
    }

    // MARK: - Playback from Library

    func playMovie(movieId: Int, resume: Bool = false) async throws {
        let _: String = try await send(method: "Player.Open", params: [
            "item": ["movieid": movieId],
            "options": ["resume": resume]
        ])
    }

    func playEpisode(episodeId: Int, resume: Bool = false) async throws {
        let _: String = try await send(method: "Player.Open", params: [
            "item": ["episodeid": episodeId],
            "options": ["resume": resume]
        ])
    }

    func queueMovie(movieId: Int) async throws {
        let _: String = try await send(method: "Playlist.Add", params: [
            "playlistid": 1,
            "item": ["movieid": movieId]
        ])
    }

    func queueEpisode(episodeId: Int) async throws {
        let _: String = try await send(method: "Playlist.Add", params: [
            "playlistid": 1,
            "item": ["episodeid": episodeId]
        ])
    }

    func setWatched(movieId: Int, watched: Bool) async throws {
        let _: String = try await send(method: "VideoLibrary.SetMovieDetails", params: [
            "movieid": movieId,
            "playcount": watched ? 1 : 0
        ])
    }

    func setWatched(episodeId: Int, watched: Bool) async throws {
        let _: String = try await send(method: "VideoLibrary.SetEpisodeDetails", params: [
            "episodeid": episodeId,
            "playcount": watched ? 1 : 0
        ])
    }

    // MARK: - Audio Library

    func getArtists(
        sort: (field: String, ascending: Bool) = ("artist", true),
        start: Int = 0,
        limit: Int = 500
    ) async throws -> ArtistsResponse {
        try await send(method: "AudioLibrary.GetArtists", params: [
            "properties": ["artist", "description", "genre", "thumbnail", "fanart", "art"],
            "sort": ["method": sort.field, "order": sort.ascending ? "ascending" : "descending"],
            "limits": ["start": start, "end": start + limit]
        ])
    }

    func getAlbums(
        artistId: Int? = nil,
        sort: (field: String, ascending: Bool) = ("title", true),
        start: Int = 0,
        limit: Int = 500
    ) async throws -> AlbumsResponse {
        var params: [String: Any] = [
            "properties": ["title", "artist", "displayartist", "year", "genre", "rating",
                          "thumbnail", "fanart", "art", "playcount", "artistid", "dateadded"],
            "sort": ["method": sort.field, "order": sort.ascending ? "ascending" : "descending"],
            "limits": ["start": start, "end": start + limit]
        ]
        if let artistId = artistId {
            params["filter"] = ["artistid": artistId]
        }
        return try await send(method: "AudioLibrary.GetAlbums", params: params)
    }

    func getRecentlyAddedAlbums(limit: Int = 25) async throws -> AlbumsResponse {
        try await send(method: "AudioLibrary.GetRecentlyAddedAlbums", params: [
            "properties": ["title", "artist", "displayartist", "year", "genre", "rating",
                          "thumbnail", "fanart", "art", "playcount", "artistid", "dateadded"],
            "limits": ["start": 0, "end": limit]
        ])
    }

    func getSongs(
        albumId: Int? = nil,
        artistId: Int? = nil,
        sort: (field: String, ascending: Bool) = ("track", true),
        start: Int = 0,
        limit: Int = 500
    ) async throws -> SongsResponse {
        var params: [String: Any] = [
            "properties": ["title", "artist", "displayartist", "album", "albumid", "albumartist",
                          "track", "disc", "duration", "year", "genre", "rating", "playcount",
                          "thumbnail", "fanart", "art", "file", "dateadded", "lastplayed"],
            "sort": ["method": sort.field, "order": sort.ascending ? "ascending" : "descending"],
            "limits": ["start": start, "end": start + limit]
        ]
        if let albumId = albumId {
            params["filter"] = ["albumid": albumId]
        } else if let artistId = artistId {
            params["filter"] = ["artistid": artistId]
        }
        return try await send(method: "AudioLibrary.GetSongs", params: params)
    }

    func getRecentlyAddedSongs(limit: Int = 25) async throws -> SongsResponse {
        try await send(method: "AudioLibrary.GetRecentlyAddedSongs", params: [
            "properties": ["title", "artist", "displayartist", "album", "albumid", "albumartist",
                          "track", "disc", "duration", "year", "genre", "rating", "playcount",
                          "thumbnail", "fanart", "art", "file", "dateadded", "lastplayed"],
            "limits": ["start": 0, "end": limit]
        ])
    }

    // MARK: - Audio Playback

    func playAlbum(albumId: Int, shuffle: Bool = false) async throws {
        // Clear playlist, add album, then play
        let _: String = try await send(method: "Playlist.Clear", params: ["playlistid": 0])
        let _: String = try await send(method: "Playlist.Add", params: [
            "playlistid": 0,
            "item": ["albumid": albumId]
        ])
        let _: String = try await send(method: "Player.Open", params: [
            "item": ["playlistid": 0],
            "options": ["shuffled": shuffle]
        ])
    }

    func playSong(songId: Int) async throws {
        let _: String = try await send(method: "Player.Open", params: [
            "item": ["songid": songId]
        ])
    }

    func queueAlbum(albumId: Int) async throws {
        let _: String = try await send(method: "Playlist.Add", params: [
            "playlistid": 0,
            "item": ["albumid": albumId]
        ])
    }

    func queueSong(songId: Int) async throws {
        let _: String = try await send(method: "Playlist.Add", params: [
            "playlistid": 0,
            "item": ["songid": songId]
        ])
    }

    func playArtist(artistId: Int, shuffle: Bool = true) async throws {
        let _: String = try await send(method: "Playlist.Clear", params: ["playlistid": 0])
        let _: String = try await send(method: "Playlist.Add", params: [
            "playlistid": 0,
            "item": ["artistid": artistId]
        ])
        let _: String = try await send(method: "Player.Open", params: [
            "item": ["playlistid": 0],
            "options": ["shuffled": shuffle]
        ])
    }

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

    // MARK: - Search

    func searchMovies(query: String, limit: Int = 25) async throws -> MoviesResponse {
        try await send(method: "VideoLibrary.GetMovies", params: [
            "properties": ["title", "year", "runtime", "rating", "plot", "genre", "director",
                          "writer", "studio", "tagline", "cast", "thumbnail", "fanart", "art",
                          "playcount", "resume", "file", "trailer", "mpaa", "imdbnumber",
                          "dateadded", "lastplayed", "streamdetails"],
            "filter": ["field": "title", "operator": "contains", "value": query],
            "sort": ["method": "title", "order": "ascending"],
            "limits": ["start": 0, "end": limit]
        ])
    }

    func searchTVShows(query: String, limit: Int = 25) async throws -> TVShowsResponse {
        try await send(method: "VideoLibrary.GetTVShows", params: [
            "properties": ["title", "year", "rating", "plot", "genre", "studio", "cast",
                          "thumbnail", "fanart", "art", "episode", "watchedepisodes", "season",
                          "playcount", "file", "imdbnumber", "premiered", "dateadded"],
            "filter": ["field": "title", "operator": "contains", "value": query],
            "sort": ["method": "title", "order": "ascending"],
            "limits": ["start": 0, "end": limit]
        ])
    }

    func searchEpisodes(query: String, limit: Int = 25) async throws -> EpisodesResponse {
        try await send(method: "VideoLibrary.GetEpisodes", params: [
            "properties": ["title", "episode", "season", "showtitle", "tvshowid", "runtime",
                          "rating", "plot", "director", "writer", "thumbnail", "fanart",
                          "playcount", "resume", "file", "firstaired", "dateadded", "streamdetails"],
            "filter": ["field": "title", "operator": "contains", "value": query],
            "sort": ["method": "title", "order": "ascending"],
            "limits": ["start": 0, "end": limit]
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

// MARK: - Supporting Types

nonisolated enum InputAction: String {
    case up = "Up"
    case down = "Down"
    case left = "Left"
    case right = "Right"
    case select = "Select"
    case back = "Back"
    case home = "Home"
    case contextMenu = "ContextMenu"
    case info = "Info"
    case osd = "ShowOSD"
}

nonisolated struct EmptyResponse: Decodable, Sendable {}

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

nonisolated struct SettingValueResponse: Decodable, Sendable {
    let value: AnyCodableValue
}

// MARK: - Kodi Settings Models

nonisolated struct SettingSectionsResponse: Decodable, Sendable {
    let sections: [SettingSection]?
}

nonisolated struct SettingSection: Decodable, Identifiable, Hashable, Sendable {
    let id: String
    let label: String
    let help: String?

    static func == (lhs: SettingSection, rhs: SettingSection) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

nonisolated struct SettingCategoriesResponse: Decodable, Sendable {
    let categories: [SettingCategory]?
}

nonisolated struct SettingCategory: Decodable, Identifiable, Hashable, Sendable {
    let id: String
    let label: String
    let help: String?

    static func == (lhs: SettingCategory, rhs: SettingCategory) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

nonisolated struct SettingsListResponse: Decodable, Sendable {
    let settings: [KodiSetting]?
}

nonisolated struct KodiSetting: Decodable, Identifiable, Sendable {
    let id: String
    let label: String
    let help: String?
    let type: String
    let value: AnyCodableValue?
    let `default`: AnyCodableValue?
    let enabled: Bool?
    let parent: String?
    let control: SettingControl?
    let options: [SettingOption]?
    let minimum: Double?
    let maximum: Double?
    let step: Double?

    var settingType: SettingType {
        SettingType(rawValue: type) ?? .unknown
    }
}

nonisolated struct SettingControl: Decodable, Sendable {
    let type: String
    let format: String?
}

nonisolated struct SettingOption: Decodable, Identifiable, Sendable {
    let label: String
    let value: AnyCodableValue

    var id: String {
        if let intVal = value.intValue {
            return String(intVal)
        } else if let strVal = value.stringValue {
            return strVal
        }
        return label
    }
}

nonisolated enum SettingType: String, Sendable {
    case boolean = "boolean"
    case integer = "integer"
    case number = "number"
    case string = "string"
    case action = "action"
    case list = "list"
    case path = "path"
    case addon = "addon"
    case unknown

    var icon: String {
        switch self {
        case .boolean: return "switch.2"
        case .integer, .number: return "number"
        case .string, .path: return "textformat"
        case .action: return "play.circle"
        case .list: return "list.bullet"
        case .addon: return "puzzlepiece"
        case .unknown: return "questionmark.circle"
        }
    }
}

// Helper for decoding any JSON value
nonisolated enum AnyCodableValue: Decodable, Sendable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case null

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode(Int.self) {
            self = .int(value)
        } else if let value = try? container.decode(Double.self) {
            self = .double(value)
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else {
            self = .null
        }
    }

    var stringValue: String? {
        if case .string(let value) = self { return value }
        return nil
    }

    var intValue: Int? {
        if case .int(let value) = self { return value }
        return nil
    }

    var boolValue: Bool? {
        if case .bool(let value) = self { return value }
        return nil
    }
}

// MARK: - Errors

nonisolated enum KodiError: LocalizedError, Sendable {
    case notConnected
    case invalidResponse
    case httpError(Int)
    case rpcError(Int, String)
    case noResult
    case timeout

    var errorDescription: String? {
        switch self {
        case .notConnected:
            return "Not connected to Kodi"
        case .invalidResponse:
            return "Invalid response from Kodi"
        case .httpError(let code):
            return "HTTP error: \(code)"
        case .rpcError(let code, let message):
            return "RPC error \(code): \(message)"
        case .noResult:
            return "No result returned"
        case .timeout:
            return "Connection timed out"
        }
    }
}

// MARK: - Keychain Helper (alias for backward compatibility)

typealias KeychainHelper = KeychainService
