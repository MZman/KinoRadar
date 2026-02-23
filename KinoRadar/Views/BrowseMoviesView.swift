import SwiftUI

struct BrowseMoviesView: View {
    @EnvironmentObject private var store: MovieStore
    @State private var selectedGenreIDs: Set<Int> = []
    @State private var showGenreFilter = false
    @State private var showMovieSearch = false

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
        List {
            if let errorMessage = store.errorMessage {
                Section {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                }
            }

            Section("Jetzt im Kino") {
                if filteredNowPlaying.isEmpty, !store.isLoading {
                    Text("Keine Filme gefunden.")
                        .foregroundStyle(.secondary)
                }
                ForEach(filteredNowPlaying) { movie in
                    MovieRow(
                        movie: movie,
                        genreText: genreText(for: movie),
                        isInterested: store.isInterested(movie),
                        onToggle: { store.toggleInterested(movie) }
                    )
                }
            }

            Section("Demnaechst") {
                if filteredUpcoming.isEmpty, !store.isLoading {
                    Text("Keine Filme gefunden.")
                        .foregroundStyle(.secondary)
                }
                ForEach(filteredUpcoming) { movie in
                    MovieRow(
                        movie: movie,
                        genreText: genreText(for: movie),
                        isInterested: store.isInterested(movie),
                        onToggle: { store.toggleInterested(movie) }
                    )
                }
            }
        }
        .navigationTitle("Kinofilme")
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    showMovieSearch = true
                } label: {
                    Image(systemName: "magnifyingglass.circle")
                        .font(.title2)
                        .padding(4)
                }
                .accessibilityLabel("Filme suchen")

                Button {
                    showGenreFilter = true
                } label: {
                    Image(systemName: isGenreFilterActive
                        ? "line.3.horizontal.decrease.circle.fill"
                        : "line.3.horizontal.decrease.circle"
                    )
                    .font(.title2)
                    .foregroundStyle(isGenreFilterActive ? .green : .primary)
                    .padding(4)
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

    private func matchesSelectedGenres(movie: Movie) -> Bool {
        guard !selectedGenreIDs.isEmpty else {
            return true
        }
        return movie.genreIDs.contains(where: { selectedGenreIDs.contains($0) })
    }

    private func genreText(for movie: Movie) -> String {
        let names = store.genreNames(for: movie)
        if names.isEmpty {
            return "Unbekannt"
        }
        return names.joined(separator: ", ")
    }
}

private struct MovieRow: View {
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
