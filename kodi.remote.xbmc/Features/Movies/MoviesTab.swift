//
//  MoviesTab.swift
//  kodi.remote.xbmc
//

import SwiftUI

struct MoviesTab: View {
    @Environment(AppState.self) private var appState
    @State private var libraryState = LibraryState()
    @State private var viewModel = MoviesViewModel()
    @State private var searchText = ""
    @State private var showingFilterSheet = false
    @AppStorage(AppStorageKeys.moviesViewMode) private var viewMode: ViewMode = .grid
    @AppStorage(AppStorageKeys.movieSortField) private var savedSortField: LibraryState.SortField = .title
    @AppStorage(AppStorageKeys.movieSortAscending) private var savedSortAscending = true
    @AppStorage(AppStorageKeys.movieFilter) private var savedFilter: LibraryState.LibraryFilter = .all
    @AppStorage(AppStorageKeys.movieGenreFilter) private var savedGenreFilter = ""
    @AppStorage(AppStorageKeys.showLibraryCounts) private var showLibraryCounts = true

    private let columns = [
        GridItem(.adaptive(minimum: 150), spacing: 16)
    ]

    var body: some View {
        NavigationStack {
            Group {
                if libraryState.isLoadingMovies && libraryState.movies.isEmpty {
                    VStack(spacing: 12) {
                        ProgressView()
                        Text("Loading Movies...")
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let error = libraryState.moviesError {
                    ContentUnavailableView {
                        Label("Error", systemImage: "exclamationmark.triangle")
                    } description: {
                        Text(error)
                    } actions: {
                        Button("Retry") {
                            Task { await viewModel.loadMovies() }
                        }
                    }
                } else if filteredMovies.isEmpty {
                    if !searchText.isEmpty {
                        ContentUnavailableView.search(text: searchText)
                    } else if hasActiveFilters {
                        ContentUnavailableView {
                            Label("No Results", systemImage: "line.3.horizontal.decrease.circle")
                        } description: {
                            Text("No movies match the current filters")
                        } actions: {
                            Button("Clear Filters") {
                                libraryState.movieFilter = .all
                                libraryState.selectedMovieGenres = []
                                savedFilter = .all
                                savedGenreFilter = ""
                            }
                        }
                    } else {
                        ContentUnavailableView {
                            Label("No Movies", systemImage: "film")
                        } description: {
                            Text("Your movie library is empty")
                        }
                    }
                } else {
                    if viewMode == .grid {
                        movieGrid
                    } else {
                        movieList
                    }
                }
            }
            .redacted(reason: libraryState.isLoadingMovies && !libraryState.movies.isEmpty ? .placeholder : [])
            .allowsHitTesting(!libraryState.isLoadingMovies || libraryState.movies.isEmpty)
            .animation(.easeInOut(duration: 0.2), value: libraryState.isLoadingMovies)
            .navigationTitle(showLibraryCounts ? "Movies (\(filteredMovies.count))" : "Movies")
            .searchable(text: $searchText, prompt: "Search movies")
            .refreshable {
                await viewModel.loadMovies(forceRefresh: true)
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
                // Persist on dismiss
                savedSortField = libraryState.movieSortField
                savedSortAscending = libraryState.movieSortAscending
                savedFilter = libraryState.movieFilter
                savedGenreFilter = libraryState.selectedMovieGenres.sorted().joined(separator: ",")
            } content: {
                LibraryFilterSheet(
                    sortField: $libraryState.movieSortField,
                    sortAscending: $libraryState.movieSortAscending,
                    watchFilter: $libraryState.movieFilter,
                    selectedGenres: $libraryState.selectedMovieGenres,
                    availableGenres: libraryState.availableMovieGenres,
                    onShuffle: { libraryState.shuffleMovies() }
                )
                .presentationDetents([.medium, .large])
            }
        }
        .task {
            libraryState.movieSortField = savedSortField
            libraryState.movieSortAscending = savedSortAscending
            libraryState.movieFilter = savedFilter
            if !savedGenreFilter.isEmpty {
                libraryState.selectedMovieGenres = Set(savedGenreFilter.split(separator: ",").map(String.init))
            }
            viewModel.configure(appState: appState, libraryState: libraryState)
            await viewModel.loadMovies()
        }
        .onChange(of: appState.currentHost?.id) { _, _ in
            // Host changed - reconfigure client and reload
            libraryState.movies = []
            libraryState.moviesError = nil
            viewModel.configure(appState: appState, libraryState: libraryState)
            Task {
                await viewModel.loadMovies(forceRefresh: true)
            }
        }
        .onChange(of: appState.libraryUpdateSignal) { _, _ in
            Task {
                await viewModel.loadMovies(forceRefresh: true)
            }
        }
    }

    private var movieGrid: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(filteredMovies) { movie in
                    NavigationLink(value: movie) {
                        MoviePosterCard(movie: movie, host: appState.currentHost)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
        }
        .navigationDestination(for: Movie.self) { movie in
            MovieDetailView(movie: movie, viewModel: viewModel)
        }
    }

    private var movieList: some View {
        List {
            ForEach(filteredMovies) { movie in
                NavigationLink(value: movie) {
                    MovieListRow(movie: movie, host: appState.currentHost)
                }
                .listRowBackground(Color.clear)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .navigationDestination(for: Movie.self) { movie in
            MovieDetailView(movie: movie, viewModel: viewModel)
        }
    }

    private var hasActiveFilters: Bool {
        libraryState.movieFilter != .all || !libraryState.selectedMovieGenres.isEmpty
    }

    private var filteredMovies: [Movie] {
        let movies = libraryState.filteredMovies
        if searchText.isEmpty {
            return movies
        }
        return movies.filter {
            $0.title.localizedCaseInsensitiveContains(searchText) ||
            ($0.genre?.joined(separator: " ").localizedCaseInsensitiveContains(searchText) ?? false) ||
            ($0.director?.joined(separator: " ").localizedCaseInsensitiveContains(searchText) ?? false)
        }
    }

}

// MARK: - Movie Poster Card

struct MoviePosterCard: View {
    let movie: Movie
    let host: KodiHost?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .topTrailing) {
                Color.clear
                    .aspectRatio(2/3, contentMode: .fit)
                    .overlay {
                        AsyncArtworkImage(path: movie.posterPath, host: host)
                    }
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                if movie.isWatched {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.white)
                        .background(Circle().fill(.green))
                        .padding(8)
                        .accessibilityLabel("Watched")
                }

                if movie.hasResume {
                    VStack {
                        Spacer()
                        ProgressView(value: movie.resume?.progress ?? 0)
                            .tint(.white)
                            .background(.black.opacity(0.5))
                            .accessibilityLabel("Watched progress")
                            .accessibilityValue("\(Int((movie.resume?.progress ?? 0) * 100)) percent")
                    }
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(movie.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(2, reservesSpace: true)
                    .frame(maxWidth: .infinity, alignment: .leading)

                HStack(spacing: 4) {
                    if let year = movie.year {
                        Text(String(year))
                    }
                    if let rating = movie.formattedRating {
                        Text("•")
                        Image(systemName: "star.fill")
                            .font(.caption2)
                        Text(rating)
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Movie List Row

struct MovieListRow: View {
    let movie: Movie
    let host: KodiHost?

    var body: some View {
        HStack(spacing: 12) {
            AsyncArtworkImage(path: movie.posterPath, host: host)
                .frame(width: 60, height: 90)
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

                if let genres = movie.genreText {
                    Text(genres)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            if movie.isWatched {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .accessibilityLabel("Watched")
            } else if movie.hasResume {
                CircularProgressView(progress: movie.resume?.progress ?? 0)
                    .frame(width: 24, height: 24)
                    .accessibilityLabel("Watched progress")
                    .accessibilityValue("\(Int((movie.resume?.progress ?? 0) * 100)) percent")
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Circular Progress View

struct CircularProgressView: View {
    let progress: Double

    var body: some View {
        ZStack {
            Circle()
                .stroke(.secondary.opacity(0.3), lineWidth: 3)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(.blue, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
    }
}

// MARK: - View Mode

enum ViewMode: String {
    case grid
    case list
}

#Preview {
    MoviesTab()
        .environment(AppState())
}
