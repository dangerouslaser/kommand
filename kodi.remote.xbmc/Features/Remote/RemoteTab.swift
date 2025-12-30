//
//  RemoteTab.swift
//  kodi.remote.xbmc
//

import SwiftUI

struct RemoteTab: View {
    @Environment(AppState.self) private var appState
    @State private var viewModel = RemoteViewModel()
    @AppStorage("showVolumeSlider") private var showVolumeSlider = false
    @State private var showingTextInput = false
    @State private var textInput = ""

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

                    // Volume Slider (optional)
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
            .navigationTitle("Remote")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    ConnectionStatusBadge(state: appState.connectionState)
                }
            }
            .alert("Send Text to Kodi", isPresented: $showingTextInput) {
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
                Text("Text will be sent to the active input field in Kodi")
            }
        }
        .task {
            viewModel.configure(appState: appState)
            await viewModel.startPolling()
        }
    }
}

// MARK: - Nothing Playing Card

struct NothingPlayingCard: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "play.tv")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            Text("Nothing Playing")
                .font(.headline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 120)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
}

#Preview {
    RemoteTab()
        .environment(AppState())
}
