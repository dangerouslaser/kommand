//
//  TVShowsTab.swift
//  kodi.remote.xbmc
//

import SwiftUI

struct TVShowsTab: View {
    @Environment(AppState.self) private var appState
    @State private var libraryState = LibraryState()
    @State private var viewModel = TVShowsViewModel()
    @State private var searchText = ""
    @State private var showingFilterSheet = false
    @AppStorage(AppStorageKeys.tvShowsViewMode) private var viewMode: ViewMode = .grid
    @AppStorage(AppStorageKeys.tvShowSortField) private var savedSortField: LibraryState.SortField = .title
    @AppStorage(AppStorageKeys.tvShowSortAscending) private var savedSortAscending = true
    @AppStorage(AppStorageKeys.tvShowFilter) private var savedFilter: LibraryState.LibraryFilter = .all
    @AppStorage(AppStorageKeys.tvShowGenreFilter) private var savedGenreFilter = ""
    @AppStorage(AppStorageKeys.showLibraryCounts) private var showLibraryCounts = true

    private let columns = [
        GridItem(.adaptive(minimum: 150), spacing: 16)
    ]

    var body: some View {
        NavigationStack {
            Group {
                if libraryState.isLoadingTVShows && libraryState.tvShows.isEmpty {
                    if viewMode == .grid {
                        LibraryGridSkeleton(columns: columns)
                    } else {
                        LibraryListSkeleton()
                    }
                } else if let error = libraryState.tvShowsError {
                    ContentUnavailableView {
                        Label("Error", systemImage: "exclamationmark.triangle")
                    } description: {
                        Text(error)
                    } actions: {
                        Button("Retry") {
                            Task { await viewModel.loadTVShows() }
                        }
                    }
                } else if filteredShows.isEmpty {
                    if !searchText.isEmpty {
                        ContentUnavailableView.search(text: searchText)
                    } else if hasActiveFilters {
                        ContentUnavailableView {
                            Label("No Results", systemImage: "line.3.horizontal.decrease.circle")
                        } description: {
                            Text("No shows match the current filters")
                        } actions: {
                            Button("Clear Filters") {
                                libraryState.tvShowFilter = .all
                                libraryState.selectedTVShowGenres = []
                                savedFilter = .all
                                savedGenreFilter = ""
                            }
                        }
                    } else {
                        ContentUnavailableView {
                            Label("No TV Shows", systemImage: "tv")
                        } description: {
                            Text("Your TV library is empty")
                        }
                    }
                } else {
                    if viewMode == .grid {
                        showsGrid
                    } else {
                        showsList
                    }
                }
            }
            .redacted(reason: libraryState.isLoadingTVShows && !libraryState.tvShows.isEmpty ? .placeholder : [])
            .allowsHitTesting(!libraryState.isLoadingTVShows || libraryState.tvShows.isEmpty)
            .animation(.easeInOut(duration: 0.2), value: libraryState.isLoadingTVShows)
            .navigationTitle(showLibraryCounts ? "TV Shows (\(filteredShows.count))" : "TV Shows")
            .searchable(text: $searchText, prompt: "Search TV shows")
            .refreshable {
                await viewModel.loadTVShows(forceRefresh: true)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            viewMode = viewMode == .grid ? .list : .grid
                        }
                    } label: {
                        Image(systemName: viewMode == .grid ? "list.bullet" : "square.grid.2x2")
                    }
                    .accessibilityLabel(viewMode == .grid ? "Switch to list view" : "Switch to grid view")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingFilterSheet = true
                    } label: {
                        Image(systemName: hasActiveFilters
                              ? "line.3.horizontal.decrease.circle.fill"
                              : "line.3.horizontal.decrease.circle")
                    }
                    .accessibilityLabel("Sort and filter")
                }
            }
            .themedBackground()
            .sheet(isPresented: $showingFilterSheet) {
                savedSortField = libraryState.tvShowSortField
                savedSortAscending = libraryState.tvShowSortAscending
                savedFilter = libraryState.tvShowFilter
                savedGenreFilter = libraryState.selectedTVShowGenres.sorted().joined(separator: ",")
            } content: {
                LibraryFilterSheet(
                    sortField: $libraryState.tvShowSortField,
                    sortAscending: $libraryState.tvShowSortAscending,
                    watchFilter: $libraryState.tvShowFilter,
                    selectedGenres: $libraryState.selectedTVShowGenres,
                    availableGenres: libraryState.availableTVShowGenres,
                    onShuffle: { libraryState.shuffleTVShows() }
                )
                .presentationDetents([.medium, .large])
            }
        }
        .task {
            libraryState.tvShowSortField = savedSortField
            libraryState.tvShowSortAscending = savedSortAscending
            libraryState.tvShowFilter = savedFilter
            if !savedGenreFilter.isEmpty {
                libraryState.selectedTVShowGenres = Set(savedGenreFilter.split(separator: ",").map(String.init))
            }
            viewModel.configure(appState: appState, libraryState: libraryState)
            await viewModel.loadTVShows()
        }
        .onChange(of: appState.currentHost?.id) { _, _ in
            // Host changed - reconfigure client and reload
            libraryState.reset()
            viewModel.configure(appState: appState, libraryState: libraryState)
            Task {
                await viewModel.loadTVShows(forceRefresh: true)
            }
        }
        .onChange(of: appState.libraryUpdateSignal) { _, _ in
            Task {
                await viewModel.loadTVShows(forceRefresh: true)
            }
        }
    }

    private var showsGrid: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(filteredShows) { show in
                    NavigationLink(value: show) {
                        TVShowPosterCard(show: show, host: appState.currentHost)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
        }
        .navigationDestination(for: TVShow.self) { show in
            TVShowDetailView(show: show, viewModel: viewModel)
        }
    }

    private var showsList: some View {
        List {
            ForEach(filteredShows) { show in
                NavigationLink(value: show) {
                    TVShowListRow(show: show, host: appState.currentHost)
                }
                .listRowBackground(Color.clear)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .navigationDestination(for: TVShow.self) { show in
            TVShowDetailView(show: show, viewModel: viewModel)
        }
    }

    private var hasActiveFilters: Bool {
        libraryState.tvShowFilter != .all || !libraryState.selectedTVShowGenres.isEmpty
    }

    private var filteredShows: [TVShow] {
        let shows = libraryState.filteredTVShows
        if searchText.isEmpty {
            return shows
        }
        return shows.filter {
            $0.title.localizedCaseInsensitiveContains(searchText) ||
            ($0.genre?.joined(separator: " ").localizedCaseInsensitiveContains(searchText) ?? false)
        }
    }

}

// MARK: - TV Show Poster Card

struct TVShowPosterCard: View {
    let show: TVShow
    let host: KodiHost?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .topTrailing) {
                Color.clear
                    .aspectRatio(2/3, contentMode: .fit)
                    .overlay {
                        AsyncArtworkImage(path: show.posterPath, host: host)
                    }
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.thumbnail))

                if show.isFullyWatched {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.white)
                        .background(Circle().fill(.green))
                        .padding(8)
                        .accessibilityLabel("Fully watched")
                } else if show.unwatchedCount > 0 {
                    Text("\(show.unwatchedCount)")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.blue, in: Capsule())
                        .padding(8)
                        .accessibilityLabel("\(show.unwatchedCount) unwatched episodes")
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(show.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(2, reservesSpace: true)
                    .frame(maxWidth: .infinity, alignment: .leading)

                HStack(spacing: 4) {
                    if let year = show.year {
                        Text(String(year))
                    }
                    if let seasons = show.season {
                        Text("•")
                        Text("\(seasons) Seasons")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - TV Show List Row

struct TVShowListRow: View {
    let show: TVShow
    let host: KodiHost?

    var body: some View {
        HStack(spacing: 12) {
            AsyncArtworkImage(path: show.posterPath, host: host)
                .frame(width: 60, height: 90)
                .clipShape(RoundedRectangle(cornerRadius: 6))

            VStack(alignment: .leading, spacing: 4) {
                Text(show.title)
                    .font(.headline)
                    .lineLimit(2)

                HStack(spacing: 8) {
                    if let year = show.year {
                        Text(String(year))
                    }
                    if let seasons = show.season {
                        Text("•")
                        Text("\(seasons) Seasons")
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

                if let genres = show.genreText {
                    Text(genres)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            if show.isFullyWatched {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .accessibilityLabel("Fully watched")
            } else if show.unwatchedCount > 0 {
                Text("\(show.unwatchedCount)")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.blue, in: Capsule())
                    .accessibilityLabel("\(show.unwatchedCount) unwatched episodes")
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    TVShowsTab()
        .environment(AppState())
}
