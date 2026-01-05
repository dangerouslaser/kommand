//
//  MovieDetailView.swift
//  kodi.remote.xbmc
//

import SwiftUI

struct MovieDetailView: View {
    let movie: Movie
    let viewModel: MoviesViewModel
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.colorScheme) private var colorScheme

    private var isIPad: Bool {
        horizontalSizeClass == .regular
    }

    private var gradientColor: Color {
        colorScheme == .dark ? .black : .white
    }

    private func hasMediaTags(_ stream: StreamDetails) -> Bool {
        stream.primaryVideo?.resolutionLabel != nil ||
        stream.primaryVideo?.hdrBadge != nil ||
        stream.primaryVideo?.codecLabel != nil ||
        stream.primaryAudio?.displayLabel != nil
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Hero Image with overlay content on iPad
                GeometryReader { geo in
                    ZStack(alignment: .bottomLeading) {
                        AsyncArtworkImage(path: movie.fanartPath ?? movie.posterPath, host: appState.currentHost)
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

                    // Action buttons
                    HStack(spacing: 12) {
                        if movie.hasResume {
                            Button {
                                Task { await viewModel.playMovie(movie, resume: true) }
                            } label: {
                                Label("Resume", systemImage: "play.fill")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)

                            Button {
                                Task { await viewModel.playMovie(movie, resume: false) }
                            } label: {
                                Label("Start Over", systemImage: "arrow.counterclockwise")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                        } else {
                            Button {
                                Task { await viewModel.playMovie(movie, resume: false) }
                            } label: {
                                Label("Play", systemImage: "play.fill")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    }

                    // Secondary actions
                    HStack(spacing: 12) {
                        Button {
                            Task { await viewModel.queueMovie(movie) }
                        } label: {
                            Label("Queue", systemImage: "text.badge.plus")
                        }
                        .buttonStyle(.bordered)

                        Button {
                            Task { await viewModel.toggleWatched(movie) }
                        } label: {
                            Label(
                                movie.isWatched ? "Mark Unwatched" : "Mark Watched",
                                systemImage: movie.isWatched ? "eye.slash" : "eye"
                            )
                        }
                        .buttonStyle(.bordered)

                        Spacer()
                    }

                    // Tagline
                    if let tagline = movie.tagline, !tagline.isEmpty {
                        Text(tagline)
                            .font(.subheadline)
                            .italic()
                            .foregroundStyle(.secondary)
                    }

                    // Plot
                    if let plot = movie.plot, !plot.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Plot")
                                .font(.headline)
                            Text(plot)
                                .font(.body)
                                .foregroundStyle(.secondary)
                        }
                    }

                    // Director
                    if let directors = movie.directorText {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Director")
                                .font(.headline)
                            Text(directors)
                                .font(.body)
                                .foregroundStyle(.secondary)
                        }
                    }

                    // Cast
                    if let cast = movie.cast, !cast.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Cast")
                                .font(.headline)

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    ForEach(cast.prefix(10)) { member in
                                        NavigationLink(value: member) {
                                            CastMemberCard(member: member, host: appState.currentHost)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                        }
                    }
                }
                .padding()
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .ignoresSafeArea(edges: .top)
        .navigationDestination(for: CastMember.self) { member in
            ActorFilmographyView(actor: member, viewModel: viewModel)
        }
    }

    // MARK: - Hero Overlay (iPad)

    private var heroOverlayContent: some View {
        VStack(alignment: .leading, spacing: isIPad ? 12 : 8) {
            // Clearlogo or title
            if let clearlogo = movie.clearlogoPath {
                AsyncArtworkImage(path: clearlogo, host: appState.currentHost)
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: isIPad ? 450 : 280, maxHeight: isIPad ? 140 : 80, alignment: .leading)
            } else {
                Text(movie.title)
                    .font(.system(size: isIPad ? 42 : 28, weight: .bold))
                    .shadow(color: .black.opacity(0.7), radius: 4, x: 0, y: 2)
            }

            // Metadata row
            HStack(spacing: isIPad ? 16 : 12) {
                if let year = movie.year {
                    Text(String(year))
                }
                if let runtime = movie.formattedRuntime {
                    Text(runtime)
                }
                if let rating = movie.formattedRating {
                    HStack(spacing: 4) {
                        Image(systemName: "star.fill")
                            .foregroundStyle(.yellow)
                        Text(rating)
                    }
                }
                if let mpaa = movie.mpaa, !mpaa.isEmpty {
                    Text(mpaa)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.white.opacity(0.2), in: RoundedRectangle(cornerRadius: 4))
                }
            }
            .font(isIPad ? .headline : .subheadline)

            if let genres = movie.genreText {
                Text(genres)
                    .font(isIPad ? .subheadline : .caption)
            }

            // Media Tags
            if let stream = movie.streamdetails, hasMediaTags(stream) {
                MediaTagsView(streamDetails: stream)
            }
        }
        .foregroundStyle(colorScheme == .dark ? .white : .black)
    }

    // MARK: - Title and Metadata (iPhone)

    private var titleAndMetadata: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Clearlogo or title
            if let clearlogo = movie.clearlogoPath {
                AsyncArtworkImage(path: clearlogo, host: appState.currentHost)
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: 280, maxHeight: 80, alignment: .leading)
            } else {
                Text(movie.title)
                    .font(.title)
                    .fontWeight(.bold)
            }

            HStack(spacing: 12) {
                if let year = movie.year {
                    Text(String(year))
                }
                if let runtime = movie.formattedRuntime {
                    Text(runtime)
                }
                if let rating = movie.formattedRating {
                    HStack(spacing: 4) {
                        Image(systemName: "star.fill")
                            .foregroundStyle(.yellow)
                        Text(rating)
                    }
                }
                if let mpaa = movie.mpaa, !mpaa.isEmpty {
                    Text(mpaa)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.secondary.opacity(0.2), in: RoundedRectangle(cornerRadius: 4))
                }
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)

            if let genres = movie.genreText {
                Text(genres)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            // Media Tags
            if let stream = movie.streamdetails, hasMediaTags(stream) {
                MediaTagsView(streamDetails: stream)
            }
        }
    }
}

