//
//  kodi_remote_xbmcApp.swift
//  kodi.remote.xbmc
//

import SwiftUI

@main
struct kodi_remote_xbmcApp: App {
    init() {
        // Prune image artwork older than 7 days at launch. Done off the main
        // actor so it doesn't delay first paint; the cache directory is small
        // enough that this is fast even with thousands of files.
        Task.detached(priority: .background) {
            await ImageCacheService.shared.pruneExpiredCache()
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
