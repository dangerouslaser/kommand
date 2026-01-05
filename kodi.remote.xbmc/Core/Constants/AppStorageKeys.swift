//
//  AppStorageKeys.swift
//  kodi.remote.xbmc
//
//  Centralized AppStorage key constants for type safety and discoverability
//

import Foundation

enum AppStorageKeys {
    // MARK: - Appearance
    static let colorScheme = "colorScheme"              // 0=System, 1=Light, 2=Dark
    static let selectedTheme = "selectedTheme"          // Theme ID string
    static let nowPlayingBackground = "nowPlayingBackground"  // 0=Blur, 1=Solid

    // MARK: - Pro Features
    static let isProUnlocked = "isProUnlocked"
    static let liveActivityEnabled = "liveActivityEnabled"
    static let showDolbyVisionProfile = "showDolbyVisionProfile"

    // MARK: - Behavior
    static let hapticFeedback = "hapticFeedback"
    static let seekInterval = "seekInterval"
    static let keepScreenOn = "keepScreenOn"
    static let showVolumeSlider = "showVolumeSlider"
    static let useVolumeButtons = "useVolumeButtons"

    // MARK: - Tab Visibility
    static let showMoviesTab = "showMoviesTab"
    static let showTVShowsTab = "showTVShowsTab"
    static let showMusicTab = "showMusicTab"
    static let showPVRTab = "showPVRTab"

    // MARK: - View Modes
    static let moviesViewMode = "moviesViewMode"
    static let tvShowsViewMode = "tvShowsViewMode"

    // MARK: - Power Menu Options
    static let powerMenuRestartKodi = "powerMenuRestartKodi"
    static let powerMenuSuspend = "powerMenuSuspend"
    static let powerMenuReboot = "powerMenuReboot"
    static let powerMenuShutdown = "powerMenuShutdown"
}
