//
//  HapticService.swift
//  kodi.remote.xbmc
//
//  Centralized haptic feedback service
//

import UIKit

enum HapticService {
    /// Trigger impact haptic feedback
    static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .medium) {
        guard UserDefaults.standard.bool(forKey: "hapticFeedback") else { return }
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }

    /// Trigger notification haptic feedback
    static func notification(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        guard UserDefaults.standard.bool(forKey: "hapticFeedback") else { return }
        UINotificationFeedbackGenerator().notificationOccurred(type)
    }

    /// Trigger selection changed haptic feedback
    static func selection() {
        guard UserDefaults.standard.bool(forKey: "hapticFeedback") else { return }
        UISelectionFeedbackGenerator().selectionChanged()
    }
}
