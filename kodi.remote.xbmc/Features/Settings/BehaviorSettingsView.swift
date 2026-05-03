//
//  BehaviorSettingsView.swift
//  kodi.remote.xbmc
//

import SwiftUI

struct BehaviorSettingsView: View {
    @AppStorage(AppStorageKeys.hapticFeedback) private var hapticFeedback = true
    @AppStorage(AppStorageKeys.seekInterval) private var seekInterval = 30
    @AppStorage(AppStorageKeys.keepScreenOn) private var keepScreenOn = true
    @AppStorage(AppStorageKeys.showVolumeSlider) private var showVolumeSlider = false
    @AppStorage(AppStorageKeys.liveActivityEnabled) private var liveActivityEnabled = false

    @State private var imageCacheSize: String = "Calculating..."
    @State private var showClearCacheConfirm = false

    var body: some View {
        Form {
            Section("Feedback") {
                Toggle("Haptic Feedback", isOn: $hapticFeedback)
            }

            Section("Playback") {
                Picker("Seek Interval", selection: $seekInterval) {
                    Text("10 seconds").tag(10)
                    Text("30 seconds").tag(30)
                    Text("1 minute").tag(60)
                }
            }

            Section("Remote") {
                Toggle("Show Volume Slider", isOn: $showVolumeSlider)
            }

            Section("Display") {
                Toggle("Keep Screen On", isOn: $keepScreenOn)
            }

            Section {
                Toggle("Live Activity", isOn: Binding(
                    get: { liveActivityEnabled },
                    set: { newValue in
                        liveActivityEnabled = newValue
                        if !newValue {
                            Task {
                                await LiveActivityManager.shared.endAllActivities()
                            }
                        }
                    }
                ))
            } header: {
                Text("Lock Screen")
            } footer: {
                Text("Show playback controls on the Lock Screen and Dynamic Island while media is playing.")
            }

            Section("Power") {
                NavigationLink {
                    PowerSettingsView()
                } label: {
                    Label("Power Button", systemImage: "power")
                }
            }

            Section {
                HStack {
                    Text("Image Cache")
                    Spacer()
                    Text(imageCacheSize)
                        .foregroundStyle(.secondary)
                }

                Button(role: .destructive) {
                    showClearCacheConfirm = true
                } label: {
                    Text("Clear Image Cache")
                }
            } header: {
                Text("Storage")
            } footer: {
                Text("Cached artwork images are stored for 7 days to improve browsing speed.")
            }
        }
        .navigationTitle("Behavior")
        .task {
            await updateCacheSize()
        }
        .confirmationDialog("Clear Image Cache?", isPresented: $showClearCacheConfirm, titleVisibility: .visible) {
            Button("Clear Cache", role: .destructive) {
                Task {
                    await ImageCacheService.shared.clearCache()
                    await updateCacheSize()
                    HapticService.notification(.success)
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This will remove all cached artwork. Images will be re-downloaded as needed.")
        }
        .navigationBarTitleDisplayMode(.inline)
        .themedScrollBackground()
    }

    private func updateCacheSize() async {
        let bytes = await ImageCacheService.shared.diskCacheSize
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        imageCacheSize = formatter.string(fromByteCount: Int64(bytes))
    }
}
