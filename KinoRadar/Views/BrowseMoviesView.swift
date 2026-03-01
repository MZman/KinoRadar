import SwiftUI

struct BrowseMoviesView: View {
    @EnvironmentObject private var store: MovieStore
    @State private var selectedGenreIDs: Set<Int> = []
    @State private var showGenreFilter = false
    @State private var showMovieSearch = false
    private let gridColumns = Array(
        repeating: GridItem(.flexible(minimum: 88), spacing: 12, alignment: .top),
        count: 3
    )

    private var filteredNowPlaying: [Movie] {
        store.nowPlaying.filter(matchesSelectedGenres)
    }

    private var filteredUpcoming: [Movie] {
        store.upcoming.filter(matchesSelectedGenres)
    }

    private var isGenreFilterActive: Bool {
        !selectedGenreIDs.isEmpty
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                brandedHeader

                if let errorMessage = store.errorMessage {
                    Text(errorMessage)
                        .font(.subheadline)
                        .foregroundStyle(.red)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color.red.opacity(0.08))
                        )
                }

                movieGridSection(title: "Jetzt im Kino", movies: filteredNowPlaying)
                movieGridSection(title: "Demnaechst", movies: filteredUpcoming)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    showMovieSearch = true
                } label: {
                    Image(systemName: "magnifyingglass.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.white)
                        .frame(width: 34, height: 34)
                        .background(Circle().fill(Color.accentColor))
                }
                .accessibilityLabel("Filme suchen")

                Button {
                    showGenreFilter = true
                } label: {
                    Image(systemName: isGenreFilterActive
                        ? "line.3.horizontal.decrease.circle.fill"
                        : "line.3.horizontal.decrease.circle"
                    )
                    .font(.title3)
                    .foregroundStyle(isGenreFilterActive ? .green : .primary)
                    .frame(width: 34, height: 34)
                }
                .accessibilityLabel("Genre-Filter")
            }
        }
        .overlay {
            if store.isLoading {
                ProgressView("Lade Filme ...")
            }
        }
        .sheet(isPresented: $showGenreFilter) {
            GenreFilterSheet(
                genres: store.sortedGenres,
                selectedGenreIDs: $selectedGenreIDs
            )
            .environmentObject(store)
        }
        .sheet(isPresented: $showMovieSearch) {
            MovieSearchSheet()
                .environmentObject(store)
        }
        .task {
            await store.loadMoviesIfNeeded()
        }
        .refreshable {
            await store.refresh()
        }
    }

    @ViewBuilder
    private func movieGridSection(title: String, movies: [Movie]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)
                .padding(.horizontal, 2)

            if movies.isEmpty, !store.isLoading {
                Text("Keine Filme gefunden.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 2)
            } else {
                LazyVGrid(columns: gridColumns, spacing: 14) {
                    ForEach(movies) { movie in
                        MovieGridCard(
                            movie: movie,
                            genreText: genreSummary(for: movie),
                            releaseYear: releaseYearText(for: movie),
                            isInterested: store.isInterested(movie),
                            onToggle: { store.toggleInterested(movie) }
                        )
                    }
                }
            }
        }
    }

    private var brandedHeader: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.systemBackground))
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color(.separator).opacity(0.25), lineWidth: 1)
            Text("MovieFinder")
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .minimumScaleFactor(0.8)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 86)
    }

    private func matchesSelectedGenres(movie: Movie) -> Bool {
        guard !selectedGenreIDs.isEmpty else {
            return true
        }
        return movie.genreIDs.contains(where: { selectedGenreIDs.contains($0) })
    }

    private func genreSummary(for movie: Movie) -> String {
        let names = store.genreNames(for: movie)
        if names.isEmpty {
            return "Unbekannt"
        }
        return names.prefix(2).joined(separator: ", ")
    }

    private func releaseYearText(for movie: Movie) -> String {
        guard let releaseDate = movie.releaseDate else {
            return "Unbekannt"
        }
        return String(Calendar.current.component(.year, from: releaseDate))
    }
}

