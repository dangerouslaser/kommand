//
//  LiveActivityManager.swift
//  kodi.remote.xbmc
//
//  Manages Live Activities for Now Playing.
//
//  Implementation follows Apple's guidelines:
//  - Images cached to App Group container as files (not UserDefaults)
//  - ContentState uses boolean flags (hasPoster/hasFanart), not paths
//  - Widget loads images via Data(contentsOf:) + UIImage(data:)
//  - Images resized before saving to avoid widget size issues
//

import ActivityKit
import Foundation
import UIKit

@MainActor
final class LiveActivityManager {
    static let shared = LiveActivityManager()

    private var currentActivity: Activity<NowPlayingAttributes>?

    // Track current artwork paths to avoid re-downloading
    private var currentPosterPath: String?
    private var currentFanartPath: String?

    private init() {}

    /// Check if Live Activities are enabled in settings (Pro feature)
    private var isEnabled: Bool {
        UserDefaults.standard.bool(forKey: "liveActivityEnabled")
    }

    // MARK: - Public API

    /// Start a new Live Activity for the given now playing item
    func startActivity(
        for item: NowPlayingItem,
        host: KodiHost,
        playerId: Int
    ) {
        // Check if feature is enabled in settings
        guard isEnabled else {
            return
        }

        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            return
        }

