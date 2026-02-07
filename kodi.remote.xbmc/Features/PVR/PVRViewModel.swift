//
//  PVRViewModel.swift
//  kodi.remote.xbmc
//

import Foundation
import os

@Observable
final class PVRViewModel {
    private var appState: AppState?
    private var client = KodiClient() // Replaced in configure() with shared instance

    // PVR availability
    var isPVRAvailable = false
    var isRecording = false
    var isScanning = false

    // Channel groups
    var tvChannelGroups: [PVRChannelGroup] = []
    var radioChannelGroups: [PVRChannelGroup] = []
    var selectedTVGroupId: Int?
    var selectedRadioGroupId: Int?

    // Channels
    var tvChannels: [PVRChannel] = []
    var radioChannels: [PVRChannel] = []

    // Recordings and timers
    var recordings: [PVRRecording] = []
    var timers: [PVRTimer] = []

    // EPG
    var epgBroadcasts: [Int: [EPGEvent]] = [:] // channelId -> broadcasts

    // Loading states
    var isLoadingChannels = false
    var isLoadingRecordings = false
    var isLoadingTimers = false
    var isCheckingAvailability = false

    // Errors
    var error: String?

    func configure(appState: AppState) {
        self.appState = appState
        self.client = appState.client
        if let host = appState.currentHost {
            Task {
                await client.configure(with: host)
            }
        }
    }

    // MARK: - PVR Availability

    func checkPVRAvailability() async {
        await MainActor.run {
            isCheckingAvailability = true
            error = nil
        }

        do {
            let properties = try await client.getPVRProperties()
            await MainActor.run {
                isPVRAvailable = properties.available ?? false
                isRecording = properties.recording ?? false
                isScanning = properties.scanning ?? false
                isCheckingAvailability = false
            }
        } catch {
            await MainActor.run {
                isPVRAvailable = false
                isCheckingAvailability = false
                self.error = "PVR not available"
            }
        }
    }

    // MARK: - Channel Groups

    func loadChannelGroups() async {
        do {
            async let tvGroups = client.getTVChannelGroups()
            async let radioGroups = client.getRadioChannelGroups()

            let (tv, radio) = try await (tvGroups, radioGroups)

            await MainActor.run {
                tvChannelGroups = tv.channelgroups ?? []
                radioChannelGroups = radio.channelgroups ?? []

                // Select first group by default
                if selectedTVGroupId == nil, let firstTV = tvChannelGroups.first {
                    selectedTVGroupId = firstTV.id
                }
                if selectedRadioGroupId == nil, let firstRadio = radioChannelGroups.first {
                    selectedRadioGroupId = firstRadio.id
                }
            }
        } catch {
            await MainActor.run {
                self.error = error.localizedDescription
            }
        }
    }

    // MARK: - TV Channels

    func loadTVChannels() async {
        guard let groupId = selectedTVGroupId else { return }

        await MainActor.run {
            isLoadingChannels = true
        }

        do {
            let response = try await client.getChannels(groupId: groupId)
            await MainActor.run {
                tvChannels = response.channels ?? []
                isLoadingChannels = false
            }
        } catch {
            await MainActor.run {
                isLoadingChannels = false
                self.error = error.localizedDescription
            }
        }
    }

    // MARK: - Radio Channels

    func loadRadioChannels() async {
        guard let groupId = selectedRadioGroupId else { return }

        await MainActor.run {
            isLoadingChannels = true
        }

        do {
            let response = try await client.getChannels(groupId: groupId)
            await MainActor.run {
                radioChannels = response.channels ?? []
                isLoadingChannels = false
            }
        } catch {
            await MainActor.run {
                isLoadingChannels = false
                self.error = error.localizedDescription
            }
        }
    }

    // MARK: - Recordings

    func loadRecordings() async {
        await MainActor.run {
            isLoadingRecordings = true
        }

        do {
            let response = try await client.getRecordings()
            await MainActor.run {
                recordings = (response.recordings ?? []).filter { !($0.isdeleted ?? false) }
                isLoadingRecordings = false
            }
        } catch {
            await MainActor.run {
                isLoadingRecordings = false
                self.error = error.localizedDescription
            }
        }
    }

    // MARK: - Timers

    func loadTimers() async {
        await MainActor.run {
            isLoadingTimers = true
        }

        do {
            let response = try await client.getTimers()
            await MainActor.run {
                timers = response.timers ?? []
                isLoadingTimers = false
            }
        } catch {
            await MainActor.run {
                isLoadingTimers = false
                self.error = error.localizedDescription
            }
        }
    }

    // MARK: - Playback

    func playChannel(_ channel: PVRChannel) async {
        do {
            try await client.playChannel(channelId: channel.id)
            HapticService.notification(.success)
        } catch {
            Logger.playback.error("Failed to play channel: \(error.localizedDescription)")
            HapticService.notification(.error)
        }
    }

    func playRecording(_ recording: PVRRecording, resume: Bool = false) async {
        do {
            try await client.playRecording(recordingId: recording.id, resume: resume)
            HapticService.notification(.success)
        } catch {
            Logger.playback.error("Failed to play recording: \(error.localizedDescription)")
            HapticService.notification(.error)
        }
    }

    // MARK: - Recording Management

    func deleteRecording(_ recording: PVRRecording) async {
        do {
            try await client.deleteRecording(recordingId: recording.id)
            await loadRecordings()
            HapticService.notification(.success)
        } catch {
            Logger.networking.error("Failed to delete recording: \(error.localizedDescription)")
            HapticService.notification(.error)
        }
    }

    func recordChannel(_ channel: PVRChannel) async {
        do {
            try await client.recordNow(channelId: channel.id)
            await checkPVRAvailability()
            HapticService.notification(.success)
        } catch {
            Logger.networking.error("Failed to record channel: \(error.localizedDescription)")
            HapticService.notification(.error)
        }
    }

    // MARK: - Timer Management

    func deleteTimer(_ timer: PVRTimer) async {
        do {
            try await client.deleteTimer(timerId: timer.id)
            await loadTimers()
            HapticService.notification(.success)
        } catch {
            Logger.networking.error("Failed to delete timer: \(error.localizedDescription)")
            HapticService.notification(.error)
        }
    }

    func scheduleRecording(broadcastId: Int) async {
        do {
            try await client.addTimer(broadcastId: broadcastId)
            await loadTimers()
            HapticService.notification(.success)
        } catch {
            Logger.networking.error("Failed to schedule recording: \(error.localizedDescription)")
            HapticService.notification(.error)
        }
    }

    // MARK: - Refresh

    func refresh() async {
        await checkPVRAvailability()
        if isPVRAvailable {
            await loadChannelGroups()
            await loadTVChannels()
            await loadRecordings()
            await loadTimers()
        }
    }
}
