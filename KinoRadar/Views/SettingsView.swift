import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var store: MovieStore
    @EnvironmentObject private var localContext: LocalContextStore

    @State private var showAPIKey = false
    @State private var isLoadingRegions = false
    @State private var regionLoadError: String?
    @State private var didLoadRegions = false

    @State private var showFilterEditor = false
    @State private var editingFilter: PredefinedGenreFilter?

    var body: some View {
        Form {
            Section("Profil") {
                TextField("Dein Name", text: $settings.userName)
                    .textInputAutocapitalization(.words)
            }

            Section("Inhalt") {
                Picker("Region (Kinostarts)", selection: $settings.regionCode) {
                    ForEach(settings.regionOptions) { option in
                        Text("\(option.name) (\(option.code))")
                            .tag(option.code)
                    }
                }

                if isLoadingRegions {
                    ProgressView("Lade Regionen ...")
                }

                if let regionLoadError {
                    Text(regionLoadError)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }

                Button("TMDB Regionen neu laden") {
                    Task {
                        await loadRegionOptionsFromTMDB()
                    }
                }
                .disabled(isLoadingRegions || settings.apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                Picker("Sprache (Anzeige)", selection: $settings.languageCode) {
                    ForEach(AppSettings.languageOptions) { option in
                        Text("\(option.name) (\(option.code))")
                            .tag(option.code)
                    }
                }

                Text("Region kommt aus der TMDB API-Liste und steuert, in welchem Land Releases/Provider gesucht werden.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                Button("Standort neu bestimmen") {
                    localContext.requestLocation()
                }

                Text("Aktueller Standort: \(localContext.resolvedCityName), \(localContext.countryCode)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("Vordefinierte Filter (max 2)") {
                if settings.predefinedGenreFilters.isEmpty {
                    Text("Keine vordefinierten Filter.")
                        .foregroundStyle(.secondary)
                }

                ForEach(settings.predefinedGenreFilters) { filter in
                    Button {
                        editingFilter = filter
                        showFilterEditor = true
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(filter.name)
                                    .font(.headline)
                                Spacer()
                                Text("\(filter.genreIDs.count)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Text(filterSummaryText(for: filter))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                    }
                    .buttonStyle(.plain)
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            settings.deletePredefinedGenreFilter(id: filter.id)
                        } label: {
                            Label("Loeschen", systemImage: "trash")
                        }
                    }
                }

                if settings.predefinedGenreFilters.count < 2 {
                    Button("Filter hinzufuegen") {
                        editingFilter = nil
                        showFilterEditor = true
                    }
                    .disabled(availableGenres.isEmpty)
                }

                if availableGenres.isEmpty {
                    Text("Genres werden erst nach dem ersten Laden der Inhalte verfuegbar.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            Section("TMDB API Key") {
                if showAPIKey {
                    TextField("API Key", text: $settings.apiKey)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                } else {
                    SecureField("API Key", text: $settings.apiKey)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }

                Toggle("API Key anzeigen", isOn: $showAPIKey)

                Text("Den API Key bekommst du in deinem TMDB-Konto unter API-Einstellungen.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("Aktionen") {
                Button("Filme/Serien neu laden") {
                    Task {
                        await store.refresh()
                    }
                }
            }

            if !settings.trimmedUserName.isEmpty {
                Section("Vorschau") {
                    Text("Hallo \(settings.trimmedUserName)")
                    Text("Region: \(settings.selectedRegionName)")
                        .foregroundStyle(.secondary)
                    Text("Sprache: \(settings.selectedLanguageName)")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Einstellungen")
        .task {
            guard !didLoadRegions else {
                return
            }
            didLoadRegions = true
            await loadRegionOptionsFromTMDB()
        }
        .sheet(isPresented: $showFilterEditor) {
            PredefinedFilterEditorSheet(
                filter: editingFilter,
                availableGenres: availableGenres
            ) { id, name, genreIDs in
                settings.upsertPredefinedGenreFilter(id: id, name: name, genreIDs: genreIDs)
            }
        }
    }

    private var availableGenres: [Genre] {
        let merged = store.sortedGenres + store.sortedGenres(for: .tv)
        var byID: [Int: Genre] = [:]
        for genre in merged {
            if byID[genre.id] == nil {
                byID[genre.id] = genre
            }
        }
        return byID.values.sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }

    private var genreNameLookup: [Int: String] {
        Dictionary(uniqueKeysWithValues: availableGenres.map { ($0.id, $0.name) })
    }

    private func filterSummaryText(for filter: PredefinedGenreFilter) -> String {
        let names = filter.genreIDs.compactMap { genreNameLookup[$0] }
        if names.isEmpty {
            return "Keine passenden Genres geladen"
        }
        return names.joined(separator: ", ")
    }

    private func loadRegionOptionsFromTMDB() async {
        let trimmedAPIKey = settings.apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedAPIKey.isEmpty else {
            regionLoadError = "Bitte zuerst den TMDB API Key eintragen."
            return
        }

        isLoadingRegions = true
        regionLoadError = nil

        do {
            let regions = try await store.fetchTMDBCountries()
            settings.updateRegionOptions(regions)
        } catch {
            regionLoadError = (error as? LocalizedError)?.errorDescription ?? "Regionen konnten nicht geladen werden."
        }

        isLoadingRegions = false
    }
}

private struct PredefinedFilterEditorSheet: View {
    @Environment(\.dismiss) private var dismiss

    let filter: PredefinedGenreFilter?
    let availableGenres: [Genre]
    let onSave: (UUID?, String, Set<Int>) -> Bool

    @State private var filterName: String
    @State private var selectedGenreIDs: Set<Int>
    @State private var saveErrorMessage: String?

    init(
        filter: PredefinedGenreFilter?,
        availableGenres: [Genre],
        onSave: @escaping (UUID?, String, Set<Int>) -> Bool
    ) {
        self.filter = filter
        self.availableGenres = availableGenres
        self.onSave = onSave
        _filterName = State(initialValue: filter?.name ?? "")
        _selectedGenreIDs = State(initialValue: Set(filter?.genreIDs ?? []))
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Name (max 5 Zeichen)") {
                    TextField("Kurzname", text: $filterName)
                        .textInputAutocapitalization(.characters)
                        .onChange(of: filterName) { _, newValue in
                            if newValue.count > 5 {
                                filterName = String(newValue.prefix(5))
                            }
                        }

                    Text("\(filterName.count)/5")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Genres") {
                    if availableGenres.isEmpty {
                        Text("Keine Genres verfuegbar.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(availableGenres) { genre in
                            Button {
                                toggleGenre(genre.id)
                            } label: {
                                HStack {
                                    Text(genre.name)
                                        .foregroundStyle(selectedGenreIDs.contains(genre.id) ? .green : .primary)
                                    Spacer()
                                    if selectedGenreIDs.contains(genre.id) {
                                        Image(systemName: "checkmark")
                                            .foregroundStyle(.green)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                if let saveErrorMessage {
                    Section {
                        Text(saveErrorMessage)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle(filter == nil ? "Filter erstellen" : "Filter bearbeiten")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Abbrechen") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Speichern") {
                        let success = onSave(filter?.id, filterName, selectedGenreIDs)
                        if success {
                            dismiss()
                        } else {
                            saveErrorMessage = "Maximal zwei Filter erlaubt und Name/Genres duerfen nicht leer sein."
                        }
                    }
                    .disabled(
                        filterName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                        selectedGenreIDs.isEmpty
                    )
                }
            }
        }
    }

    private func toggleGenre(_ genreID: Int) {
        if selectedGenreIDs.contains(genreID) {
            selectedGenreIDs.remove(genreID)
        } else {
            selectedGenreIDs.insert(genreID)
        }
    }
}
