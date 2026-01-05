//
//  DesignSystem.swift
//  kodi.remote.xbmc
//
//  Centralized design constants for consistent UI
//

import SwiftUI

enum DesignSystem {
    // MARK: - Corner Radius
    enum Radius {
        static let card: CGFloat = 20
        static let button: CGFloat = 12
        static let thumbnail: CGFloat = 8
        static let badge: CGFloat = 6
        static let small: CGFloat = 4
    }

    // MARK: - Spacing
    enum Spacing {
        static let cardPadding: CGFloat = 16
        static let sectionSpacing: CGFloat = 24
        static let itemSpacing: CGFloat = 12
        static let small: CGFloat = 8
        static let tiny: CGFloat = 4
    }

    // MARK: - Image Sizing
    enum ImageSize {
        static let posterMaxWidth: CGFloat = 200
        static let fanartMaxWidth: CGFloat = 400
        static let thumbnailSize: CGFloat = 60
    }

    // MARK: - Animation
    enum Animation {
        static let standard: SwiftUI.Animation = .easeInOut(duration: 0.2)
        static let spring: SwiftUI.Animation = .spring(response: 0.3, dampingFraction: 0.7)
    }
}
