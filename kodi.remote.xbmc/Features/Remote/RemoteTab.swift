//
//  RemoteTab.swift
//  kodi.remote.xbmc
//

import SwiftUI

struct RemoteTab: View {
    @Environment(AppState.self) private var appState
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var viewModel = RemoteViewModel()
    @AppStorage(AppStorageKeys.showVolumeSlider) private var showVolumeSlider = false
    @AppStorage(AppStorageKeys.useVolumeButtons) private var useVolumeButtons = true
    @State private var showingTextInput = false
    @State private var textInput = ""
    @State private var volumeButtonHandler = VolumeButtonHandler()

    private var isIPad: Bool { horizontalSizeClass == .regular }

    // Power Button
    @AppStorage(AppStorageKeys.powerPrimaryAction) private var primaryActionRaw: String = PowerAction.systemShutdown.rawValue
    @AppStorage(AppStorageKeys.powerEnabledActions) private var enabledActionsRaw: String = "quitKodi,systemShutdown"
    @AppStorage(AppStorageKeys.powerConfirmPrimary) private var confirmPrimary = true
    @State private var confirmingAction: PowerAction?

    var body: some View {
        NavigationStack {
            remoteLayout
            .background {
                // Hidden volume view to suppress system volume HUD
                if appState.isCoreELEC && useVolumeButtons {
                    HiddenVolumeView()
                        .frame(width: 0, height: 0)
                }
            }
            .themedScrollBackground()
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        if confirmPrimary {
                            confirmingAction = primaryAction
                        } else {
                            viewModel.executePowerAction(primaryAction)
                        }
                    } label: {
                        Image(systemName: "power")
                    }
                    .contextMenu {
                        ForEach(enabledSecondaryActions) { action in
                            Button(role: action.isDestructive ? .destructive : nil) {
                                confirmingAction = action
                            } label: {
                                Label(action.displayName, systemImage: action.systemImage)
                            }
                        }
                    }
                    .accessibilityLabel("Power: \(primaryAction.displayName)")
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
            .confirmationDialog(
                confirmingAction?.confirmationTitle ?? "",
                isPresented: Binding(
                    get: { confirmingAction != nil },
                    set: { if !$0 { confirmingAction = nil } }
                ),
                titleVisibility: .visible
            ) {
                if let action = confirmingAction {
                    Button(action.confirmButtonLabel, role: action.isDestructive ? .destructive : nil) {
                        viewModel.executePowerAction(action)
                        confirmingAction = nil
                    }
                    Button("Cancel", role: .cancel) { confirmingAction = nil }
                }
            } message: {
                if let action = confirmingAction {
                    Text(action.confirmationMessage)
                }
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

    // MARK: - Power Helpers

    private var primaryAction: PowerAction {
        PowerAction(rawValue: primaryActionRaw) ?? .systemShutdown
    }

    private var enabledSecondaryActions: [PowerAction] {
        enabledActionsRaw.split(separator: ",")
            .compactMap { PowerAction(rawValue: String($0)) }
            .filter { $0 != primaryAction }
    }

    // MARK: - Remote Layout

    private var remoteLayout: some View {
        VStack(spacing: 16) {
            // Now Playing Card — fills remaining space
            if let nowPlaying = appState.nowPlaying, !nowPlaying.title.isEmpty {
                NowPlayingCard(
                    item: nowPlaying,
                    onAudioStreamChange: viewModel.setAudioStream,
                    onSubtitleChange: viewModel.setSubtitle,
                    onSeek: viewModel.seekToPercentage,
                    flexibleHeight: true
                )
                .padding(.horizontal)
            } else {
                NothingPlayingCard()
                    .frame(maxHeight: .infinity)
                    .padding(.horizontal)
            }

            // Controls — natural size at bottom
            remoteControls
        }
        .padding(.top)
        .padding(.bottom)
    }

    // MARK: - Shared Controls

    private var remoteControls: some View {
        VStack(spacing: 16) {
            NavigationPad(onInput: viewModel.sendInput)
                .padding(.horizontal)

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

            QuickActionsBar(
                onHome: { viewModel.sendInput(.home) },
                onBack: { viewModel.sendInput(.back) },
                onInfo: { viewModel.sendInput(.info) },
                onOSD: { viewModel.sendInput(.osd) },
                onKeyboard: { showingTextInput = true }
            )
            .padding(.horizontal)

            if appState.isCoreELEC {
                CECVolumeControl(
                    onVolumeUp: viewModel.cecVolumeUp,
                    onVolumeDown: viewModel.cecVolumeDown,
                    onMute: viewModel.cecMute
                )
                .padding(.horizontal)
            }

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
