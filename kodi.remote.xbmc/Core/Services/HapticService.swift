//
//  HapticService.swift
//  kodi.remote.xbmc
//
//  Centralized haptic feedback service
//

import UIKit

enum HapticService {

    enum ImpactStyle {
        case light, medium, heavy

        fileprivate var uiKit: UIImpactFeedbackGenerator.FeedbackStyle {
            switch self {
            case .light: .light
            case .medium: .medium
            case .heavy: .heavy
            }
        }
    }

    enum NotificationType {
        case success, warning, error

        fileprivate var uiKit: UINotificationFeedbackGenerator.FeedbackType {
            switch self {
            case .success: .success
            case .warning: .warning
            case .error: .error
            }
        }
    }

    /// Trigger impact haptic feedback
    static func impact(_ style: ImpactStyle = .medium) {
        guard UserDefaults.standard.bool(forKey: "hapticFeedback") else { return }
        UIImpactFeedbackGenerator(style: style.uiKit).impactOccurred()
    }

    /// Trigger notification haptic feedback
    static func notification(_ type: NotificationType) {
        guard UserDefaults.standard.bool(forKey: "hapticFeedback") else { return }
        UINotificationFeedbackGenerator().notificationOccurred(type.uiKit)
    }

    /// Trigger selection changed haptic feedback
    static func selection() {
        guard UserDefaults.standard.bool(forKey: "hapticFeedback") else { return }
        UISelectionFeedbackGenerator().selectionChanged()
    }
}
