//
//  PowerSettingsView.swift
//  kodi.remote.xbmc
//

import SwiftUI

struct PowerSettingsView: View {
    @AppStorage(AppStorageKeys.powerPrimaryAction) private var primaryActionRaw: String = PowerAction.systemShutdown.rawValue
    @AppStorage(AppStorageKeys.powerEnabledActions) private var enabledActionsRaw: String = "quitKodi,systemShutdown"
    @AppStorage(AppStorageKeys.powerConfirmPrimary) private var confirmPrimary = true

    var body: some View {
        Form {
            Section {
                Picker("Action", selection: $primaryActionRaw) {
                    ForEach(PowerAction.allCases) { action in
                        Label(action.displayName, systemImage: action.systemImage)
                            .tag(action.rawValue)
                    }
                }
            } header: {
                Text("Primary Action")
            } footer: {
                Text("Tap the power button to execute this action.")
            }

            Section {
                Toggle("Confirm Before Executing", isOn: $confirmPrimary)
            } footer: {
                Text("Show a confirmation dialog before the primary action runs.")
            }

            Section {
                ForEach(PowerAction.allCases) { action in
                    if action.rawValue != primaryActionRaw {
                        Toggle(isOn: toggleBinding(for: action)) {
                            Label(action.displayName, systemImage: action.systemImage)
                        }
                    }
                }
            } header: {
                Text("Long-Press Menu")
            } footer: {
                Text("Long-press the power button to see these additional actions. Each will ask for confirmation before executing.")
            }
        }
        .navigationTitle("Power Button")
    }

    private func toggleBinding(for action: PowerAction) -> Binding<Bool> {
        Binding(
            get: {
                enabledActions.contains(action)
            },
            set: { enabled in
                var actions = enabledActions
                if enabled {
                    actions.insert(action)
                } else {
                    actions.remove(action)
                }
                enabledActionsRaw = actions.map(\.rawValue).joined(separator: ",")
            }
        )
    }

    private var enabledActions: Set<PowerAction> {
        Set(enabledActionsRaw.split(separator: ",").compactMap { PowerAction(rawValue: String($0)) })
    }
}

#Preview {
    NavigationStack {
        PowerSettingsView()
    }
}
