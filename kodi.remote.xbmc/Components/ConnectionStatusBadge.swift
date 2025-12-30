//
//  ConnectionStatusBadge.swift
//  kodi.remote.xbmc
//

import SwiftUI

struct ConnectionStatusBadge: View {
    let state: ConnectionState
    let isCoreELEC: Bool
    let onStandby: (() -> Void)?
    let onWakeUp: (() -> Void)?

    init(
        state: ConnectionState,
        isCoreELEC: Bool = false,
        onStandby: (() -> Void)? = nil,
        onWakeUp: (() -> Void)? = nil
    ) {
        self.state = state
        self.isCoreELEC = isCoreELEC
        self.onStandby = onStandby
        self.onWakeUp = onWakeUp
    }

    private var iconColor: Color {
        switch state {
        case .connected: return .green
        case .connecting: return .orange
        case .disconnected: return .gray
        case .error: return .red
        }
    }

    var body: some View {
        HStack(spacing: 8) {
            // Connection status icon (colored by state)
            Group {
                if case .connecting = state {
                    ProgressView()
                        .controlSize(.mini)
                } else {
                    Image(systemName: "play.tv.fill")
                        .font(.caption)
                        .foregroundStyle(iconColor)
                }
            }

            // Power menu (CoreELEC only)
            if isCoreELEC, onStandby != nil || onWakeUp != nil {
                Divider()
                    .frame(height: 16)

                Menu {
                    if let onWakeUp = onWakeUp {
                        Button {
                            onWakeUp()
                        } label: {
                            Label("Wake Up TV", systemImage: "power.circle")
                        }
                    }
                    if let onStandby = onStandby {
                        Button(role: .destructive) {
                            onStandby()
                        } label: {
                            Label("Turn Off TV & AVR", systemImage: "power")
                        }
                    }
                } label: {
                    Image(systemName: "power")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)
                }
                .menuStyle(.borderlessButton)
                .accessibilityLabel("TV Power")
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color(.systemGray5), in: Capsule())
        .accessibilityLabel(state.statusText)
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        VStack(spacing: 20) {
            ConnectionStatusBadge(state: .connected, isCoreELEC: true, onStandby: {}, onWakeUp: {})
            ConnectionStatusBadge(state: .connected, isCoreELEC: false)
            ConnectionStatusBadge(state: .connecting)
            ConnectionStatusBadge(state: .disconnected)
            ConnectionStatusBadge(state: .error("Failed"))
        }
    }
}
