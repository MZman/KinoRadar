import SwiftUI

struct InterestedMoviesView: View {
    enum SortOption: String, CaseIterable, Identifiable {
        case alphabetical = "Alphabetisch"
        case releaseDate = "Release-Datum"

        var id: String { rawValue }
    }

    @EnvironmentObject private var store: MovieStore
    @State private var sortOption: SortOption = .alphabetical

    private var sortedMovies: [Movie] {
        switch sortOption {
        case .alphabetical:
            return store.interestedMovies.sorted {
                $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
            }
        case .releaseDate:
            return store.interestedMovies.sorted { lhs, rhs in
                switch (lhs.releaseDate, rhs.releaseDate) {
                case let (left?, right?):
                    return left < right
                case (_?, nil):
                    return true
                case (nil, _?):
                    return false
                case (nil, nil):
                    return lhs.title < rhs.title
                }
            }
        }
    }

    var body: some View {
        List {
            Section {
                Picker("Sortierung", selection: $sortOption) {
                    ForEach(SortOption.allCases) { option in
                        Text(option.rawValue)
                            .tag(option)
                    }
                }
                .pickerStyle(.segmented)
            }

            if sortedMovies.isEmpty {
                Section {
                    ContentUnavailableView(
                        "Noch keine Filme markiert",
                        systemImage: "film.stack",
                        description: Text("Markiere Filme im Tab Kino, damit sie hier erscheinen.")
                    )
                }
            } else {
                Section("Meine Filme") {
                    ForEach(sortedMovies) { movie in
                        NavigationLink {
                            MovieInfoView(movie: movie, genreText: genreText(for: movie))
                        } label: {
                            HStack(alignment: .top, spacing: 12) {
                                InterestedPosterThumbnailView(url: movie.posterURL)

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(movie.title)
                                        .font(.headline)
                                        .lineLimit(2)

                                    Text("Release: \(movie.releaseDateText)")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)

                                    Text("Genre: \(genreText(for: movie))")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(2)

                                    let feedback = store.feedback(for: movie.id)
                                    if feedback.rating > 0 {
                                        Text("Bewertung: \(feedback.rating) / 5")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .padding(.top, 2)
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }
            }
        }
        .navigationTitle("Meine Liste")
    }

    private func genreText(for movie: Movie) -> String {
        let names = store.genreNames(for: movie)
        if names.isEmpty {
            return "Unbekannt"
        }
        return names.joined(separator: ", ")
    }
}

private struct InterestedPosterThumbnailView: View {
    let url: URL?

    var body: some View {
        AsyncImage(url: url) { phase in
            switch phase {
            case .success(let image):
                image
                    .resizable()
                    .scaledToFill()
            case .empty:
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(.systemGray5))
                    ProgressView()
                }
            case .failure:
                fallbackPoster
            @unknown default:
                fallbackPoster
            }
        }
        .frame(width: 60, height: 86)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var fallbackPoster: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(.systemGray5))
            Image(systemName: "film")
                .foregroundStyle(.secondary)
        }
    }
}
