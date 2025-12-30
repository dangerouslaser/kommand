//
//  RemoteTab.swift
//  kodi.remote.xbmc
//

import SwiftUI

struct RemoteTab: View {
    @Environment(AppState.self) private var appState
    @State private var viewModel = RemoteViewModel()
    @AppStorage("showVolumeSlider") private var showVolumeSlider = false
    @AppStorage("useVolumeButtons") private var useVolumeButtons = true
    @State private var showingTextInput = false
    @State private var textInput = ""
    @State private var volumeButtonHandler = VolumeButtonHandler()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Now Playing Card
                    if let nowPlaying = appState.nowPlaying, !nowPlaying.title.isEmpty {
                        NowPlayingCard(item: nowPlaying)
                            .padding(.horizontal)
                    } else {
                        NothingPlayingCard()
                            .padding(.horizontal)
                    }

                    // Navigation D-Pad
                    NavigationPad(onInput: viewModel.sendInput)
                        .padding(.horizontal)

                    // Playback Controls
                    PlaybackControls(
                        isPlaying: appState.nowPlaying?.isPlaying ?? false,
                        onPlayPause: viewModel.togglePlayPause,
                        onStop: viewModel.stop,
                        onSkipBack: viewModel.skipPrevious,
                        onSkipForward: viewModel.skipNext,
                        onSeekBack: viewModel.seekBackward,
                        onSeekForward: viewModel.seekForward
                    )
                    .padding(.horizontal)

                    // Quick Actions
                    QuickActionsBar(
                        onHome: { viewModel.sendInput(.home) },
                        onBack: { viewModel.sendInput(.back) },
                        onInfo: { viewModel.sendInput(.info) },
                        onOSD: { viewModel.sendInput(.osd) },
                        onKeyboard: { showingTextInput = true }
                    )
                    .padding(.horizontal)

                    // CEC Volume Control (for CoreELEC - controls TV/AVR)
                    if appState.isCoreELEC {
                        CECVolumeControl(
                            onVolumeUp: viewModel.cecVolumeUp,
                            onVolumeDown: viewModel.cecVolumeDown,
                            onMute: viewModel.cecMute
                        )
                        .padding(.horizontal)
                    }

                    // Kodi Volume Slider (optional)
                    if showVolumeSlider {
                        VolumeSlider(
                            volume: Binding(
                                get: { appState.volume },
                                set: { viewModel.setVolume($0) }
                            ),
                            isMuted: appState.isMuted,
                            onMuteToggle: viewModel.toggleMute
                        )
                        .padding(.horizontal)
                    }

                    Spacer(minLength: 20)
                }
                .padding(.top)
            }
            .background {
                // Hidden volume view to suppress system volume HUD
                if appState.isCoreELEC && useVolumeButtons {
                    HiddenVolumeView()
                        .frame(width: 0, height: 0)
                }
            }
            .toolbar {
                if appState.isCoreELEC {
                    ToolbarItem(placement: .topBarTrailing) {
                        Menu {
                            Button {
                                viewModel.cecWakeUp()
                            } label: {
                                Label("Wake Up TV", systemImage: "power.circle")
                            }
                            Button(role: .destructive) {
                                viewModel.cecStandby()
                            } label: {
                                Label("Turn Off TV & AVR", systemImage: "power")
                            }
                        } label: {
                            Image(systemName: "power")
                        }
                    }
                }
            }
            .alert("Send Text", isPresented: $showingTextInput) {
                TextField("Enter text", text: $textInput)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                Button("Send") {
                    if !textInput.isEmpty {
                        viewModel.sendText(textInput)
                        textInput = ""
                    }
                }
                Button("Cancel", role: .cancel) {
                    textInput = ""
                }
            } message: {
                Text("Text will be sent to the active input field")
            }
        }
        .task {
            viewModel.configure(appState: appState)
            await viewModel.startPolling()
        }
        .onAppear {
            setupVolumeButtonHandler()
        }
        .onDisappear {
            volumeButtonHandler.stop()
        }
        .onChange(of: appState.isCoreELEC) { _, isCoreELEC in
            if isCoreELEC && useVolumeButtons {
                setupVolumeButtonHandler()
            } else {
                volumeButtonHandler.stop()
            }
        }
    }

    private func setupVolumeButtonHandler() {
        guard appState.isCoreELEC && useVolumeButtons else { return }

        volumeButtonHandler.onVolumeUp = { [viewModel] in
            viewModel.cecVolumeUp()
        }
        volumeButtonHandler.onVolumeDown = { [viewModel] in
            viewModel.cecVolumeDown()
        }
        volumeButtonHandler.start()
    }
}

// MARK: - Nothing Playing Card

struct NothingPlayingCard: View {
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "play.slash")
                .font(.body)
                .foregroundStyle(.tertiary)

            Text("Nothing Playing")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
    }
}

#Preview {
    RemoteTab()
        .environment(AppState())
}
