//
//  LibrarySettingsView.swift
//  kodi.remote.xbmc
//

import SwiftUI

struct LibrarySettingsView: View {
    @AppStorage("showMoviesTab") private var showMoviesTab = true
    @AppStorage("showTVShowsTab") private var showTVShowsTab = true
    @AppStorage("showMusicTab") private var showMusicTab = true
    @AppStorage("showPVRTab") private var showPVRTab = false

    var body: some View {
        Form {
            Section {
                Toggle(isOn: $showMoviesTab) {
                    Label("Movies", systemImage: "film")
                }

                Toggle(isOn: $showTVShowsTab) {
                    Label("TV Shows", systemImage: "tv")
                }

                Toggle(isOn: $showMusicTab) {
                    Label("Music", systemImage: "music.note")
                }

                Toggle(isOn: $showPVRTab) {
                    Label("Live TV & Radio", systemImage: "play.tv")
                }
            } header: {
                Text("Show in Tab Bar")
            } footer: {
                Text("Choose which media libraries appear in the main navigation. The Remote tab is always visible. Live TV requires a PVR backend to be configured in Kodi.")
            }
        }
        .navigationTitle("Media Types")
        .navigationBarTitleDisplayMode(.inline)
        .themedScrollBackground()
    }
}
