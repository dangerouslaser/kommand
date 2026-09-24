//
//  DashboardSearchRows.swift
//  kodi.remote.xbmc
//

import SwiftUI

struct SearchMovieRow: View {
    let movie: Movie
    let host: KodiHost?

    var body: some View {
        HStack(spacing: 12) {
            AsyncArtworkImage(path: movie.posterPath, host: host)
                .frame(width: 50, height: 75)
                .clipShape(RoundedRectangle(cornerRadius: 6))

            VStack(alignment: .leading, spacing: 4) {
                Text(movie.title)
                    .font(.headline)
                    .lineLimit(2)

                HStack(spacing: 8) {
                    if let year = movie.year {
                        Text(String(year))
                    }
                    if let runtime = movie.formattedRuntime {
                        Text("•")
                        Text(runtime)
                    }
                    if let rating = movie.formattedRating {
                        Text("•")
                        HStack(spacing: 2) {
                            Image(systemName: "star.fill")
                                .foregroundStyle(.yellow)
                            Text(rating)
                        }
                    }
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }

            Spacer()

            if movie.isWatched {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            }
        }
        .padding(.vertical, 4)
    }
}

struct SearchTVShowRow: View {
    let show: TVShow
    let host: KodiHost?

    var body: some View {
        HStack(spacing: 12) {
            AsyncArtworkImage(path: show.posterPath, host: host)
                .frame(width: 50, height: 75)
                .clipShape(RoundedRectangle(cornerRadius: 6))

            VStack(alignment: .leading, spacing: 4) {
                Text(show.title)
                    .font(.headline)
                    .lineLimit(2)

                HStack(spacing: 8) {
                    if let year = show.year {
                        Text(String(year))
                    }
                    if let seasons = show.season, seasons > 0 {
                        Text("•")
                        Text("\(seasons) Season\(seasons == 1 ? "" : "s")")
                    }
                    if let rating = show.formattedRating {
                        Text("•")
                        HStack(spacing: 2) {
                            Image(systemName: "star.fill")
                                .foregroundStyle(.yellow)
                            Text(rating)
                        }
                    }
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }

            Spacer()

            if show.isFullyWatched {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            }
        }
        .padding(.vertical, 4)
    }
}

struct SearchChannelRow: View {
    let channel: PVRChannel
    let host: KodiHost?

    var body: some View {
        HStack(spacing: 12) {
            AsyncArtworkImage(path: channel.thumbnail, host: host)
                .frame(width: 50, height: 50)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay {
                    if channel.thumbnail == nil {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.secondary.opacity(0.2))
                            .overlay {
                                Image(systemName: "tv")
                                    .foregroundStyle(.secondary)
                            }
                    }
                }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    if let number = channel.channelNumber {
                        Text(number)
                            .font(.caption)
                            .fontWeight(.semibold)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.secondary.opacity(0.2), in: RoundedRectangle(cornerRadius: 4))
                    }
                    Text(channel.label)
                        .font(.headline)
                        .lineLimit(1)
                }

                if let nowPlaying = channel.broadcastnow {
                    Text(nowPlaying.title)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)

                    if let timeRange = nowPlaying.formattedTimeRange {
                        Text(timeRange)
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
            }

            Spacer()

            if channel.isrecording == true {
                Image(systemName: "record.circle.fill")
                    .foregroundStyle(.red)
            }

            Image(systemName: "play.fill")
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}