private struct MovieGridCard: View {
    let movie: Movie
    let genreText: String
    let releaseYear: String
    let isInterested: Bool
    let onToggle: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            NavigationLink(destination: MovieInfoView(movie: movie, genreText: genreText)) {
                VStack(alignment: .leading, spacing: 6) {
                    PosterGridView(url: movie.posterURL)

                    Text(movie.title)
                        .font(.headline)
                        .lineLimit(1)

                    Text(genreText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)

                    Text(releaseYear)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color(.systemBackground))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color(.separator).opacity(0.18), lineWidth: 1)
                )
                .foregroundStyle(.primary)
            }
            .buttonStyle(.plain)

            Button {
                onToggle()
            } label: {
                Image(systemName: isInterested ? "bookmark.circle.fill" : "bookmark.circle")
                    .font(.title2)
                    .foregroundStyle(isInterested ? .green : .gray)
                    .padding(4)
            }
            .buttonStyle(.plain)
            .padding(6)
        }
    }
}

private struct PosterGridView: View {
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
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color(.systemGray5))
                    ProgressView()
                }
            case .failure:
                fallbackPoster
            @unknown default:
                fallbackPoster
            }
        }
        .aspectRatio(2 / 3, contentMode: .fit)
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var fallbackPoster: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(.systemGray5))
            Image(systemName: "film")
                .foregroundStyle(.secondary)
        }
    }
}

private struct PosterThumbnailView: View {
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
        .frame(width: 68, height: 98)
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

private struct GenreFilterSheet: View {
    @EnvironmentObject private var store: MovieStore
    let genres: [Genre]
    @Binding var selectedGenreIDs: Set<Int>

    @Environment(\.dismiss) private var dismiss
    @State private var newPresetName = ""
    @State private var showSaveControls = false
    @State private var selectedWheelGenreID: Int?

