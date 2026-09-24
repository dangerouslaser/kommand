//
//  DashboardNavigationViews.swift
//  kodi.remote.xbmc
//

import SwiftUI

struct DashboardEpisodeNavItem: Hashable {
    let episode: Episode

    func hash(into hasher: inout Hasher) {
        hasher.combine(episode.id)
    }

    static func == (lhs: DashboardEpisodeNavItem, rhs: DashboardEpisodeNavItem) -> Bool {
        lhs.episode.id == rhs.episode.id
    }
}

struct DashboardMovieDetailWrapper: View {
    let movie: Movie
    @Environment(AppState.self) private var appState
    @State private var viewModel = MoviesViewModel()
    @State private var libraryState = LibraryState()

    var body: some View {
        MovieDetailView(movie: movie, viewModel: viewModel)
            .task {
                viewModel.configure(appState: appState, libraryState: libraryState)
            }
    }
}

struct DashboardShowDetailWrapper: View {
    let showInfo: RecentShowInfo
    @Environment(AppState.self) private var appState
    @State private var viewModel = TVShowsViewModel()
    @State private var libraryState = LibraryState()
    @State private var tvShow: TVShow?
    @State private var isLoading = true
    @State private var error: String?

    var body: some View {
        Group {
            if isLoading {
                LoadingPlaceholder(message: "Loading show...")
            } else if let tvShow {
                TVShowDetailView(show: tvShow, viewModel: viewModel)
            } else if let error {
                ContentUnavailableView {
                    Label("Error", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(error)
                }
            }
        }
        .task {
            viewModel.configure(appState: appState, libraryState: libraryState)
            await loadTVShow()
        }
    }

    private func loadTVShow() async {
        guard appState.currentHost != nil else {
            await MainActor.run {
                error = "No host configured"
                isLoading = false
            }
            return
        }

        let client = appState.client

        do {
            let response = try await client.getTVShowDetails(tvShowId: showInfo.tvshowid)
            await MainActor.run {
                tvShow = response.tvshowdetails
                isLoading = false
            }
        } catch {
            await MainActor.run {
                self.error = error.localizedDescription
                isLoading = false
            }
        }
    }
}

struct DashboardEpisodeDetailWrapper: View {
    let episode: Episode
    @Environment(AppState.self) private var appState
    @Environment(\.colorScheme) private var colorScheme
    @State private var viewModel = DashboardViewModel()

    private var gradientColor: Color {
        colorScheme == .dark ? .black : .white
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                GeometryReader { geo in
                    ZStack(alignment: .bottomLeading) {
                        AsyncArtworkImage(path: episode.fanart ?? episode.thumbnail, host: appState.currentHost)
                            .frame(width: geo.size.width, height: geo.size.height)
                            .clipped()

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
                    }
                }
                .frame(height: 220)

                VStack(alignment: .leading, spacing: 16) {
                    if let showTitle = episode.showtitle {
                        Text(showTitle)
                            .font(.headline)
                            .foregroundStyle(.secondary)
                    }

                    Text(episode.title)
                        .font(.title)
                        .fontWeight(.bold)

                    HStack(spacing: 12) {
                        Text(episode.episodeNumber)
                        if let runtime = episode.formattedRuntime {
                            Text(runtime)
                        }
                        if let rating = episode.formattedRating {
                            HStack(spacing: 4) {
                                Image(systemName: "star.fill")
                                    .foregroundStyle(.yellow)
                                Text(rating)
                            }
                        }
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                    HStack(spacing: 12) {
                        if episode.hasResume {
                            Button {
                                Task { await viewModel.playEpisode(episode, resume: true) }
                            } label: {
                                Label("Resume", systemImage: "play.fill")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)

                            Button {
                                Task { await viewModel.playEpisode(episode, resume: false) }
                            } label: {
                                Label("Start Over", systemImage: "arrow.counterclockwise")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                        } else {
                            Button {
                                Task { await viewModel.playEpisode(episode, resume: false) }
                            } label: {
                                Label("Play", systemImage: "play.fill")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    }

                    if let plot = episode.plot, !plot.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Plot")
                                .font(.headline)
                            Text(plot)
                                .font(.body)
                                .foregroundStyle(.secondary)
                        }
                    }

                    if let firstaired = episode.firstaired, !firstaired.isEmpty {
                        HStack {
                            Text("First Aired")
                                .font(.headline)
                            Spacer()
                            Text(firstaired)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding()
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .ignoresSafeArea(edges: .top)
        .task {
            viewModel.configure(appState: appState)
        }
    }
}

struct DashboardTVShowDetailWrapper: View {
    let show: TVShow
    @Environment(AppState.self) private var appState
    @State private var viewModel = TVShowsViewModel()
    @State private var libraryState = LibraryState()

    var body: some View {
        TVShowDetailView(show: show, viewModel: viewModel)
            .task {
                viewModel.configure(appState: appState, libraryState: libraryState)
            }
    }
}
