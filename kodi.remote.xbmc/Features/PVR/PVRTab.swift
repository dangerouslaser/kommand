//
//  PVRTab.swift
//  kodi.remote.xbmc
//

import SwiftUI

enum PVRSection: String, CaseIterable {
    case tv = "Live TV"
    case radio = "Radio"
    case recordings = "Recordings"
    case timers = "Timers"
}

struct PVRTab: View {
    @Environment(AppState.self) private var appState
    @State private var viewModel = PVRViewModel()
    @State private var selectedSection: PVRSection = .tv
    @State private var searchText = ""

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isCheckingAvailability {
                    VStack(spacing: 12) {
                        ProgressView()
                        Text("Checking PVR...")
                            .foregroundStyle(.secondary)
                    }
                } else if !viewModel.isPVRAvailable {
                    ContentUnavailableView {
                        Label("PVR Not Available", systemImage: "tv.slash")
                    } description: {
                        Text("No PVR backend is configured or available on this Kodi installation.")
                    } actions: {
                        Button("Retry") {
                            Task { await viewModel.checkPVRAvailability() }
                        }
                    }
                } else {
                    VStack(spacing: 0) {
                        // Section Picker
                        Picker("Section", selection: $selectedSection) {
                            ForEach(PVRSection.allCases, id: \.self) { section in
                                Text(section.rawValue).tag(section)
                            }
                        }
                        .pickerStyle(.segmented)
                        .padding()

                        // Content
                        Group {
                            switch selectedSection {
                            case .tv:
                                tvChannelsView
                            case .radio:
                                radioChannelsView
                            case .recordings:
                                recordingsView
                            case .timers:
                                timersView
                            }
                        }
                    }
                }
            }
            .navigationTitle("Live TV")
            .searchable(text: $searchText, prompt: searchPrompt)
            .refreshable {
                await viewModel.refresh()
            }
            .toolbar {
                if viewModel.isRecording {
                    ToolbarItem(placement: .topBarTrailing) {
                        Image(systemName: "record.circle")
                            .foregroundStyle(.red)
                            .symbolEffect(.pulse)
                            .accessibilityLabel("Recording in progress")
                    }
                }
            }
            .themedBackground()
        }
        .task {
            viewModel.configure(appState: appState)
            await viewModel.checkPVRAvailability()
            if viewModel.isPVRAvailable {
                await viewModel.loadChannelGroups()
                await viewModel.loadTVChannels()
            }
        }
        .onChange(of: selectedSection) { _, newSection in
            Task {
                switch newSection {
                case .tv:
                    await viewModel.loadTVChannels()
                case .radio:
                    await viewModel.loadRadioChannels()
                case .recordings:
                    await viewModel.loadRecordings()
                case .timers:
                    await viewModel.loadTimers()
                }
            }
        }
    }

    private var searchPrompt: String {
        switch selectedSection {
        case .tv: return "Search TV channels"
        case .radio: return "Search radio stations"
        case .recordings: return "Search recordings"
        case .timers: return "Search timers"
        }
    }

    // MARK: - TV Channels View

    private var tvChannelsView: some View {
        Group {
            if viewModel.isLoadingChannels && viewModel.tvChannels.isEmpty {
                VStack(spacing: 12) {
                    ProgressView()
                    Text("Loading Channels...")
                        .foregroundStyle(.secondary)
                }
            } else if filteredTVChannels.isEmpty {
                if searchText.isEmpty {
                    ContentUnavailableView {
                        Label("No Channels", systemImage: "tv")
                    } description: {
                        Text("No TV channels found")
                    }
                } else {
                    ContentUnavailableView.search(text: searchText)
                }
            } else {
                List {
                    ForEach(filteredTVChannels) { channel in
                        ChannelRow(channel: channel, host: appState.currentHost) {
                            Task { await viewModel.playChannel(channel) }
                        } onRecord: {
                            Task { await viewModel.recordChannel(channel) }
                        }
                        .listRowBackground(Color.clear)
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
    }

    private var filteredTVChannels: [PVRChannel] {
        if searchText.isEmpty {
            return viewModel.tvChannels
        }
        return viewModel.tvChannels.filter {
            $0.label.localizedCaseInsensitiveContains(searchText)
        }
    }

    // MARK: - Radio Channels View

    private var radioChannelsView: some View {
        Group {
            if viewModel.isLoadingChannels && viewModel.radioChannels.isEmpty {
                VStack(spacing: 12) {
                    ProgressView()
                    Text("Loading Stations...")
                        .foregroundStyle(.secondary)
                }
            } else if filteredRadioChannels.isEmpty {
                if searchText.isEmpty {
                    ContentUnavailableView {
                        Label("No Stations", systemImage: "radio")
                    } description: {
                        Text("No radio stations found")
                    }
                } else {
                    ContentUnavailableView.search(text: searchText)
                }
            } else {
                List {
                    ForEach(filteredRadioChannels) { channel in
                        ChannelRow(channel: channel, host: appState.currentHost) {
                            Task { await viewModel.playChannel(channel) }
                        } onRecord: {
                            Task { await viewModel.recordChannel(channel) }
                        }
                        .listRowBackground(Color.clear)
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
    }

    private var filteredRadioChannels: [PVRChannel] {
        if searchText.isEmpty {
            return viewModel.radioChannels
        }
        return viewModel.radioChannels.filter {
            $0.label.localizedCaseInsensitiveContains(searchText)
        }
    }

    // MARK: - Recordings View

    private var recordingsView: some View {
        Group {
            if viewModel.isLoadingRecordings && viewModel.recordings.isEmpty {
                VStack(spacing: 12) {
                    ProgressView()
                    Text("Loading Recordings...")
                        .foregroundStyle(.secondary)
                }
            } else if filteredRecordings.isEmpty {
                if searchText.isEmpty {
                    ContentUnavailableView {
                        Label("No Recordings", systemImage: "video.badge.checkmark")
                    } description: {
                        Text("Your recorded programs will appear here")
                    }
                } else {
                    ContentUnavailableView.search(text: searchText)
                }
            } else {
                List {
                    ForEach(filteredRecordings) { recording in
                        RecordingRow(recording: recording, host: appState.currentHost) {
                            Task { await viewModel.playRecording(recording) }
                        } onResume: {
                            Task { await viewModel.playRecording(recording, resume: true) }
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                Task { await viewModel.deleteRecording(recording) }
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                        .listRowBackground(Color.clear)
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
    }

    private var filteredRecordings: [PVRRecording] {
        if searchText.isEmpty {
            return viewModel.recordings
        }
        return viewModel.recordings.filter {
            $0.title.localizedCaseInsensitiveContains(searchText) ||
            ($0.channel?.localizedCaseInsensitiveContains(searchText) ?? false)
        }
    }

    // MARK: - Timers View

    private var timersView: some View {
        Group {
            if viewModel.isLoadingTimers && viewModel.timers.isEmpty {
                VStack(spacing: 12) {
                    ProgressView()
                    Text("Loading Timers...")
                        .foregroundStyle(.secondary)
                }
            } else if filteredTimers.isEmpty {
                if searchText.isEmpty {
                    ContentUnavailableView {
                        Label("No Timers", systemImage: "clock.badge.checkmark")
                    } description: {
                        Text("Scheduled recordings will appear here")
                    }
                } else {
                    ContentUnavailableView.search(text: searchText)
                }
            } else {
                List {
                    ForEach(filteredTimers) { timer in
                        TimerRow(timer: timer)
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                if !(timer.isreadonly ?? false) {
                                    Button(role: .destructive) {
                                        Task { await viewModel.deleteTimer(timer) }
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                            }
                            .listRowBackground(Color.clear)
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
    }

    private var filteredTimers: [PVRTimer] {
        if searchText.isEmpty {
            return viewModel.timers
        }
        return viewModel.timers.filter {
            $0.title.localizedCaseInsensitiveContains(searchText)
        }
    }
}

// MARK: - Channel Row

struct ChannelRow: View {
    let channel: PVRChannel
    let host: KodiHost?
    let onPlay: () -> Void
    let onRecord: () -> Void

    var body: some View {
        Button(action: onPlay) {
            HStack(spacing: 12) {
                // Channel logo
                AsyncArtworkImage(path: channel.thumbnail, host: host)
                    .frame(width: 50, height: 50)
                    .clipShape(RoundedRectangle(cornerRadius: 6))

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        if let number = channel.channelNumber {
                            Text(number)
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundStyle(.secondary)
                        }
                        Text(channel.label)
                            .font(.headline)
                    }

                    // Now playing
                    if let now = channel.broadcastnow {
                        Text(now.title)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)

                        if let progress = now.progresspercentage {
                            ProgressView(value: progress / 100)
                                .tint(.blue)
                                .accessibilityLabel("Program progress")
                                .accessibilityValue("\(Int(progress)) percent")
                        }
                    }
                }

                Spacer()

                // Recording indicator
                if channel.isrecording ?? false {
                    Image(systemName: "record.circle")
                        .foregroundStyle(.red)
                        .accessibilityLabel("Recording")
                }
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button {
                onPlay()
            } label: {
                Label("Watch", systemImage: "play.fill")
            }

            Button {
                onRecord()
            } label: {
                Label("Record", systemImage: "record.circle")
            }
        }
    }
}

// MARK: - Recording Row

struct RecordingRow: View {
    let recording: PVRRecording
    let host: KodiHost?
    let onPlay: () -> Void
    let onResume: () -> Void

    var body: some View {
        Button(action: recording.hasResume ? onResume : onPlay) {
            HStack(spacing: 12) {
                // Thumbnail
                AsyncArtworkImage(path: recording.artworkPath, host: host)
                    .frame(width: 80, height: 60)
                    .clipShape(RoundedRectangle(cornerRadius: 6))

                VStack(alignment: .leading, spacing: 4) {
                    Text(recording.title)
                        .font(.headline)
                        .lineLimit(2)

                    HStack(spacing: 8) {
                        if let channel = recording.channel {
                            Text(channel)
                        }
                        if let date = recording.formattedDate {
                            Text("•")
                            Text(date)
                        }
                        if let runtime = recording.formattedRuntime {
                            Text("•")
                            Text(runtime)
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)

                    if recording.hasResume {
                        ProgressView(value: recording.resume?.progress ?? 0)
                            .tint(.blue)
                            .accessibilityLabel("Watched progress")
                            .accessibilityValue("\(Int((recording.resume?.progress ?? 0) * 100)) percent")
                    }
                }

                Spacer()

                if recording.isWatched {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .accessibilityLabel("Watched")
                }
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
        .contextMenu {
            if recording.hasResume {
                Button {
                    onResume()
                } label: {
                    Label("Resume", systemImage: "play.fill")
                }

                Button {
                    onPlay()
                } label: {
                    Label("Start Over", systemImage: "arrow.counterclockwise")
                }
            } else {
                Button {
                    onPlay()
                } label: {
                    Label("Play", systemImage: "play.fill")
                }
            }
        }
    }
}

// MARK: - Timer Row

struct TimerRow: View {
    let timer: PVRTimer

    var body: some View {
        HStack(spacing: 12) {
            // Status icon
            Image(systemName: timerIcon)
                .font(.title2)
                .foregroundStyle(timerColor)
                .frame(width: 40)

            VStack(alignment: .leading, spacing: 4) {
                Text(timer.title)
                    .font(.headline)
                    .lineLimit(2)

                if let time = timer.formattedTime {
                    Text(time)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Text(timer.stateText)
                    .font(.caption)
                    .foregroundStyle(timerColor)
            }

            Spacer()

            if timer.isActive {
                Image(systemName: "record.circle")
                    .foregroundStyle(.red)
                    .symbolEffect(.pulse)
                    .accessibilityLabel("Recording active")
            }
        }
        .padding(.vertical, 4)
    }

    private var timerIcon: String {
        if timer.isActive {
            return "record.circle.fill"
        } else if timer.isScheduled {
            return "clock.fill"
        } else {
            return "clock"
        }
    }

    private var timerColor: Color {
        switch timer.state?.lowercased() {
        case "recording": return .red
        case "scheduled": return .blue
        case "completed": return .green
        case "conflict_ok", "conflict_notok": return .orange
        case "error": return .red
        case "disabled": return .secondary
        default: return .secondary
        }
    }
}

#Preview {
    PVRTab()
        .environment(AppState())
}
