//
//  RemoteViewModel.swift
//  kodi.remote.xbmc
//

import Foundation
import SwiftUI
import os

@Observable
final class RemoteViewModel {
    private var appState: AppState?
    private var client = KodiClient() // Replaced in configure() with shared instance
    private var pollingTask: Task<Void, Never>?
    private var notificationTask: Task<Void, Never>?
    private var isPolling = false
    private var usePollingFallback = false

    // Cache for expensive lookups that don't change frequently
    private var cachedDVProfile: String?
    private var cachedHasAtmos: Bool = false
    private var lastMediaFile: String?

    deinit {
        pollingTask?.cancel()
        notificationTask?.cancel()
    }

    func configure(appState: AppState) {
        self.appState = appState
        self.client = appState.client

        if let host = appState.currentHost {
            Task {
                await client.configure(with: host)
            }
        }
    }

    // MARK: - Connection

    func startPolling() async {
        guard !isPolling else { return }
        isPolling = true

        // Ensure client is configured
        if let host = appState?.currentHost {
            await client.configure(with: host)
            // Also configure the shared connection manager for Live Activity intents
            await KodiConnectionManager.shared.configure(with: host)
        }

        await MainActor.run {
            appState?.connectionState = .connecting
        }

        // Test connection first
        await testConnection()

        // Check for CoreELEC on initial connection
        await checkCoreELEC()

        // Try WebSocket first, fall back to polling if it fails
        if !usePollingFallback {
            await startWebSocketConnection()
        }

        // If WebSocket failed or isn't available, use polling
        if usePollingFallback {
            startPollingFallback()
        }
    }

    private func startWebSocketConnection() async {
        guard let stream = await client.connectWebSocket() else {
            usePollingFallback = true
            return
        }

        // Initial fetch to populate state
        await updateNowPlaying()
        await updateVolume()

        // Start WebSocket notification listener
        notificationTask = Task {
            for await notification in stream {
                if Task.isCancelled { break }
                await handleNotification(notification)
            }

            // Stream ended (WebSocket disconnected) - fall back to polling
            if !Task.isCancelled {
                await MainActor.run {
                    usePollingFallback = true
                }
                startPollingFallback()
            }
        }

        // Start a slower background poll for progress updates
        // WebSocket only sends state changes, not continuous progress
        startProgressPolling()
    }

    private func startProgressPolling() {
        pollingTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(5))
                guard !Task.isCancelled else { break }