// MARK: - Actor Filmography View

struct ActorFilmographyView: View {
    let actor: CastMember
    let viewModel: MoviesViewModel
    @Environment(AppState.self) private var appState

    private let columns = [GridItem(.adaptive(minimum: 150), spacing: 16)]

    var body: some View {
        ScrollView {
            if viewModel.isLoadingActorMovies {
                ProgressView("Loading...")
                    .frame(maxWidth: .infinity)
                    .padding(.top, 60)
            } else if viewModel.actorMovies.isEmpty {
                ContentUnavailableView {
                    Label("No Movies Found", systemImage: "film")
                } description: {
                    Text("No movies featuring \(actor.name) were found in your library")
                }
                .padding(.top, 60)
            } else {
                VStack(alignment: .leading, spacing: 16) {
                    // Actor header
                    HStack(spacing: 16) {
                        AsyncArtworkImage(path: actor.thumbnail, host: appState.currentHost)
                            .frame(width: 80, height: 80)
                            .clipShape(Circle())

                        VStack(alignment: .leading, spacing: 4) {
                            Text(actor.name)
                                .font(.title2)
                                .fontWeight(.bold)

                            Text("\(viewModel.actorMovies.count) movie\(viewModel.actorMovies.count == 1 ? "" : "s") in library")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()
                    }
                    .padding(.horizontal)

                    // Movies grid
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(viewModel.actorMovies) { movie in
                            NavigationLink {
                                MovieDetailView(movie: movie, viewModel: viewModel)
                            } label: {
                                ActorMovieCard(movie: movie, actorRole: roleForActor(in: movie), host: appState.currentHost)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
        }
        .navigationTitle(actor.name)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.loadMoviesByActor(actor.name)
        }
    }

    private func roleForActor(in movie: Movie) -> String? {
        movie.cast?.first { $0.name == actor.name }?.role
    }
}

struct ActorMovieCard: View {
    let movie: Movie
    let actorRole: String?
    let host: KodiHost?

    private var accessibilityDescription: String {
        var description = movie.title
        if let year = movie.year {
            description += ", \(year)"
        }
        if let role = actorRole, !role.isEmpty {
            description += ", as \(role)"
        }
        if movie.isWatched {
            description += ", watched"
        }
        return description
    }

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
                        .background(Circle().fill(.green).padding(-2))
                        .padding(8)
                        .accessibilityHidden(true)
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(movie.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(2)

                HStack(spacing: 4) {
                    if let year = movie.year {
                        Text(String(year))
                    }
                    if let role = actorRole, !role.isEmpty {
                        Text("•")
                        Text(role)
                            .lineLimit(1)
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityDescription)
    }
}

struct CastMemberCard: View {
    let member: CastMember
    let host: KodiHost?

    private var accessibilityDescription: String {
        if let role = member.role, !role.isEmpty {
            return "\(member.name) as \(role)"
        }
        return member.name
    }

    var body: some View {
        VStack(spacing: 4) {
            AsyncArtworkImage(path: member.thumbnail, host: host)
                .frame(width: 80, height: 80)
                .clipShape(Circle())

            Text(member.name)
                .font(.caption)
                .fontWeight(.medium)
                .lineLimit(1)

            if let role = member.role {
                Text(role)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .frame(width: 90)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityDescription)
        .accessibilityHint("Tap to see filmography")
    }
}

// MARK: - Media Tags View

struct MediaTagsView: View {
    let streamDetails: StreamDetails

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                // Resolution
                if let resolution = streamDetails.primaryVideo?.resolutionLabel {
                    MediaTagBadge(text: resolution, icon: "tv", color: .blue, accessibilityLabel: "Resolution: \(resolution)")
                }

                // HDR
                if let hdr = streamDetails.primaryVideo?.hdrBadge {
                    MediaTagBadge(text: hdr, icon: "sun.max.fill", color: .orange, accessibilityLabel: "HDR format: \(hdr)")
                }

                // Video Codec
                if let videoCodec = streamDetails.primaryVideo?.codecLabel {
                    MediaTagBadge(text: videoCodec, icon: "film", color: .purple, accessibilityLabel: "Video codec: \(videoCodec)")
                }

                // Audio
                if let audio = streamDetails.primaryAudio?.displayLabel {
                    MediaTagBadge(text: audio, icon: "speaker.wave.3.fill", color: .green, accessibilityLabel: "Audio: \(audio)")
                }

                // Subtitles count
                if let subs = streamDetails.subtitle, !subs.isEmpty {
                    MediaTagBadge(text: "\(subs.count) Subs", icon: "captions.bubble", color: .secondary, accessibilityLabel: "\(subs.count) subtitle tracks available")
                }
            }
        }
    }
}

struct MediaTagBadge: View {
    let text: String
    var icon: String? = nil
    var color: Color = .secondary
    var accessibilityLabel: String? = nil

    var body: some View {
        HStack(spacing: 4) {
            if let icon = icon {
                Image(systemName: icon)
                    .font(.caption2)
            }
            Text(text)
                .font(.caption)
                .fontWeight(.medium)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(color.opacity(0.15), in: RoundedRectangle(cornerRadius: 8))
        .foregroundStyle(color)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel ?? text)
    }
}

#Preview {
    NavigationStack {
        MovieDetailView(
            movie: Movie(
                movieid: 1,
                title: "The Matrix",
                year: 1999,
                runtime: 8160,
                rating: 8.7,
                plot: "A computer hacker learns from mysterious rebels about the true nature of his reality and his role in the war against its controllers.",
                genre: ["Action", "Sci-Fi"],
                director: ["Lana Wachowski", "Lilly Wachowski"],
                writer: nil,
                studio: ["Warner Bros."],
                tagline: "The fight for the future begins.",
                cast: [
                    CastMember(name: "Keanu Reeves", role: "Neo", thumbnail: nil, order: 0),
                    CastMember(name: "Laurence Fishburne", role: "Morpheus", thumbnail: nil, order: 1)
                ],
                thumbnail: nil,
                fanart: nil,
                art: nil,
                playcount: 1,
                resume: nil,
                file: nil,
                trailer: nil,
                mpaa: "R",
                imdbnumber: "tt0133093",
                dateadded: nil,
                lastplayed: nil,
                streamdetails: StreamDetails(
                    video: [VideoStream(codec: "hevc", aspect: 2.4, width: 3840, height: 2160, duration: 8160, stereomode: nil, hdrtype: "dolbyvision")],
                    audio: [AudioStreamDetail(codec: "truehd", channels: 8, language: "eng")],
                    subtitle: [SubtitleStream(language: "eng"), SubtitleStream(language: "spa")]
                )
            ),
            viewModel: MoviesViewModel()
        )
    }
    .environment(AppState())
}
