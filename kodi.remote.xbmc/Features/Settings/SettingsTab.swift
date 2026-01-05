//
//  SettingsTab.swift
//  kodi.remote.xbmc
//

import SwiftUI

struct SettingsTab: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        NavigationStack {
            List {
                Section("Connections") {
                    NavigationLink {
                        HostsListView()
                    } label: {
                        Label {
                            HStack {
                                Text("Kodi Hosts")
                                Spacer()
                                if let host = appState.currentHost {
                                    Text(host.name)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        } icon: {
                            Image(systemName: "server.rack")
                        }
                    }

                    if appState.currentHost != nil {
                        HStack {
                            Label("Status", systemImage: "circle.fill")
                                .foregroundStyle(appState.connectionState.statusColor)
                            Spacer()
                            if appState.isCoreELEC && appState.connectionState == .connected {
                                Text("CoreELEC")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(.blue.opacity(0.2), in: RoundedRectangle(cornerRadius: 6))
                                    .foregroundStyle(.blue)
                            }
                            Text(appState.connectionState.statusText)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                if appState.connectionState == .connected {
                    Section("Kodi") {
                        NavigationLink {
                            KodiSettingsView()
                        } label: {
                            Label("Kodi Settings", systemImage: "slider.horizontal.3")
                        }
                    }
                }

                Section("Appearance") {
                    NavigationLink {
                        AppearanceSettingsView()
                    } label: {
                        Label("Theme & Display", systemImage: "paintbrush")
                    }
                }

                Section("Library") {
                    NavigationLink {
                        LibrarySettingsView()
                    } label: {
                        Label("Media Types", systemImage: "square.stack")
                    }
                }

                Section("Behavior") {
                    NavigationLink {
                        BehaviorSettingsView()
                    } label: {
                        Label("Controls & Gestures", systemImage: "hand.tap")
                    }
                }

                if appState.isCoreELEC {
                    Section("CoreELEC") {
                        NavigationLink {
                            CoreELECSettingsView()
                        } label: {
                            Label("System Settings", systemImage: "cpu")
                        }
                    }
                }

                Section("About") {
                    NavigationLink {
                        AboutView()
                    } label: {
                        Label("About Kommand", systemImage: "info.circle")
                    }
                }
            }
            .navigationTitle("Settings")
            .themedScrollBackground()
        }
    }
}

#Preview {
    SettingsTab()
        .environment(AppState())
}
