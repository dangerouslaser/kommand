//
//  BehaviorSettingsView.swift
//  kodi.remote.xbmc
//

import SwiftUI

struct BehaviorSettingsView: View {
    @AppStorage("hapticFeedback") private var hapticFeedback = true
    @AppStorage("seekInterval") private var seekInterval = 30
    @AppStorage("keepScreenOn") private var keepScreenOn = true
    @AppStorage("showVolumeSlider") private var showVolumeSlider = false
    @AppStorage("liveActivityEnabled") private var liveActivityEnabled = false
    @AppStorage("isProUnlocked") private var isProUnlocked = false

    // Power Menu Settings
    @AppStorage("powerMenuRestartKodi") private var powerMenuRestartKodi = true
    @AppStorage("powerMenuSuspend") private var powerMenuSuspend = false
    @AppStorage("powerMenuReboot") private var powerMenuReboot = false
    @AppStorage("powerMenuShutdown") private var powerMenuShutdown = false

    @State private var showProPaywall = false

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
                HStack {
                    Toggle("Live Activity", isOn: Binding(
                        get: { liveActivityEnabled },
                        set: { newValue in
                            if newValue && !isProUnlocked {
                                showProPaywall = true
                            } else {
                                liveActivityEnabled = newValue
                                if !newValue {
                                    // End any active Live Activity when disabled
                                    Task {
                                        await LiveActivityManager.shared.endAllActivities()
                                    }
                                }
                            }
                        }
                    ))

                    if !isProUnlocked {
                        Text("PRO")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(.orange, in: RoundedRectangle(cornerRadius: 4))
                    }
                }
            } header: {
                Text("Lock Screen")
            } footer: {
                Text("Show playback controls on the Lock Screen and Dynamic Island while media is playing.")
            }

            Section {
                Toggle("Restart Kodi", isOn: $powerMenuRestartKodi)
                Toggle("Suspend Device", isOn: $powerMenuSuspend)
                Toggle("Reboot Device", isOn: $powerMenuReboot)
                Toggle("Shutdown Device", isOn: $powerMenuShutdown)
            } header: {
                Text("Power Menu")
            } footer: {
                Text("Choose which options appear in the power menu on the Remote tab. The power menu is only visible when connected to a CoreELEC device.")
            }
        }
        .navigationTitle("Behavior")
        .navigationBarTitleDisplayMode(.inline)
        .themedScrollBackground()
        .sheet(isPresented: $showProPaywall) {
            ProPaywallView()
        }
    }
}
