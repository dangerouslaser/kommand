//
//  RemoteTab.swift
//  kodi.remote.xbmc
//

import SwiftUI

struct RemoteTab: View {
    @Environment(AppState.self) private var appState
    @Environment(\.scenePhase) private var scenePhase
    @State private var viewModel = RemoteViewModel()
    @AppStorage("showVolumeSlider") private var showVolumeSlider = false
    @AppStorage("useVolumeButtons") private var useVolumeButtons = true
    @State private var showingTextInput = false
    @State private var textInput = ""
    @State private var volumeButtonHandler = VolumeButtonHandler()

    // Power Menu Settings
    @AppStorage("powerMenuRestartKodi") private var powerMenuRestartKodi = true
    @AppStorage("powerMenuSuspend") private var powerMenuSuspend = false
    @AppStorage("powerMenuReboot") private var powerMenuReboot = false
    @AppStorage("powerMenuShutdown") private var powerMenuShutdown = false

    // Power Menu Confirmation States
    @State private var showRestartKodiConfirm = false
    @State private var showSuspendConfirm = false
    @State private var showRebootConfirm = false
    @State private var showShutdownConfirm = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // Now Playing Card
                    if let nowPlaying = appState.nowPlaying, !nowPlaying.title.isEmpty {
                        NowPlayingCard(
                            item: nowPlaying,
                            onAudioStreamChange: viewModel.setAudioStream,
                            onSubtitleChange: viewModel.setSubtitle,
                            onSeek: viewModel.seekToPercentage
                        )
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
            .themedScrollBackground()
            .toolbar {
                if appState.isCoreELEC {
                    ToolbarItem(placement: .topBarTrailing) {
                        Menu {
                            if powerMenuRestartKodi {
                                Button {
                                    showRestartKodiConfirm = true
                                } label: {
                                    Label("Restart Kodi", systemImage: "arrow.clockwise")
                                }
                            }
                            if powerMenuSuspend {
                                Button {
                                    showSuspendConfirm = true
                                } label: {
                                    Label("Suspend Device", systemImage: "moon.fill")
                                }
                            }
                            if powerMenuReboot {
                                Button {
                                    showRebootConfirm = true
                                } label: {
                                    Label("Reboot Device", systemImage: "arrow.triangle.2.circlepath")
                                }
                            }
                            if powerMenuShutdown {
                                Button(role: .destructive) {
                                    showShutdownConfirm = true
                                } label: {
                                    Label("Shutdown Device", systemImage: "power")
                                }
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
            .confirmationDialog("Restart Kodi?", isPresented: $showRestartKodiConfirm, titleVisibility: .visible) {
                Button("Restart") { viewModel.restartKodi() }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Kodi will restart. Any playback will be interrupted.")
            }
            .confirmationDialog("Suspend Device?", isPresented: $showSuspendConfirm, titleVisibility: .visible) {
                Button("Suspend") { viewModel.suspendDevice() }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("The device will enter sleep mode. Wake it with CEC or Wake-on-LAN.")
            }
            .confirmationDialog("Reboot Device?", isPresented: $showRebootConfirm, titleVisibility: .visible) {
                Button("Reboot", role: .destructive) { viewModel.rebootDevice() }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("The device will restart. This may take a minute.")
            }
            .confirmationDialog("Shutdown Device?", isPresented: $showShutdownConfirm, titleVisibility: .visible) {
                Button("Shutdown", role: .destructive) { viewModel.shutdownDevice() }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("The device will power off completely.")
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
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                // Refresh state when returning from background (e.g., after Live Activity action)
                viewModel.refreshNowPlaying()
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
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
    }
}

#Preview {
    RemoteTab()
        .environment(AppState())
}
