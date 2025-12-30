//
//  ConnectionStatusBadge.swift
//  kodi.remote.xbmc
//

import SwiftUI

struct ConnectionStatusBadge: View {
    let state: ConnectionState

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(state.statusColor)
                .frame(width: 8, height: 8)

            if case .connecting = state {
                ProgressView()
                    .controlSize(.small)
            }
        }
        .accessibilityLabel(state.statusText)
    }
}

#Preview {
    VStack(spacing: 20) {
        ConnectionStatusBadge(state: .connected)
        ConnectionStatusBadge(state: .connecting)
        ConnectionStatusBadge(state: .disconnected)
        ConnectionStatusBadge(state: .error("Failed"))
    }
}
