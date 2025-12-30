//
//  RemoteViewModel.swift
//  kodi.remote.xbmc
//

import Foundation
import SwiftUI

@Observable
final class RemoteViewModel {
    private var appState: AppState?
    private let client = KodiClient()
    private var pollingTask: Task<Void, Never>?
    private var isPolling = false

    @ObservationIgnored
    @AppStorage("hapticFeedback") private var hapticFeedback = true

    func configure(appState: AppState) {
        self.appState = appState
    }

    // MARK: - Polling

    func startPolling() async {
        guard !isPolling else { return }
        isPolling = true

        // Configure client with current host
        if let host = appState?.currentHost {
            await client.configure(with: host)
            await MainActor.run {
                appState?.connectionState = .connecting
            }
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

            await MainActor.run {
                appState?.activePlayerId = players.first?.playerid
            }

            guard let playerId = players.first?.playerid else {
                await MainActor.run {
                    appState?.nowPlaying = nil
                }
                return
            }

            async let itemTask = client.getPlayerItem(playerId: playerId)
            async let propsTask = client.getPlayerProperties(playerId: playerId)

            let (itemResponse, props) = try await (itemTask, propsTask)
            let item = itemResponse.item

            let nowPlaying = NowPlayingItem(
                type: MediaType(from: item.type),
                title: item.title ?? item.label ?? "Unknown",
                subtitle: buildSubtitle(from: item),
                artworkPath: item.thumbnail,
                fanartPath: item.fanart,
                duration: props.totaltime?.totalSeconds ?? 0,
                position: props.time?.totalSeconds ?? 0,
                speed: props.speed ?? 0,
                audioStreams: (props.audiostreams ?? []).enumerated().map { index, stream in
                    AudioStream(
                        id: stream.index ?? index,
                        name: stream.name ?? "",
                        language: stream.language,
                        codec: stream.codec,
                        channels: stream.channels
                    )
                },
                subtitles: (props.subtitles ?? []).enumerated().map { index, sub in
                    Subtitle(
                        id: sub.index ?? index,
                        name: sub.name ?? "",
                        language: sub.language
                    )
                },
                currentAudioStreamIndex: props.currentaudiostream?.index ?? 0,
                currentSubtitleIndex: props.currentsubtitle?.index ?? -1,
                videoCodec: props.currentvideostream?.codec,
                audioCodec: props.currentaudiostream?.codec,
                hdrType: props.currentvideostream?.hdrtype
            )

            await MainActor.run {
                appState?.nowPlaying = nowPlaying
                appState?.connectionState = .connected
            }
        } catch {
            await MainActor.run {
                if case .notConnected = error as? KodiError {
                    appState?.connectionState = .disconnected
                }
            }
        }
    }

    private func updateVolume() async {
        do {
            let volume = try await client.getVolume()
            await MainActor.run {
                appState?.volume = volume.volume
                appState?.isMuted = volume.muted
            }
        } catch {
            // Ignore volume errors
        }
    }

    private func buildSubtitle(from item: PlayerItemResponse.MediaItem) -> String? {
        switch item.type {
        case "episode":
            if let show = item.showtitle, let season = item.season, let episode = item.episode {
                return "\(show) S\(season)E\(episode)"
            }
            return item.showtitle
        case "song":
            if let artist = item.artist?.first {
                if let album = item.album {
                    return "\(artist) — \(album)"
                }
                return artist
            }
            return item.album
        case "movie":
            if let year = item.year {
                return String(year)
            }
            return nil
        default:
            return nil
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
                let result = try await client.playPause(playerId: playerId)
                await MainActor.run {
                    appState?.nowPlaying?.speed = result.speed
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

    // MARK: - Haptics

    private func triggerHaptic(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        guard hapticFeedback else { return }
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.impactOccurred()
    }
}
