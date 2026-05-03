//
//  LoadingPlaceholder.swift
//  kodi.remote.xbmc
//
//  The "ProgressView + secondary caption" pattern that appears in every tab while
//  initial library data is being fetched. Centralized so spacing/typography stay
//  consistent if the design ever changes.
//

import SwiftUI

struct LoadingPlaceholder: View {
    let message: String

    var body: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text(message)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    LoadingPlaceholder(message: "Loading Artists…")
}