                // Only update if we're still using WebSocket (not fallback polling)
                if !usePollingFallback {
                    await updateNowPlaying()
                }
            }
        }
    }

    private func handleNotification(_ notification: JSONRPCNotification) async {
        guard let type = KodiNotification(rawValue: notification.method) else {
            return
        }

        switch type {
        case .playerOnPlay, .playerOnPause, .playerOnStop, .playerOnSeek, .playerOnSpeedChanged:
            await updateNowPlaying()

        case .applicationOnVolumeChanged:
            await updateVolume()

        case .playerOnPropertyChanged:
            await updateNowPlaying()

        default:
            break
        }
    }

    private func startPollingFallback() {
        pollingTask = Task {
            while !Task.isCancelled {
                await updateNowPlaying()
                await updateVolume()
                try? await Task.sleep(for: .seconds(2))
                guard !Task.isCancelled else { break }
            }
        }
    }

    private func testConnection() async {
        do {
            _ = try await client.testConnection()
            await MainActor.run {
                appState?.connectionState = .connected
            }
        } catch {
            await MainActor.run {
                appState?.connectionState = .error(error.localizedDescription)
            }
        }
    }

    private func checkCoreELEC() async {
        let isCoreELEC = await client.detectCoreELEC()

        await MainActor.run {
            appState?.isCoreELEC = isCoreELEC
            appState?.serverCapabilities.isCoreELEC = isCoreELEC
        }
    }

    func stopPolling() {
        pollingTask?.cancel()
        notificationTask?.cancel()
        pollingTask = nil
        notificationTask = nil
        isPolling = false
        usePollingFallback = false

        Task {
            await client.disconnectWebSocket()
        }
    }

    private func updateNowPlaying() async {
        guard appState?.currentHost != nil else { return }

        do {
            let players = try await client.getActivePlayers()
            let playerId = players.first?.playerid

            await MainActor.run {
                appState?.activePlayerId = playerId
                // Update connection manager for Live Activity intents
                KodiConnectionManager.shared.setActivePlayer(id: playerId)
            }

            guard let playerId = playerId else {
                await MainActor.run {
                    if appState?.nowPlaying != nil {
                        appState?.nowPlaying = nil
                        // End Live Activity when playback stops
                        LiveActivityManager.shared.endActivity()
                    }
                }
                // Clear cache when playback stops
                lastMediaFile = nil
                cachedDVProfile = nil
                cachedHasAtmos = false
                return
            }

            // Run item and properties fetch in parallel
            async let itemTask = client.getPlayerItem(playerId: playerId)
            async let propertiesTask = client.getPlayerProperties(playerId: playerId)

            let (itemResponse, properties) = try await (itemTask, propertiesTask)

            let item = itemResponse.item
            let mediaType = MediaType(rawValue: item.type) ?? .unknown
            let videoStream = properties.currentvideostream
            let audioStream = properties.currentaudiostream
            let subtitle = properties.currentsubtitle

            // Get stream details from item (has more accurate HDR info)
            let videoStreamDetail = item.streamdetails?.video?.first
            let audioStreamDetail = item.streamdetails?.audio?.first

            let hdrType = videoStreamDetail?.hdrtype ?? videoStream?.hdrtype

            // Check if media file changed - reset cache if so
            let currentFile = item.file
            let mediaChanged = currentFile != lastMediaFile
            if mediaChanged {
                lastMediaFile = currentFile
                cachedDVProfile = nil
                cachedHasAtmos = false
            }

            // Fetch Dolby Vision profile info only when media changes or not cached
            var dvProfile = cachedDVProfile
            if dvProfile == nil && hdrType?.lowercased() == "dolbyvision" {
                if let dvInfo = try? await client.getDolbyVisionInfo() {
                    dvProfile = dvInfo.formattedProfile
                    cachedDVProfile = dvProfile
                }
            }

            // Fetch audio info for Atmos detection only when media changes
            var hasAtmos = cachedHasAtmos
            if mediaChanged {
                if let audioInfo = try? await client.getPlayerAudioInfo() {
                    hasAtmos = audioInfo.hasAtmos
                    cachedHasAtmos = hasAtmos
                }
            }

            // Parse subtitle tracks from player properties
            let subtitleTracks = (properties.subtitles ?? []).compactMap { sub -> Subtitle? in
                guard let index = sub.index else { return nil }
                return Subtitle(
                    id: index,
                    name: sub.name ?? "",
                    language: sub.language
                )
            }

            // Parse audio tracks from player properties
            let audioTracks = (properties.audiostreams ?? []).compactMap { audio -> AudioStream? in
                guard let index = audio.index else { return nil }
                return AudioStream(
                    id: index,
                    name: audio.name ?? "",
                    language: audio.language,
                    codec: audio.codec,
                    channels: audio.channels
                )
            }

            let nowPlaying = NowPlayingItem(
                type: mediaType,
                title: item.title ?? "Unknown",
                subtitle: item.showtitle ?? item.artist?.first,
                artworkPath: item.artworkPath,
                fanartPath: item.art?.fanart ?? item.fanart,
                duration: properties.totaltime?.totalSeconds ?? 0,
                position: properties.time?.totalSeconds ?? 0,
                speed: properties.speed ?? 0,
                audioStreams: audioTracks,
                subtitles: subtitleTracks,
                currentAudioStreamIndex: audioStream?.index ?? 0,
                currentSubtitleIndex: subtitle?.index ?? -1,
                subtitlesEnabled: properties.subtitleenabled ?? false,
                videoCodec: videoStreamDetail?.codec ?? videoStream?.codec,
                audioCodec: audioStreamDetail?.codec ?? audioStream?.codec,
                hdrType: hdrType,
                videoWidth: videoStreamDetail?.width ?? videoStream?.width,
                videoHeight: videoStreamDetail?.height ?? videoStream?.height,
                audioChannels: audioStreamDetail?.channels ?? audioStream?.channels,
                audioLanguage: audioStreamDetail?.language ?? audioStream?.language,
                subtitleLanguage: subtitle?.language,
                filePath: item.file,
                dolbyVisionProfile: dvProfile,
                hasAtmos: hasAtmos
            )

            await MainActor.run {
                let previousNowPlaying = appState?.nowPlaying
                appState?.nowPlaying = nowPlaying
                appState?.connectionState = .connected

                // Update Live Activity
                if let host = appState?.currentHost {
                    if previousNowPlaying == nil {
                        // New playback started - create Live Activity
                        LiveActivityManager.shared.startActivity(
                            for: nowPlaying,
                            host: host,
                            playerId: playerId
                        )
                    } else {
                        // Update existing Live Activity
                        LiveActivityManager.shared.updateActivity(for: nowPlaying, host: host, playerId: playerId)
                    }
                }
            }
        } catch {
            await MainActor.run {
                if case KodiError.notConnected = error {
                    appState?.connectionState = .disconnected
                }
            }
        }
    }

    private func updateVolume() async {
        do {
            let volumeInfo = try await client.getVolume()
            await MainActor.run {
                appState?.volume = volumeInfo.volume
                appState?.isMuted = volumeInfo.muted
            }
        } catch {
            // Ignore volume errors
        }
    }

    // MARK: - State Refresh

    /// Forces an immediate refresh of the now playing state
    /// Call this when returning from background or after Live Activity actions
    func refreshNowPlaying() {
        Task {
            await updateNowPlaying()
            await updateVolume()
        }
    }

    // MARK: - Input Commands

    func sendInput(_ action: InputAction) {
        HapticService.impact(.light)

        Task {
            do {
                try await client.sendInput(action)
            } catch {
                Logger.networking.error("Failed to send input: \(error.localizedDescription)")
            }
        }
    }

    func sendText(_ text: String, done: Bool = true) {
        HapticService.impact(.medium)

        Task {
            do {
                try await client.sendText(text, done: done)
            } catch {
                Logger.networking.error("Failed to send text input: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Playback Commands

    func togglePlayPause() {
        HapticService.impact(.medium)

        Task {
            guard let playerId = appState?.activePlayerId else { return }
            do {
                let response = try await client.playPause(playerId: playerId)
                await MainActor.run {
                    // Replace the struct to trigger @Observable update
                    if var nowPlaying = appState?.nowPlaying {
                        nowPlaying.speed = response.speed
                        appState?.nowPlaying = nowPlaying
                    }
                }
            } catch {
                Logger.playback.error("Failed to toggle play/pause: \(error.localizedDescription)")
            }
        }
    }

    func stop() {
        HapticService.impact(.medium)

        Task {
            guard let playerId = appState?.activePlayerId else { return }
            do {
                try await client.stop(playerId: playerId)
                await MainActor.run {
                    appState?.nowPlaying = nil
                    appState?.activePlayerId = nil
                    // End Live Activity when stopping playback
                    LiveActivityManager.shared.endActivity()
                }
            } catch {
                Logger.playback.error("Failed to stop playback: \(error.localizedDescription)")
            }
        }
    }

    func skipPrevious() {
        HapticService.impact(.light)

        Task {
            guard let playerId = appState?.activePlayerId else { return }
            do {
                try await client.skipPrevious(playerId: playerId)
            } catch {
                Logger.playback.error("Failed to skip to previous: \(error.localizedDescription)")
            }
        }
    }

    func skipNext() {
        HapticService.impact(.light)

        Task {
            guard let playerId = appState?.activePlayerId else { return }
            do {
                try await client.skipNext(playerId: playerId)
            } catch {
                Logger.playback.error("Failed to skip to next: \(error.localizedDescription)")
            }
        }
    }

    func seekBackward() {
        HapticService.impact(.light)

        Task {
            guard let playerId = appState?.activePlayerId else { return }
            do {
                try await client.seekRelative(playerId: playerId, seconds: -30)
                // Optimistic update based on estimated position
                await MainActor.run {
                    if var nowPlaying = appState?.nowPlaying {
                        let now = Date()
                        let estimatedPosition = nowPlaying.estimatedPosition(at: now)
                        nowPlaying.position = max(0, estimatedPosition - 30)
                        nowPlaying.lastUpdated = now
                        appState?.nowPlaying = nowPlaying
                    }
                }
            } catch {
                Logger.playback.error("Failed to seek backward: \(error.localizedDescription)")
            }
        }
    }

    func seekForward() {
        HapticService.impact(.light)

        Task {
            guard let playerId = appState?.activePlayerId else { return }
            do {
                try await client.seekRelative(playerId: playerId, seconds: 30)
                // Optimistic update based on estimated position
                await MainActor.run {
                    if var nowPlaying = appState?.nowPlaying {
                        let now = Date()
                        let estimatedPosition = nowPlaying.estimatedPosition(at: now)
                        nowPlaying.position = min(nowPlaying.duration, estimatedPosition + 30)
                        nowPlaying.lastUpdated = now
                        appState?.nowPlaying = nowPlaying
                    }
                }
            } catch {
                Logger.playback.error("Failed to seek forward: \(error.localizedDescription)")
            }
        }
    }

    func seekToPercentage(_ percentage: Double) {
        HapticService.impact(.light)

        Task {
            guard let playerId = appState?.activePlayerId else { return }
            do {
                // Clamp percentage to valid range
                let clamped = min(100, max(0, percentage * 100))
                try await client.seek(playerId: playerId, percentage: clamped)
                // Refresh now playing to update UI
                await updateNowPlaying()
            } catch {
                Logger.playback.error("Failed to seek to percentage: \(error.localizedDescription)")
            }
        }
    }

    func setSubtitle(_ index: Int) {
        HapticService.impact(.light)

        Task {
            guard let playerId = appState?.activePlayerId else { return }
            do {
                // Index of -1 means disable subtitles ("off")
                if index == -1 {
                    try await client.disableSubtitles(playerId: playerId)
                    await MainActor.run {
                        appState?.nowPlaying?.subtitlesEnabled = false
                    }
                } else {
                    try await client.setSubtitle(playerId: playerId, subtitleIndex: index)
                    await MainActor.run {
                        appState?.nowPlaying?.currentSubtitleIndex = index
                        appState?.nowPlaying?.subtitlesEnabled = true
                    }
                }
            } catch {
                Logger.playback.error("Failed to set subtitle: \(error.localizedDescription)")
            }
        }
    }

    func setAudioStream(_ index: Int) {
        HapticService.impact(.light)

        Task {
            guard let playerId = appState?.activePlayerId else { return }
            do {
                try await client.setAudioStream(playerId: playerId, streamIndex: index)
                await MainActor.run {
                    appState?.nowPlaying?.currentAudioStreamIndex = index
                }
            } catch {
                Logger.playback.error("Failed to set audio stream: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Volume Commands

    func setVolume(_ volume: Int) {
        Task {
            do {
                _ = try await client.setVolume(volume)
            } catch {
                Logger.playback.error("Failed to set volume: \(error.localizedDescription)")
            }
        }
    }

    func toggleMute() {
        HapticService.impact(.light)

        Task {
            do {
                let muted = try await client.toggleMute()
                await MainActor.run {
                    appState?.isMuted = muted
                }
            } catch {
                Logger.playback.error("Failed to toggle mute: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - CEC Volume Commands (for TV/AVR control)

    func cecVolumeUp() {
        HapticService.impact(.light)

        Task {
            do {
                try await client.cecVolumeUp()
            } catch {
                Logger.networking.error("Failed to send CEC volume up: \(error.localizedDescription)")
            }
        }
    }

    func cecVolumeDown() {
        HapticService.impact(.light)

        Task {
            do {
                try await client.cecVolumeDown()
            } catch {
                Logger.networking.error("Failed to send CEC volume down: \(error.localizedDescription)")
            }
        }
    }

    func cecMute() {
        HapticService.impact(.medium)

        Task {
            do {
                try await client.cecMute()
            } catch {
                Logger.networking.error("Failed to send CEC mute: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - System Power Commands

    func restartKodi() {
        HapticService.impact(.heavy)

        Task {
            do {
                try await client.quit()
            } catch {
                Logger.networking.error("Failed to restart Kodi: \(error.localizedDescription)")
            }
        }
    }

    func suspendDevice() {
        HapticService.impact(.heavy)

        Task {
            do {
                try await client.suspend()
            } catch {
                Logger.networking.error("Failed to suspend device: \(error.localizedDescription)")
            }
        }
    }

    func rebootDevice() {
        HapticService.impact(.heavy)

        Task {
            do {
                try await client.reboot()
            } catch {
                Logger.networking.error("Failed to reboot device: \(error.localizedDescription)")
            }
        }
    }

    func shutdownDevice() {
        HapticService.impact(.heavy)

        Task {
            do {
                try await client.shutdown()
            } catch {
                Logger.networking.error("Failed to shutdown device: \(error.localizedDescription)")
            }
        }
    }

}
