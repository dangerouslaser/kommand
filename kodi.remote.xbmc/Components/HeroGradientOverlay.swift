//
//  HeroGradientOverlay.swift
//  kodi.remote.xbmc
//
//  The bottom-fading gradient that sits on top of hero artwork in detail views
//  (Movie, TV Show) and the now-playing card. Centralized so the four-stop curve
//  stays consistent across the app — visual drift between detail screens and the
//  remote was easy to introduce when each view rolled its own LinearGradient.
//

import SwiftUI

struct HeroGradientOverlay: View {
    /// The base color the gradient fades into (typically the surrounding background
    /// for the current color scheme so the artwork blends seamlessly into content
    /// below).
    let color: Color

    var body: some View {
        LinearGradient(
            stops: [
                .init(color: .clear, location: 0),
                .init(color: color.opacity(0.3), location: 0.4),
                .init(color: color.opacity(0.85), location: 0.75),
                .init(color: color, location: 1.0)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

#Preview {
    ZStack {
        Color.blue
        HeroGradientOverlay(color: .black)
    }
    .frame(height: 350)
}
