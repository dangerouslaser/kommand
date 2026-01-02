//
//  RemoteViewModel.swift
//  kodi.remote.xbmc
//

import Foundation
import SwiftUI

@Observable
final class RemoteViewModel {
    private var appState: AppState?
    private var client = KodiClient()
    private var pollingTask: Task<Void, Never>?
    private var isPolling = false

    @ObservationIgnored
    @AppStorage("hapticFeedback") private var hapticFeedback = true

    func configure(appState: AppState) {
        self.appState = appState

        if let host = appState.currentHost {
            Task {
                await client.configure(with: host)
            }
        }
    }

    // MARK: - Polling

    func startPolling() async {
        guard !isPolling else { return }
        isPolling = true

        // Ensure client is configured
        if let host = appState?.currentHost {
            await client.configure(with: host)
        }

        await MainActor.run {
            appState?.connectionState = .connecting
        }

        // Test connection first
        await testConnection()

        // Check for CoreELEC on initial connection
        await checkCoreELEC()

        pollingTask = Task {
            while !Task.isCancelled {
                await updateNowPlaying()
                await updateVolume()
                try? await Task.sleep(for: .seconds(2))
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
        pollingTask = nil
        isPolling = false
    }

    private func updateNowPlaying() async {
        guard appState?.currentHost != nil else { return }

        do {
            let players = try await client.getActivePlayers()
            let playerId = players.first?.playerid

            await MainActor.run {
                appState?.activePlayerId = playerId
            }

            guard let playerId = playerId else {
                await MainActor.run {
                    appState?.nowPlaying = nil
                }
                return
            }

            let itemResponse = try await client.getPlayerItem(playerId: playerId)
            let properties = try await client.getPlayerProperties(playerId: playerId)

            let item = itemResponse.item
            let mediaType = MediaType(rawValue: item.type) ?? .unknown
            let videoStream = properties.currentvideostream
            let audioStream = properties.currentaudiostream
            let subtitle = properties.currentsubtitle

            // Get stream details from item (has more accurate HDR info)
            let videoStreamDetail = item.streamdetails?.video?.first
            let audioStreamDetail = item.streamdetails?.audio?.first

            let hdrType = videoStreamDetail?.hdrtype ?? videoStream?.hdrtype

            // Fetch Dolby Vision profile info if playing DV content
            var dvProfile: String?
            if hdrType?.lowercased() == "dolbyvision" {
                if let dvInfo = try? await client.getDolbyVisionInfo() {
                    dvProfile = dvInfo.formattedProfile
                }
            }

            // Fetch audio info for Atmos detection
            var hasAtmos = false
            if let audioInfo = try? await client.getPlayerAudioInfo() {
                hasAtmos = audioInfo.hasAtmos
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
                audioStreams: [],
                subtitles: [],
                currentAudioStreamIndex: audioStream?.index ?? 0,
                currentSubtitleIndex: subtitle?.index ?? -1,
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
                appState?.nowPlaying = nowPlaying
                appState?.connectionState = .connected
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

    // MARK: - Input Commands

    func sendInput(_ action: InputAction) {
        triggerHaptic(.light)

        Task {
            do {
                try await client.sendInput(action)
            } catch {
                print("Input error: \(error)")
            }
        }
    }

    func sendText(_ text: String, done: Bool = true) {
        triggerHaptic(.medium)

        Task {
            do {
                try await client.sendText(text, done: done)
            } catch {
                print("Send text error: \(error)")
            }
        }
    }

    // MARK: - Playback Commands

    func togglePlayPause() {
        triggerHaptic(.medium)

        Task {
            guard let playerId = appState?.activePlayerId else { return }
            do {
                let response = try await client.playPause(playerId: playerId)
                await MainActor.run {
                    appState?.nowPlaying?.speed = response.speed
                }
            } catch {
                print("Play/pause error: \(error)")
            }
        }
    }

    func stop() {
        triggerHaptic(.medium)

        Task {
            guard let playerId = appState?.activePlayerId else { return }
            do {
                try await client.stop(playerId: playerId)
                await MainActor.run {
                    appState?.nowPlaying = nil
                    appState?.activePlayerId = nil
                }
            } catch {
                print("Stop error: \(error)")
            }
        }
    }

    func skipPrevious() {
        triggerHaptic(.light)

        Task {
            guard let playerId = appState?.activePlayerId else { return }
            do {
                try await client.skipPrevious(playerId: playerId)
            } catch {
                print("Skip previous error: \(error)")
            }
        }
    }

    func skipNext() {
        triggerHaptic(.light)

        Task {
            guard let playerId = appState?.activePlayerId else { return }
            do {
                try await client.skipNext(playerId: playerId)
            } catch {
                print("Skip next error: \(error)")
            }
        }
    }

    func seekBackward() {
        triggerHaptic(.light)

        Task {
            guard let playerId = appState?.activePlayerId else { return }
            do {
                try await client.seekRelative(playerId: playerId, seconds: -30)
            } catch {
                print("Seek error: \(error)")
            }
        }
    }

    func seekForward() {
        triggerHaptic(.light)

        Task {
            guard let playerId = appState?.activePlayerId else { return }
            do {
                try await client.seekRelative(playerId: playerId, seconds: 30)
            } catch {
                print("Seek error: \(error)")
            }
        }
    }

    // MARK: - Volume Commands

    func setVolume(_ volume: Int) {
        Task {
            do {
                _ = try await client.setVolume(volume)
            } catch {
                print("Volume error: \(error)")
            }
        }
    }

    func toggleMute() {
        triggerHaptic(.light)

        Task {
            do {
                let muted = try await client.toggleMute()
                await MainActor.run {
                    appState?.isMuted = muted
                }
            } catch {
                print("Mute error: \(error)")
            }
        }
    }

    // MARK: - CEC Volume Commands (for TV/AVR control)

    func cecVolumeUp() {
        triggerHaptic(.light)

        Task {
            do {
                try await client.cecVolumeUp()
            } catch {
                print("CEC volume up error: \(error)")
            }
        }
    }

    func cecVolumeDown() {
        triggerHaptic(.light)

        Task {
            do {
                try await client.cecVolumeDown()
            } catch {
                print("CEC volume down error: \(error)")
            }
        }
    }

    func cecMute() {
        triggerHaptic(.medium)

        Task {
            do {
                try await client.cecMute()
            } catch {
                print("CEC mute error: \(error)")
            }
        }
    }

    // MARK: - System Power Commands

    func restartKodi() {
        triggerHaptic(.heavy)

        Task {
            do {
                try await client.quit()
            } catch {
                print("Restart Kodi error: \(error)")
            }
        }
    }

    func suspendDevice() {
        triggerHaptic(.heavy)

        Task {
            do {
                try await client.suspend()
            } catch {
                print("Suspend error: \(error)")
            }
        }
    }

    func rebootDevice() {
        triggerHaptic(.heavy)

        Task {
            do {
                try await client.reboot()
            } catch {
                print("Reboot error: \(error)")
            }
        }
    }

    func shutdownDevice() {
        triggerHaptic(.heavy)

        Task {
            do {
                try await client.shutdown()
            } catch {
                print("Shutdown error: \(error)")
            }
        }
    }

    // MARK: - Haptics

    private func triggerHaptic(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        guard hapticFeedback else { return }
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.impactOccurred()
    }
}
