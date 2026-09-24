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
                } else if !viewModel.isInitialLoad && !viewModel.hasContinueWatching && !viewModel.hasRecentlyAdded {
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
                            } else if viewModel.isLoadingInProgress {
                                continueWatchingSkeleton
                            }

                            // Recently Added Movies
                            if !viewModel.recentMovies.isEmpty {
                                recentMoviesSection
                            } else if viewModel.isLoadingRecent {
                                recentMoviesSkeleton
                            }

                            // Recently Added Shows
                            if !viewModel.recentShows.isEmpty {
                                recentShowsSection
                            } else if viewModel.isLoadingRecent {
                                recentShowsSkeleton
                            }
                        }
                        .padding(.vertical)
                        .animation(.easeInOut(duration: 0.3), value: viewModel.hasContinueWatching)
                        .animation(.easeInOut(duration: 0.3), value: viewModel.recentMovies.isEmpty)
                        .animation(.easeInOut(duration: 0.3), value: viewModel.recentShows.isEmpty)
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
        .onChange(of: appState.libraryUpdateSignal) { _, _ in
            Task {
                await viewModel.loadRecentlyAdded()
            }
        }
    }

    // MARK: - Search Results

    private var searchResultsView: some View {
        Group {
            if viewModel.isSearching {
                LoadingPlaceholder(message: "Searching...")
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
    // MARK: - Section Skeletons

    private var continueWatchingSkeleton: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Continue Watching")
                .font(.title2)
                .fontWeight(.bold)
                .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(0..<3, id: \.self) { _ in
                        RoundedRectangle(cornerRadius: DesignSystem.Radius.button)
                            .fill(Color(.secondarySystemFill))
                            .aspectRatio(16/9, contentMode: .fit)
                            .frame(width: 280)
                    }
                }
                .padding(.horizontal)
            }
        }
        .redacted(reason: .placeholder)
    }

    private var recentMoviesSkeleton: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recently Added Movies")
                .font(.title2)
                .fontWeight(.bold)
                .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(0..<5, id: \.self) { _ in
                        VStack(alignment: .leading, spacing: 8) {
                            RoundedRectangle(cornerRadius: DesignSystem.Radius.thumbnail)
                                .fill(Color(.secondarySystemFill))
                                .aspectRatio(2/3, contentMode: .fit)
                                .frame(width: 120)

                            VStack(alignment: .leading, spacing: 4) {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color(.tertiarySystemFill))
                                    .frame(width: 100, height: 12)
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color(.tertiarySystemFill))
                                    .frame(width: 50, height: 10)
                            }
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
        .redacted(reason: .placeholder)
    }

    private var recentShowsSkeleton: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recently Added Shows")
                .font(.title2)
                .fontWeight(.bold)
                .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(0..<4, id: \.self) { _ in
                        VStack(alignment: .leading, spacing: 8) {
                            RoundedRectangle(cornerRadius: DesignSystem.Radius.thumbnail)
                                .fill(Color(.secondarySystemFill))
                                .aspectRatio(16/9, contentMode: .fit)
                                .frame(width: 200)

                            VStack(alignment: .leading, spacing: 4) {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color(.tertiarySystemFill))
                                    .frame(width: 140, height: 12)
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color(.tertiarySystemFill))
                                    .frame(width: 70, height: 10)
                            }
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
        .redacted(reason: .placeholder)
    }
}

#Preview {
    DashboardTab()
        .environment(AppState())
}