    var body: some View {
        NavigationStack {
            List {
                if !store.sortedGenreFilterPresets.isEmpty {
                    Section("Gespeicherte Filter") {
                        ForEach(store.sortedGenreFilterPresets) { preset in
                            HStack {
                                Button {
                                    selectedGenreIDs = Set(preset.genreIDs)
                                    dismiss()
                                } label: {
                                    HStack {
                                        Text(preset.name)
                                        Spacer()
                                        Text("\(preset.genreIDs.count)")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    .foregroundStyle(.primary)
                                }
                                .buttonStyle(.plain)
                            }
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    store.deleteGenreFilterPreset(id: preset.id)
                                } label: {
                                    Label("Loeschen", systemImage: "trash")
                                }
                            }
                        }
                    }
                }

                if showSaveControls {
                    Section("Aktuelle Auswahl speichern") {
                        TextField("Filtername", text: $newPresetName)
                            .textInputAutocapitalization(.words)

                        Button("Auswahl speichern") {
                            store.saveGenreFilterPreset(
                                name: newPresetName,
                                selectedGenreIDs: selectedGenreIDs
                            )
                            newPresetName = ""
                            showSaveControls = false
                        }
                        .disabled(
                            selectedGenreIDs.isEmpty ||
                            newPresetName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        )
                    }
                }

                Section("Genre auswaehlen") {
                    if genres.isEmpty {
                        Text("Keine Genres verfuegbar.")
                            .foregroundStyle(.secondary)
                    } else {
                        Picker("Genre", selection: $selectedWheelGenreID) {
                            ForEach(genres) { genre in
                                Text(genre.name)
                                    .tag(Optional(genre.id))
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(height: 150)

                        if let selectedWheelGenreID {
                            Button(genreToggleTitle(for: selectedWheelGenreID)) {
                                toggleGenreSelection(genreID: selectedWheelGenreID)
                            }
                        }

                        Text(currentSelectionText)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Genre-Filter")
            .toolbar {
                ToolbarItemGroup(placement: .topBarLeading) {
                    Button("Zuruecksetzen") {
                        selectedGenreIDs.removeAll()
                    }
                    Button {
                        showSaveControls.toggle()
                    } label: {
                        Image(systemName: "square.and.arrow.down")
                    }
                    .accessibilityLabel("Speichern einblenden")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fertig") {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .onAppear {
            if selectedWheelGenreID == nil {
                selectedWheelGenreID = genres.first?.id
            }
        }
        .onChange(of: genres) { _, newGenres in
            if selectedWheelGenreID == nil {
                selectedWheelGenreID = newGenres.first?.id
            } else if let selectedWheelGenreID, !newGenres.contains(where: { $0.id == selectedWheelGenreID }) {
                self.selectedWheelGenreID = newGenres.first?.id
            }
        }
    }

    private func toggleGenreSelection(genreID: Int) {
        if selectedGenreIDs.contains(genreID) {
            selectedGenreIDs.remove(genreID)
        } else {
            selectedGenreIDs.insert(genreID)
        }
    }

    private func genreToggleTitle(for genreID: Int) -> String {
        if selectedGenreIDs.contains(genreID) {
            return "Genre entfernen"
        }
        return "Genre auswaehlen"
    }

    private var currentSelectionText: String {
        if selectedGenreIDs.isEmpty {
            return "Aktiv: Alle Genres"
        }
        let lookup = Dictionary(uniqueKeysWithValues: genres.map { ($0.id, $0.name) })
        let names = selectedGenreIDs.compactMap { lookup[$0] }.sorted()
        if names.isEmpty {
            return "Aktiv: Individuelle Auswahl"
        }
        return "Aktiv: \(names.joined(separator: ", "))"
    }
}

private struct MovieSearchSheet: View {
    @EnvironmentObject private var store: MovieStore
    @Environment(\.dismiss) private var dismiss

    @State private var query = ""
    @State private var results: [Movie] = []
    @State private var isSearching = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            List {
                Section("Freitextsuche") {
                    TextField("Filmtitel eingeben", text: $query)
                        .textInputAutocapitalization(.words)
                        .onSubmit {
                            Task {
                                await performSearch()
                            }
                        }

                    Button("Suchen") {
                        Task {
                            await performSearch()
                        }
                    }
                    .disabled(isSearching || trimmedQuery.isEmpty)
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                    }
                }

                if isSearching {
                    Section {
                        ProgressView("Suche laeuft ...")
                    }
                } else if !trimmedQuery.isEmpty {
                    if results.isEmpty {
                        Section {
                            Text("Keine Treffer gefunden.")
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        Section("Ergebnisse") {
                            ForEach(results) { movie in
                                SearchResultRow(
                                    movie: movie,
                                    genreText: genreText(for: movie),
                                    isInterested: store.isInterested(movie),
                                    onToggle: { store.toggleInterested(movie) }
                                )
                            }
                        }
                    }
                } else {
                    Section {
                        Text("Suche nach Filmen mit Freitext.")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Filmsuche")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Schliessen") {
                        dismiss()
                    }
                }
            }
        }
    }

    private var trimmedQuery: String {
        query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func performSearch() async {
        guard !trimmedQuery.isEmpty else {
            results = []
            errorMessage = nil
            return
        }

        isSearching = true
        errorMessage = nil

        do {
            results = try await store.searchMovies(query: trimmedQuery)
        } catch {
            results = []
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "Suche fehlgeschlagen."
        }

        isSearching = false
    }

    private func genreText(for movie: Movie) -> String {
        let names = store.genreNames(for: movie)
        if names.isEmpty {
            return "Unbekannt"
        }
        return names.joined(separator: ", ")
    }
}

private struct SearchResultRow: View {
    let movie: Movie
    let genreText: String
    let isInterested: Bool
    let onToggle: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            NavigationLink(destination: MovieInfoView(movie: movie, genreText: genreText)) {
                HStack(alignment: .top, spacing: 12) {
                    PosterThumbnailView(url: movie.posterURL)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(movie.title)
                            .font(.headline)
                            .lineLimit(2)

                        Text("Release: \(movie.releaseDateText)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        Text("Genre: \(genreText)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }
                .foregroundStyle(.primary)
            }

            Spacer(minLength: 8)

            Button(action: onToggle) {
                Image(systemName: isInterested ? "bookmark.fill" : "bookmark")
                    .font(.title3)
                    .foregroundStyle(isInterested ? .green : .gray)
            }
            .buttonStyle(.borderless)
        }
        .padding(.vertical, 4)
    }
}
