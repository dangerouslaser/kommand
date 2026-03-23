//
//  AppStorageKeys.swift
//  kodi.remote.xbmc
//
//  Centralized AppStorage key constants for type safety and discoverability
//

import Foundation

nonisolated enum AppStorageKeys {
    // MARK: - Appearance
    static let colorScheme = "colorScheme"              // 0=System, 1=Light, 2=Dark
    static let selectedTheme = "selectedTheme"          // Theme ID string
    static let nowPlayingBackground = "nowPlayingBackground"  // 0=Blur, 1=Solid

    // MARK: - Features
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

    // MARK: - Library Sort & Filter
    static let movieSortField = "movieSortField"
    static let movieSortAscending = "movieSortAscending"
    static let movieFilter = "movieFilter"
    static let tvShowSortField = "tvShowSortField"
    static let tvShowSortAscending = "tvShowSortAscending"
    static let tvShowFilter = "tvShowFilter"

    // MARK: - Hints
    static let hasUsedStopGesture = "hasUsedStopGesture"

    // MARK: - Power Button
    static let powerPrimaryAction = "powerPrimaryAction"
    static let powerEnabledActions = "powerEnabledActions"
    static let powerConfirmPrimary = "powerConfirmPrimaryAction"
}
