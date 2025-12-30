//
//  KodiClient.swift
//  kodi.remote.xbmc
//

import Foundation

actor KodiClient {
    private var host: KodiHost?
    private var session: URLSession
    private var requestId: Int = 0
    private var webSocketTask: URLSessionWebSocketTask?
    private var notificationContinuation: AsyncStream<JSONRPCNotification>.Continuation?

    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 10
        config.timeoutIntervalForResource = 30
        self.session = URLSession(configuration: config)
    }

    // MARK: - Connection

    func configure(with host: KodiHost) {
        self.host = host
    }

    func testConnection() async throws -> Bool {
        let _: String = try await send(method: "JSONRPC.Ping")
        return true
    }

    // MARK: - JSON-RPC

    private func nextRequestId() -> Int {
        requestId += 1
        return requestId
    }

    func send<T: Decodable>(method: String, params: [String: Any] = [:]) async throws -> T {
        guard let host = host, let url = host.jsonRPCURL else {
            throw KodiError.notConnected
        }

        let request = JSONRPCRequest(method: method, params: params, id: nextRequestId())
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let username = host.username, !username.isEmpty {
            // Get password from keychain (simplified - just using empty for now)
            let password = KeychainHelper.getPassword(for: host.id) ?? ""
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
            if T.self == EmptyResponse.self {
                return EmptyResponse() as! T
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
                          "currentsubtitle", "audiostreams", "subtitles", "currentvideostream"]
        ])
    }

    func getPlayerItem(playerId: Int) async throws -> PlayerItemResponse {
        try await send(method: "Player.GetItem", params: [
            "playerid": playerId,
            "properties": ["title", "artist", "album", "showtitle", "season", "episode",
                          "year", "runtime", "thumbnail", "fanart", "file"]
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
        let direction = seconds >= 0 ? "bigforward" : "bigbackward"
        let _: PlayerPropertiesResponse = try await send(method: "Player.Seek", params: [
            "playerid": playerId,
            "value": direction
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

    func setSubtitle(playerId: Int, subtitleIndex: Int, enable: Bool = true) async throws {
        let _: EmptyResponse = try await send(method: "Player.SetSubtitle", params: [
            "playerid": playerId,
            "subtitle": subtitleIndex,
            "enable": enable
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

    // MARK: - CEC Power Control

    /// Put TV/AVR to standby via CEC (does not affect the CoreELEC box)
    func cecStandby() async throws {
        try await executeAction("cecstandby")
    }

    /// Activate CEC source (wake TV and switch input to CoreELEC)
    func cecActivateSource() async throws {
        try await executeAction("cecactivatesource")
    }

    /// Toggle CEC device state
    func cecToggleState() async throws {
        try await executeAction("cectogglestate")
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

enum InputAction: String {
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

struct EmptyResponse: Decodable {}

struct PlayerSpeedResponse: Decodable {
    let speed: Int
}

struct AddonDetailsResponse: Decodable {
    let addon: AddonInfo

    struct AddonInfo: Decodable {
        let addonid: String
        let name: String?
        let enabled: Bool?
    }
}

struct SystemInfoResponse: Decodable {
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

struct SettingValueResponse: Decodable {
    let value: AnyCodableValue
}

// MARK: - Kodi Settings Models

struct SettingSectionsResponse: Decodable {
    let sections: [SettingSection]?
}

struct SettingSection: Decodable, Identifiable, Hashable {
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

struct SettingCategoriesResponse: Decodable {
    let categories: [SettingCategory]?
}

struct SettingCategory: Decodable, Identifiable, Hashable {
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

struct SettingsListResponse: Decodable {
    let settings: [KodiSetting]?
}

struct KodiSetting: Decodable, Identifiable {
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

struct SettingControl: Decodable {
    let type: String
    let format: String?
}

struct SettingOption: Decodable, Identifiable {
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

enum SettingType: String {
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
enum AnyCodableValue: Decodable {
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

enum KodiError: LocalizedError {
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

// MARK: - Keychain Helper (simplified)

enum KeychainHelper {
    static func getPassword(for hostId: UUID) -> String? {
        // Simplified - in production use Security framework
        UserDefaults.standard.string(forKey: "password_\(hostId.uuidString)")
    }

    static func setPassword(_ password: String, for hostId: UUID) {
        UserDefaults.standard.set(password, forKey: "password_\(hostId.uuidString)")
    }

    static func deletePassword(for hostId: UUID) {
        UserDefaults.standard.removeObject(forKey: "password_\(hostId.uuidString)")
    }
}
