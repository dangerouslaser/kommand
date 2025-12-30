//
//  TVShowDetailView.swift
//  kodi.remote.xbmc
//

import SwiftUI

struct TVShowDetailView: View {
    let show: TVShow
    let viewModel: TVShowsViewModel
    @Environment(AppState.self) private var appState
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.colorScheme) private var colorScheme

    private var isIPad: Bool {
        horizontalSizeClass == .regular
    }

    private var gradientColor: Color {
        colorScheme == .dark ? .black : .white
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Hero Image with overlay content on iPad
                GeometryReader { geo in
                    ZStack(alignment: .bottomLeading) {
                        AsyncArtworkImage(path: show.fanartPath ?? show.posterPath, host: appState.currentHost)
                            .frame(width: geo.size.width, height: geo.size.height)
                            .clipped()

                        // Gradient overlay at bottom (adapts to color scheme)
                        LinearGradient(
                            stops: [
                                .init(color: .clear, location: 0),
                                .init(color: gradientColor.opacity(0.3), location: 0.4),
                                .init(color: gradientColor.opacity(0.85), location: 0.75),
                                .init(color: gradientColor, location: 1.0)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )

                        // Show logo/title overlay on hero
                        heroOverlayContent
                            .padding(isIPad ? 32 : 16)
                    }
                }
                .frame(height: isIPad ? 550 : 350)

                VStack(alignment: .leading, spacing: 16) {

                    // Plot
                    if let plot = show.plot, !plot.isEmpty {
                        Text(plot)
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }

                    // Seasons
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Seasons")
                            .font(.headline)

                        if viewModel.isLoadingSeasons {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                        } else if viewModel.seasons.isEmpty {
                            Text("No seasons found")
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(viewModel.seasons) { season in
                                NavigationLink(value: season) {
                                    SeasonRow(season: season, host: appState.currentHost)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding()
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .ignoresSafeArea(edges: .top)
        .navigationDestination(for: Season.self) { season in
            SeasonDetailView(show: show, season: season, viewModel: viewModel)
        }
        .task {
            await viewModel.loadSeasons(for: show)
        }
    }

    // MARK: - Hero Overlay (iPad)

    private var heroOverlayContent: some View {
        VStack(alignment: .leading, spacing: isIPad ? 12 : 8) {
            // Clearlogo or title
            if let clearlogo = show.clearlogoPath {
                AsyncArtworkImage(path: clearlogo, host: appState.currentHost)
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: isIPad ? 450 : 280, maxHeight: isIPad ? 140 : 80, alignment: .leading)
            } else {
                Text(show.title)
                    .font(.system(size: isIPad ? 42 : 28, weight: .bold))
                    .shadow(color: .black.opacity(0.7), radius: 4, x: 0, y: 2)
            }

            // Metadata row
            HStack(spacing: isIPad ? 16 : 12) {
                if let year = show.year {
                    Text(String(year))
                }
                if let seasons = show.season {
                    Text("\(seasons) Seasons")
                }
                if let episodes = show.episode {
                    Text("\(episodes) Episodes")
                }
                if let rating = show.formattedRating {
                    HStack(spacing: 4) {
                        Image(systemName: "star.fill")
                            .foregroundStyle(.yellow)
                        Text(rating)
                    }
                }
            }
            .font(isIPad ? .headline : .subheadline)

            if let genres = show.genreText {
                Text(genres)
                    .font(isIPad ? .subheadline : .caption)
            }

            if show.unwatchedCount > 0 {
                Text("\(show.unwatchedCount) unwatched episodes")
                    .font(isIPad ? .subheadline : .caption)
                    .foregroundStyle(.cyan)
            }
        }
        .foregroundStyle(colorScheme == .dark ? .white : .black)
    }

    // MARK: - Title and Metadata (iPhone)

    private var titleAndMetadata: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Clearlogo or title
            if let clearlogo = show.clearlogoPath {
                AsyncArtworkImage(path: clearlogo, host: appState.currentHost)
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: 280, maxHeight: 80, alignment: .leading)
            } else {
                Text(show.title)
                    .font(.title)
                    .fontWeight(.bold)
            }

            HStack(spacing: 12) {
                if let year = show.year {
                    Text(String(year))
                }
                if let seasons = show.season {
                    Text("\(seasons) Seasons")
                }
                if let episodes = show.episode {
                    Text("\(episodes) Episodes")
                }
                if let rating = show.formattedRating {
                    HStack(spacing: 4) {
                        Image(systemName: "star.fill")
                            .foregroundStyle(.yellow)
                        Text(rating)
                    }
                }
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)

            if let genres = show.genreText {
                Text(genres)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if show.unwatchedCount > 0 {
                Text("\(show.unwatchedCount) unwatched episodes")
                    .font(.subheadline)
                    .foregroundStyle(.blue)
            }
        }
    }
}

// MARK: - Season Row

struct SeasonRow: View {
    let season: Season
    let host: KodiHost?

    var body: some View {
        HStack(spacing: 12) {
            AsyncArtworkImage(path: season.posterPath, host: host)
                .frame(width: 80, height: 120)
                .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 4) {
                Text(season.displayName)
                    .font(.headline)

                if let episodes = season.episode {
                    Text("\(episodes) Episodes")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                if season.unwatchedCount > 0 {
                    Text("\(season.unwatchedCount) unwatched")
                        .font(.caption)
                        .foregroundStyle(.blue)
                } else if season.isFullyWatched {
                    Label("Watched", systemImage: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.green)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}

#Preview {
    NavigationStack {
        TVShowDetailView(
            show: TVShow(
                tvshowid: 1,
                title: "Breaking Bad",
                year: 2008,
                rating: 9.5,
                plot: "A high school chemistry teacher diagnosed with cancer turns to manufacturing drugs.",
                genre: ["Crime", "Drama", "Thriller"],
                studio: ["AMC"],
                cast: nil,
                thumbnail: nil,
                fanart: nil,
                art: nil,
                episode: 62,
                watchedepisodes: 50,
                season: 5,
                playcount: nil,
                file: nil,
                imdbnumber: nil,
                premiered: nil,
                dateadded: nil
            ),
            viewModel: TVShowsViewModel()
        )
    }
    .environment(AppState())
}