        Task {
            // End any existing activity first (without clearing shared data)
            await endActivitiesForTransition()

            // Now update shared UserDefaults for widget intents
            // This must happen AFTER ending old activities, not before
            updateSharedData(host: host, playerId: playerId)

            // Cache artwork before starting activity
            await cacheArtwork(for: item, host: host)

            let attributes = NowPlayingAttributes(
                mediaType: item.type.rawValue,
                hostName: host.name
            )

            let state = contentState(from: item)

            do {
                let activity = try Activity.request(
                    attributes: attributes,
                    content: .init(state: state, staleDate: nil),
                    pushType: nil
                )
                self.currentActivity = activity
            } catch {
                // Activity start failed silently
            }
        }
    }

    /// Update the current Live Activity with new playback state
    func updateActivity(for item: NowPlayingItem, host: KodiHost, playerId: Int? = nil) {
        // Check if feature is enabled in settings
        guard isEnabled else {
            // If disabled but activity exists, end it
            if currentActivity != nil {
                Task { await endAllActivities() }
            }
            return
        }

        guard let activity = currentActivity else {
            // If no activity exists but we have playback, start one
            if let playerId = playerId ?? getActivePlayerId() {
                startActivity(for: item, host: host, playerId: playerId)
            }
            return
        }

        // Keep shared data updated in case app was backgrounded
        if let playerId = playerId ?? getActivePlayerId() {
            updateSharedData(host: host, playerId: playerId)
        }

        Task {
            // Cache artwork if it changed
            await cacheArtwork(for: item, host: host)

            var state = contentState(from: item)

            // If we're within cooldown after an intent action, preserve the current isPlaying state
            // This prevents polling from overwriting the correct state set by the intent
            if AppGroupConstants.isWithinIntentCooldown {
                state.isPlaying = activity.content.state.isPlaying
                state.lastUpdated = activity.content.state.lastUpdated
            }

            await activity.update(
                ActivityContent(state: state, staleDate: nil)
            )
        }
    }

    /// End the current Live Activity
    func endActivity() {
        Task {
            await endAllActivities()
        }
    }

    /// Refresh the Live Activity state after a control action
    /// Called by intents after sending commands to Kodi
    func refreshActivityState() async {
        guard let activity = currentActivity else { return }

        // Toggle the isPlaying state optimistically for immediate UI feedback
        // The next polling cycle will correct it if needed
        var updatedState = activity.content.state
        updatedState.isPlaying = !updatedState.isPlaying

        await activity.update(
            ActivityContent(state: updatedState, staleDate: nil)
        )
    }

    /// End all Live Activities for this app (clears shared data - use when playback stops)
    func endAllActivities() async {
        for activity in Activity<NowPlayingAttributes>.activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
        currentActivity = nil

        // Clear shared data and cached artwork
        clearSharedData()
    }

    /// End activities for transition to a new activity (preserves shared data)
    private func endActivitiesForTransition() async {
        for activity in Activity<NowPlayingAttributes>.activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
        currentActivity = nil
        // Note: Do NOT clear shared data here - new activity will update it
    }

    // MARK: - Private Helpers

    /// Build ContentState from NowPlayingItem (synchronous - no image loading)
    private func contentState(from item: NowPlayingItem) -> NowPlayingAttributes.ContentState {
        // Build subtitle based on media type
        let subtitle: String
        switch item.type {
        case .episode:
            subtitle = item.subtitle ?? "TV Show"
        case .movie:
            subtitle = item.subtitle ?? "Movie"
        case .song:
            subtitle = item.subtitle ?? "Music"
        case .musicvideo:
            subtitle = item.subtitle ?? "Music Video"
        case .unknown:
            subtitle = item.subtitle ?? ""
        }

        // Format resolution
        let resolution: String? = {
            guard let height = item.videoHeight else { return nil }
            if height >= 2160 { return "4K" }
            else if height >= 1080 { return "1080p" }
            else if height >= 720 { return "720p" }
            else if height >= 480 { return "480p" }
            return nil
        }()

        // Format audio codec
        let audioCodec: String? = {
            guard let codec = item.audioCodec else { return nil }
            let lower = codec.lowercased()
            if lower.contains("truehd") { return "TrueHD" }
            else if lower.contains("dts") {
                if lower.contains("hd") || lower.contains("ma") { return "DTS-HD" }
                else if lower.contains("x") { return "DTS:X" }
                return "DTS"
            }
            else if lower.contains("eac3") || lower.contains("ec3") || lower.contains("ddp") { return "DD+" }
            else if lower.contains("ac3") { return "DD" }
            else if lower.contains("aac") { return "AAC" }
            else if lower.contains("flac") { return "FLAC" }
            return nil
        }()

        return NowPlayingAttributes.ContentState(
            title: item.title,
            subtitle: subtitle,
            hasPoster: AppGroupConstants.hasPoster,
            hasFanart: AppGroupConstants.hasFanart,
            elapsedTime: item.position,
            totalDuration: item.duration,
            isPlaying: item.isPlaying,
            lastUpdated: Date(),
            hdrType: item.hdrType,
            resolution: resolution,
            audioCodec: audioCodec,
            hasAtmos: item.hasAtmos
        )
    }

    /// Cache artwork images to App Group container
    private func cacheArtwork(for item: NowPlayingItem, host: KodiHost) async {
        // Cache poster if artwork path changed
        if item.artworkPath != currentPosterPath {
            currentPosterPath = item.artworkPath

            if let artworkPath = item.artworkPath,
               let url = host.imageURL(for: artworkPath) {
                await cacheImage(from: url, to: AppGroupConstants.posterURL, host: host, maxWidth: 200)
            } else {
                // No artwork - delete cached file
                if let posterURL = AppGroupConstants.posterURL {
                    try? FileManager.default.removeItem(at: posterURL)
                }
            }
        }

        // Cache fanart if fanart path changed
        if item.fanartPath != currentFanartPath {
            currentFanartPath = item.fanartPath

            if let fanartPath = item.fanartPath,
               let url = host.imageURL(for: fanartPath) {
                await cacheImage(from: url, to: AppGroupConstants.fanartURL, host: host, maxWidth: 400)
            } else {
                // No fanart - delete cached file
                if let fanartURL = AppGroupConstants.fanartURL {
                    try? FileManager.default.removeItem(at: fanartURL)
                }
            }
        }
    }

    /// Download, resize, and cache image to App Group container
    private func cacheImage(from url: URL, to fileURL: URL?, host: KodiHost, maxWidth: CGFloat) async {
        guard let fileURL = fileURL else { return }

        do {
            var request = URLRequest(url: url)
            request.timeoutInterval = 10

            // Add basic auth if credentials exist (required by Kodi)
            if let username = host.username, !username.isEmpty {
                let password = KeychainHelper.getPassword(for: host.id) ?? ""
                let credentials = "\(username):\(password)"
                if let data = credentials.data(using: .utf8) {
                    let base64 = data.base64EncodedString()
                    request.setValue("Basic \(base64)", forHTTPHeaderField: "Authorization")
                }
            }

            let (data, response) = try await URLSession.shared.data(for: request)

            // Check HTTP response
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                return
            }

            // Don't cache empty data
            guard data.count > 100 else { return }

            // Verify it's actually an image and resize it
            guard let originalImage = UIImage(data: data) else {
                return
            }

            // Resize image to fit widget constraints
            let resizedImage = resizeImage(originalImage, maxWidth: maxWidth)

            // Convert to JPEG for smaller file size
            guard let jpegData = resizedImage.jpegData(compressionQuality: 0.8) else {
                return
            }

            // Write to file with no file protection (needed for lock screen access)
            try jpegData.write(to: fileURL, options: [.atomic])

            // Set file protection to none so widget can read on lock screen
            try FileManager.default.setAttributes(
                [.protectionKey: FileProtectionType.none],
                ofItemAtPath: fileURL.path
            )

        } catch {
            // Image caching failed silently
        }
    }

    /// Resize image to fit within maxWidth while maintaining aspect ratio
    private func resizeImage(_ image: UIImage, maxWidth: CGFloat) -> UIImage {
        let scale = min(1, maxWidth / image.size.width)

        // If already small enough, return original
        if scale >= 1 { return image }

        let newSize = CGSize(
            width: image.size.width * scale,
            height: image.size.height * scale
        )

        // Force 1x scale to avoid @2x/@3x bloat in file size
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1

        let renderer = UIGraphicsImageRenderer(size: newSize, format: format)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }

    private func updateSharedData(host: KodiHost, playerId: Int) {
        guard let defaults = UserDefaults(suiteName: AppGroupConstants.suiteName) else {
            return
        }

        defaults.set(host.address, forKey: AppGroupConstants.hostAddressKey)
        defaults.set(host.httpPort, forKey: AppGroupConstants.hostPortKey)
        defaults.set(host.username, forKey: AppGroupConstants.hostUsernameKey)
        defaults.set(host.id.uuidString, forKey: "currentHostId")

        // Password is now shared via Keychain access group — no UserDefaults copy needed.
        defaults.removeObject(forKey: AppGroupConstants.hostPasswordKey)

        defaults.set(playerId, forKey: AppGroupConstants.activePlayerIdKey)
    }

    private func clearSharedData() {
        guard let defaults = UserDefaults(suiteName: AppGroupConstants.suiteName) else { return }

        defaults.removeObject(forKey: AppGroupConstants.hostAddressKey)
        defaults.removeObject(forKey: AppGroupConstants.hostPortKey)
        defaults.removeObject(forKey: AppGroupConstants.hostUsernameKey)
        defaults.removeObject(forKey: AppGroupConstants.hostPasswordKey)
        defaults.removeObject(forKey: AppGroupConstants.activePlayerIdKey)

        // Clear tracked paths
        currentPosterPath = nil
        currentFanartPath = nil

        // Delete cached artwork files
        AppGroupConstants.clearCachedArtwork()
    }

    private func getActivePlayerId() -> Int? {
        UserDefaults(suiteName: AppGroupConstants.suiteName)?.integer(forKey: AppGroupConstants.activePlayerIdKey)
    }
}
