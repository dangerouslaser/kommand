//
//  DashboardCards.swift
//  kodi.remote.xbmc
//

import SwiftUI

struct ContinueWatchingCardView: View {
    let title: String
    let subtitle: String?
    let artworkPath: String?
    let clearlogoPath: String?
    let progress: Double
    let host: KodiHost?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack {
                Color.clear
                    .aspectRatio(16/9, contentMode: .fit)
                    .frame(width: 280)
                    .overlay {
                        AsyncArtworkImage(path: artworkPath, host: host)
                    }
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.button))

                LinearGradient(
                    colors: [.black.opacity(0.3), .black.opacity(0.8)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.button))

                if let clearlogoPath {
                    AsyncArtworkImage(path: clearlogoPath, host: host)
                        .frame(height: 50)
                        .frame(maxWidth: 200)
                } else {
                    Text(title)
                        .font(.system(size: 22, weight: .heavy))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.8), radius: 4, x: 0, y: 2)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .minimumScaleFactor(0.7)
                        .frame(maxWidth: 248)
                        .padding(.horizontal, 16)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Spacer()

                    if let subtitle {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.8))
                            .lineLimit(1)
                    }

                    ProgressView(value: progress)
                        .tint(.white)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

struct RecentPosterCardView: View {
    let title: String
    let subtitle: String?
    let artworkPath: String?
    let isWatched: Bool
    let host: KodiHost?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .topTrailing) {
                Color.clear
                    .aspectRatio(2/3, contentMode: .fit)
                    .frame(width: 120)
                    .overlay {
                        AsyncArtworkImage(path: artworkPath, host: host)
                    }
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.thumbnail))

                if isWatched {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.white)
                        .background(Circle().fill(.green))
                        .padding(6)
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .lineLimit(2, reservesSpace: true)

                if let subtitle {
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 120, alignment: .leading)
        }
    }
}

struct RecentShowCardView: View {
    let title: String
    let seasonInfo: String
    let newEpisodeCount: Int
    let artworkPath: String?
    let host: KodiHost?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .topTrailing) {
                Color.clear
                    .aspectRatio(16/9, contentMode: .fit)
                    .frame(width: 200)
                    .overlay {
                        AsyncArtworkImage(path: artworkPath, host: host)
                    }
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.thumbnail))

                Text("\(newEpisodeCount) new")
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.blue, in: RoundedRectangle(cornerRadius: 6))
                    .foregroundStyle(.white)
                    .padding(6)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .lineLimit(1)

                Text(seasonInfo)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .frame(width: 200, alignment: .leading)
        }
    }
}
