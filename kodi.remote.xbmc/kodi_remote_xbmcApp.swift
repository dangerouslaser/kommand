//
//  kodi_remote_xbmcApp.swift
//  kodi.remote.xbmc
//

import SwiftUI

@main
struct kodi_remote_xbmcApp: App {
    init() {
        // Auto-unlock Pro features on TestFlight and Debug builds
        AppEnvironment.configureProUnlock()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
