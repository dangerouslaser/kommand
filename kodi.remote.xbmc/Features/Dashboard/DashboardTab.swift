//
//  DashboardTab.swift
//  kodi.remote.xbmc
//

import SwiftUI

struct DashboardTab: View {
    @Environment(AppState.self) private var appState
    @State private var viewModel = DashboardViewModel()

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isInitialLoad && viewModel.isLoadingInProgress && viewModel.isLoadingRecent {
                    ProgressView("Loading...")
                } else if !viewModel.hasContinueWatching && !viewModel.hasRecentlyAdded {
                    ContentUnavailableView {
                        Label("Nothing Here Yet", systemImage: "play.square.stack")
                    } description: {
                        Text("Start watching something and it will appear here")
                    }
                } else {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 24) {
                            // Continue Watching
                            if viewModel.hasContinueWatching {
                                continueWatchingSection
                            }

                            // Recently Added Movies
                            if !viewModel.recentMovies.isEmpty {
                                recentMoviesSection
                            }

                            // Recently Added Shows
                            if !viewModel.recentShows.isEmpty {
                                recentShowsSection
                            }
                        }
                        .padding(.vertical)
                    }
                }
            }
            .navigationTitle("Home")
            .navigationDestination(for: Movie.self) { movie in
                DashboardMovieDetailWrapper(movie: movie)
            }
            .navigationDestination(for: RecentShowInfo.self) { showInfo in
                DashboardShowDetailWrapper(showInfo: showInfo)
            }
            .navigationDestination(for: DashboardEpisodeNavItem.self) { item in
                DashboardEpisodeDetailWrapper(episode: item.episode)
            }
            .refreshable {
                await viewModel.refresh()
            }
        }
        .task {
            viewModel.configure(appState: appState)
            await viewModel.loadAll()
        }
    }

    // MARK: - Continue Watching Section

    private var continueWatchingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Continue Watching")
                .font(.title2)
                .fontWeight(.bold)
                .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    // In-progress movies
                    ForEach(viewModel.inProgressMovies) { movie in
                        NavigationLink(value: movie) {
                            ContinueWatchingCardView(
                                title: movie.title,
                                subtitle: movie.formattedRuntime,
                                artworkPath: movie.fanartPath ?? movie.posterPath,
                                progress: movie.resume?.progress ?? 0,
                                host: appState.currentHost
                            )
                        }
                        .buttonStyle(.plain)
                    }

                    // In-progress episodes
                    ForEach(viewModel.inProgressEpisodes) { episode in
                        NavigationLink(value: DashboardEpisodeNavItem(episode: episode)) {
                            ContinueWatchingCardView(
                                title: episode.showtitle ?? episode.title,
                                subtitle: "\(episode.episodeNumber) - \(episode.title)",
                                artworkPath: episode.fanart ?? episode.thumbnail,
                                progress: episode.resume?.progress ?? 0,
                                host: appState.currentHost
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    // MARK: - Recent Movies Section

    private var recentMoviesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recently Added Movies")
                .font(.title2)
                .fontWeight(.bold)
                .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(viewModel.recentMovies) { movie in
                        NavigationLink(value: movie) {
                            RecentPosterCardView(
                                title: movie.title,
                                subtitle: movie.year.map { String($0) },
                                artworkPath: movie.posterPath,
                                isWatched: movie.isWatched,
                                host: appState.currentHost
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    // MARK: - Recent Shows Section

    private var recentShowsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recently Added Shows")
                .font(.title2)
                .fontWeight(.bold)
                .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(viewModel.recentShows) { showInfo in
                        NavigationLink(value: showInfo) {
                            RecentShowCardView(
                                title: showInfo.title,
                                seasonInfo: "Season \(showInfo.season)",
                                newEpisodeCount: showInfo.newEpisodeCount,
                                artworkPath: showInfo.fanart ?? showInfo.thumbnail,
                                host: appState.currentHost
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)
            }
        }
    }
}

// MARK: - Navigation Item for Episodes (needed for Hashable conformance)

struct DashboardEpisodeNavItem: Hashable {
    let episode: Episode

    func hash(into hasher: inout Hasher) {
        hasher.combine(episode.id)
    }

    static func == (lhs: DashboardEpisodeNavItem, rhs: DashboardEpisodeNavItem) -> Bool {
        lhs.episode.id == rhs.episode.id
    }
}

// MARK: - Continue Watching Card (Display Only for NavigationLink)

struct ContinueWatchingCardView: View {
    let title: String
    let subtitle: String?
    let artworkPath: String?
    let progress: Double
    let host: KodiHost?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .bottomLeading) {
                // Background artwork
                Color.clear
                    .aspectRatio(16/9, contentMode: .fit)
                    .frame(width: 280)
                    .overlay {
                        AsyncArtworkImage(path: artworkPath, host: host)
                    }
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                // Gradient overlay
                LinearGradient(
                    colors: [.clear, .black.opacity(0.7)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .clipShape(RoundedRectangle(cornerRadius: 12))

                // Title and progress
                VStack(alignment: .leading, spacing: 6) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(.white)
                        .lineLimit(1)

                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.8))
                            .lineLimit(1)
                    }

                    ProgressView(value: progress)
                        .tint(.white)
                }
                .padding(12)

                // Play button overlay
                HStack {
                    Spacer()
                    VStack {
                        Spacer()
                        Image(systemName: "play.circle.fill")
                            .font(.system(size: 44))
                            .foregroundStyle(.white)
                            .shadow(radius: 4)
                        Spacer()
                    }
                    Spacer()
                }
            }
        }
    }
}

// MARK: - Recent Poster Card (Display Only for NavigationLink)

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
                    .clipShape(RoundedRectangle(cornerRadius: 8))

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

                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 120, alignment: .leading)
        }
    }
}

// MARK: - Recent Show Card (Display Only for NavigationLink)

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
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                // New episodes badge
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

// MARK: - Navigation Wrapper Views

/// Wrapper for MovieDetailView that creates its own ViewModel
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

/// Wrapper for TVShowDetailView that fetches the show and creates its own ViewModel
struct DashboardShowDetailWrapper: View {
    let showInfo: RecentShowInfo
    @Environment(AppState.self) private var appState
    @State private var viewModel = TVShowsViewModel()
    @State private var libraryState = LibraryState()
    @State private var tvShow: TVShow?
    @State private var isLoading = true
    @State private var error: String?

    private let client = KodiClient()

    var body: some View {
        Group {
            if isLoading {
                ProgressView("Loading show...")
            } else if let tvShow = tvShow {
                TVShowDetailView(show: tvShow, viewModel: viewModel)
            } else if let error = error {
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
        guard let host = appState.currentHost else {
            await MainActor.run {
                error = "No host configured"
                isLoading = false
            }
            return
        }

        await client.configure(with: host)

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

/// Wrapper for Episode detail - shows episode info with play options
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
                // Hero Image
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
                    // Show title
                    if let showTitle = episode.showtitle {
                        Text(showTitle)
                            .font(.headline)
                            .foregroundStyle(.secondary)
                    }

                    // Episode title
                    Text(episode.title)
                        .font(.title)
                        .fontWeight(.bold)

                    // Episode info
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

                    // Action buttons
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

                    // Plot
                    if let plot = episode.plot, !plot.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Plot")
                                .font(.headline)
                            Text(plot)
                                .font(.body)
                                .foregroundStyle(.secondary)
                        }
                    }

                    // First aired
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

#Preview {
    DashboardTab()
        .environment(AppState())
}
