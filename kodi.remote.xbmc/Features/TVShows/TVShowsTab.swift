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
    @AppStorage("tvShowsViewMode") private var viewMode: ViewMode = .grid

    private let columns = [
        GridItem(.adaptive(minimum: 150), spacing: 16)
    ]

    var body: some View {
        NavigationStack {
            Group {
                if libraryState.isLoadingTVShows && libraryState.tvShows.isEmpty {
                    ProgressView("Loading TV Shows...")
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
                    if searchText.isEmpty {
                        ContentUnavailableView {
                            Label("No TV Shows", systemImage: "tv")
                        } description: {
                            Text("Your TV library is empty")
                        }
                    } else {
                        ContentUnavailableView.search(text: searchText)
                    }
                } else {
                    if viewMode == .grid {
                        showsGrid
                    } else {
                        showsList
                    }
                }
            }
            .navigationTitle("TV Shows")
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
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        sortMenu
                        Divider()
                        filterMenu
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                    }
                }
            }
        }
        .task {
            viewModel.configure(appState: appState, libraryState: libraryState)
            await viewModel.loadTVShows()
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
        List(filteredShows) { show in
            NavigationLink(value: show) {
                TVShowListRow(show: show, host: appState.currentHost)
            }
        }
        .listStyle(.plain)
        .navigationDestination(for: TVShow.self) { show in
            TVShowDetailView(show: show, viewModel: viewModel)
        }
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

    private var sortMenu: some View {
        Menu("Sort By") {
            ForEach(LibraryState.SortField.allCases, id: \.self) { field in
                Button {
                    if libraryState.tvShowSortField == field {
                        libraryState.tvShowSortAscending.toggle()
                    } else {
                        libraryState.tvShowSortField = field
                        libraryState.tvShowSortAscending = true
                    }
                    Task { await viewModel.loadTVShows(forceRefresh: true) }
                } label: {
                    HStack {
                        Text(field.displayName)
                        if libraryState.tvShowSortField == field {
                            Image(systemName: libraryState.tvShowSortAscending ? "chevron.up" : "chevron.down")
                        }
                    }
                }
            }
        }
    }

    private var filterMenu: some View {
        Menu("Filter") {
            ForEach(LibraryState.LibraryFilter.allCases, id: \.self) { filter in
                Button {
                    libraryState.tvShowFilter = filter
                } label: {
                    HStack {
                        Text(filter.displayName)
                        if libraryState.tvShowFilter == filter {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
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
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                if show.isFullyWatched {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.white)
                        .background(Circle().fill(.green))
                        .padding(8)
                } else if show.unwatchedCount > 0 {
                    Text("\(show.unwatchedCount)")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.blue, in: Capsule())
                        .padding(8)
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
            } else if show.unwatchedCount > 0 {
                Text("\(show.unwatchedCount)")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.blue, in: Capsule())
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    TVShowsTab()
        .environment(AppState())
}
