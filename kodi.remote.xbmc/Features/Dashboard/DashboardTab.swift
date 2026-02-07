//
//  DashboardTab.swift
//  kodi.remote.xbmc
//

import SwiftUI

struct DashboardTab: View {
    @Environment(AppState.self) private var appState
    @State private var viewModel = DashboardViewModel()
    @State private var searchText = ""
    @State private var searchTask: Task<Void, Never>?

    var body: some View {
        NavigationStack {
            Group {
                if !searchText.isEmpty {
                    // Search Results
                    searchResultsView
                } else if viewModel.isInitialLoad && viewModel.isLoadingInProgress && viewModel.isLoadingRecent {
                    VStack(spacing: 12) {
                        ProgressView()
                        Text("Loading...")
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
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
            .searchable(text: $searchText, prompt: "Search movies & shows")
            .onChange(of: searchText) { _, newValue in
                searchTask?.cancel()
                searchTask = Task {
                    try? await Task.sleep(for: .milliseconds(300))
                    guard !Task.isCancelled else { return }
                    await viewModel.search(query: newValue)
                }
            }
            .navigationDestination(for: Movie.self) { movie in
                DashboardMovieDetailWrapper(movie: movie)
            }
            .navigationDestination(for: TVShow.self) { show in
                DashboardTVShowDetailWrapper(show: show)
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
            .themedBackground()
        }
        .task {
            viewModel.configure(appState: appState)
            await viewModel.loadAll()
        }
        .onChange(of: appState.currentHost?.id) { _, _ in
            // Host changed - reconfigure client and reload
            viewModel.configure(appState: appState)
            Task {
                await viewModel.refresh()
            }
        }
    }

    // MARK: - Search Results

    private var searchResultsView: some View {
        Group {
            if viewModel.isSearching {
                VStack(spacing: 12) {
                    ProgressView()
                    Text("Searching...")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if !viewModel.hasSearchResults {
                ContentUnavailableView.search(text: searchText)
            } else {
                List {
                    // Live TV Section
                    if !viewModel.searchChannels.isEmpty {
                        Section("Live TV") {
                            ForEach(viewModel.searchChannels) { channel in
                                Button {
                                    Task { await viewModel.playChannel(channel) }
                                } label: {
                                    SearchChannelRow(channel: channel, host: appState.currentHost)
                                }
                                .buttonStyle(.plain)
                                .listRowBackground(Color.clear)
                            }
                        }
                    }

                    // Movies Section
                    if !viewModel.searchMovies.isEmpty {
                        Section("Movies") {
                            ForEach(viewModel.searchMovies) { movie in
                                NavigationLink(value: movie) {
                                    SearchMovieRow(movie: movie, host: appState.currentHost)
                                }
                                .listRowBackground(Color.clear)
                            }
                        }
                    }

                    // TV Shows Section
                    if !viewModel.searchTVShows.isEmpty {
                        Section("TV Shows") {
                            ForEach(viewModel.searchTVShows) { show in
                                NavigationLink(value: show) {
                                    SearchTVShowRow(show: show, host: appState.currentHost)
                                }
                                .listRowBackground(Color.clear)
                            }
                        }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
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
                                clearlogoPath: movie.clearlogoPath,
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
                                clearlogoPath: nil,
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
    let clearlogoPath: String?
    let progress: Double
    let host: KodiHost?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack {
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
                    colors: [.black.opacity(0.3), .black.opacity(0.8)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .clipShape(RoundedRectangle(cornerRadius: 12))

                // Clearlogo centered (vertically and horizontally)
                if let clearlogoPath = clearlogoPath {
                    AsyncArtworkImage(path: clearlogoPath, host: host)
                        .frame(height: 50)
                        .frame(maxWidth: 200)
                }

                // Subtitle and progress at bottom
                VStack(alignment: .leading, spacing: 6) {
                    Spacer()

                    if clearlogoPath == nil {
                        Text(title)
                            .font(.headline)
                            .foregroundStyle(.white)
                            .lineLimit(1)
                    }

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
                .frame(maxWidth: .infinity, alignment: .leading)
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
                // Background artwork
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

    var body: some View {
        Group {
            if isLoading {
                VStack(spacing: 12) {
                    ProgressView()
                    Text("Loading show...")
                        .foregroundStyle(.secondary)
                }
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

// MARK: - Search Row Views

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
            // Channel icon
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

                // Now playing
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

            // Recording indicator
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

// MARK: - TV Show Detail Wrapper (for search results)

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

#Preview {
    DashboardTab()
        .environment(AppState())
}
