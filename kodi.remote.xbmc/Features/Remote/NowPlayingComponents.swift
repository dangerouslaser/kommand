//
//  NowPlayingComponents.swift
//  kodi.remote.xbmc
//

import SwiftUI

struct NowPlayingArtworkBackground: View {
    let item: NowPlayingItem
    let host: KodiHost?

    @ViewBuilder
    var body: some View {
        if let fanartPath = item.fanartPath, !fanartPath.isEmpty {
            AsyncArtworkImage(path: fanartPath, host: host)
                .clipped()
        } else if let artworkPath = item.artworkPath, !artworkPath.isEmpty {
            AsyncArtworkImage(path: artworkPath, host: host)
                .blur(radius: 20)
                .scaleEffect(1.2)
                .clipped()
        } else {
            LinearGradient(
                colors: [Color(white: 0.2), Color(white: 0.1)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
}

struct HeroBadge: View {
    let text: String
    var color: Color = .white.opacity(0.6)

    var body: some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(color.opacity(0.25), in: RoundedRectangle(cornerRadius: 3))
            .foregroundStyle(color == .white.opacity(0.6) ? .white.opacity(0.8) : color)
    }
}

struct CodecBadge: View {
    let text: String
    var color: Color = .secondary

    var body: some View {
        Text(text)
            .font(.caption2)
            .fontWeight(.medium)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.2), in: RoundedRectangle(cornerRadius: 4))
            .foregroundStyle(color)
    }
}

struct DetailRow: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 16)

            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()

            Text(value)
                .font(.caption)
                .foregroundStyle(.primary)
                .lineLimit(1)
        }
    }
}
