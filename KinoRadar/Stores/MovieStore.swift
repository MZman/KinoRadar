import Foundation
import Combine

struct GenreFilterPreset: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var genreIDs: [Int]
}

@MainActor
final class MovieStore: ObservableObject {
    @Published var nowPlaying: [Movie] = []
    @Published var upcoming: [Movie] = []
    @Published var tvOnTheAir: [Movie] = []
    @Published var upcomingTV: [Movie] = []
    @Published private(set) var genres: [Genre] = []
    @Published private(set) var tvGenres: [Genre] = []
    @Published private(set) var genreFilterPresets: [GenreFilterPreset] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published private(set) var interestedMovieIDs: Set<Int> = []
    @Published private(set) var feedbackByMovieID: [Int: MovieFeedback] = [:]

    private let service: MovieServiceProtocol
    private let userDefaults = UserDefaults.standard
    private let calendar = Calendar.current
    private var movieCache: [Int: Movie] = [:]
    private var cachedGenreNamesByMovieID: [Int: [String]] = [:]
    private var movieDetailCache: [String: MovieDetail] = [:]
    private var personDetailCache: [Int: PersonDetail] = [:]
    private var watchProviderCache: [String: WatchProviderRegionInfo] = [:]
    private var collectionCache: [Int: MovieCollectionDetail] = [:]
    private var tvSeasonCache: [String: TVSeasonDetail] = [:]
    private var relatedMediaCache: [String: [Movie]] = [:]

    private enum Keys {
        static let interestedMovieIDs = "interested_movie_ids"
        static let feedbackByMovieID = "feedback_by_movie_id"
        static let movieCache = "movie_cache"
        static let genres = "genres"
        static let tvGenres = "tv_genres"
        static let genreFilterPresets = "genre_filter_presets"
        static let cachedGenreNamesByMovieID = "cached_genre_names_by_movie_id"
    }

    init(service: MovieServiceProtocol = TMDBService()) {
        self.service = service
        loadPersistedState()
    }

    func loadMoviesIfNeeded() async {
        guard nowPlaying.isEmpty, upcoming.isEmpty, tvOnTheAir.isEmpty, upcomingTV.isEmpty, !isLoading else {
            return
        }
        await refresh()
    }

    func refresh() async {
        guard !isLoading else {
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            async let nowPlayingMovies = service.fetchNowPlaying()
            async let upcomingMovies = service.fetchUpcoming()
            async let tvOnTheAirSeries = service.fetchTVOnTheAir()
            async let upcomingTVSeries = service.fetchUpcomingTV()
            let (loadedNowPlaying, loadedUpcoming) = try await (nowPlayingMovies, upcomingMovies)
            let loadedGenres = (try? await service.fetchGenres()) ?? genres
            let loadedTVGenres = (try? await service.fetchTVGenres()) ?? tvGenres
            let loadedTVOnTheAir = (try? await tvOnTheAirSeries) ?? tvOnTheAir
            let loadedUpcomingTV = (try? await upcomingTVSeries) ?? upcomingTV
            let sortedLoadedGenres = loadedGenres.sorted {
                $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
            let sortedLoadedTVGenres = loadedTVGenres.sorted {
                $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
            let filteredUpcoming = filterUpcomingCurrentYear(loadedUpcoming)

            nowPlaying = loadedNowPlaying
            upcoming = filteredUpcoming
            tvOnTheAir = loadedTVOnTheAir
            upcomingTV = loadedUpcomingTV
            genres = sortedLoadedGenres
            tvGenres = sortedLoadedTVGenres
            cacheGenreNames(
                movies: loadedNowPlaying + filteredUpcoming,
                genres: sortedLoadedGenres
            )
            cacheGenreNames(
                movies: loadedTVOnTheAir + loadedUpcomingTV,
                genres: sortedLoadedTVGenres
            )
            cache(movies: loadedNowPlaying + filteredUpcoming + loadedTVOnTheAir + loadedUpcomingTV)
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "Filme konnten nicht geladen werden."
        }

        isLoading = false
    }

    func isInterested(_ movie: Movie) -> Bool {
        interestedMovieIDs.contains(movie.id)
    }

    func toggleInterested(_ movie: Movie) {
        if interestedMovieIDs.contains(movie.id) {
            interestedMovieIDs.remove(movie.id)
        } else {
            interestedMovieIDs.insert(movie.id)
            movieCache[movie.id] = movie
            let names = genreNames(for: movie)
            if !names.isEmpty {
                cachedGenreNamesByMovieID[movie.id] = names
            }
        }
        persist()
    }

    func feedback(for movieID: Int) -> MovieFeedback {
        feedbackByMovieID[movieID] ?? .empty
    }

    func saveFeedback(for movieID: Int, rating: Int, comment: String) {
        let normalizedRating = min(max(rating, 0), 5)
        let normalizedComment = comment.trimmingCharacters(in: .whitespacesAndNewlines)
        feedbackByMovieID[movieID] = MovieFeedback(rating: normalizedRating, comment: normalizedComment)
        persist()
    }

    var interestedMovies: [Movie] {
        interestedMovieIDs.compactMap { movieCache[$0] }
    }

    var sortedGenres: [Genre] {
        genres
    }

    func sortedGenres(for mediaType: MediaType) -> [Genre] {
        switch mediaType {
        case .movie:
            return genres
        case .tv:
            return tvGenres
        }
    }

    var sortedGenreFilterPresets: [GenreFilterPreset] {
        genreFilterPresets
    }

    func genreNames(for movie: Movie) -> [String] {
        let sourceGenres = movie.mediaType == .tv ? tvGenres : genres
        let lookup = Dictionary(uniqueKeysWithValues: sourceGenres.map { ($0.id, $0.name) })
        let resolvedNames = movie.genreIDs.compactMap { lookup[$0] }
        if !resolvedNames.isEmpty {
            return resolvedNames
        }
        return cachedGenreNamesByMovieID[movie.id] ?? []
    }

    func saveGenreFilterPreset(name: String, selectedGenreIDs: Set<Int>) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty, !selectedGenreIDs.isEmpty else {
            return
        }

        if let existingIndex = genreFilterPresets.firstIndex(where: {
            $0.name.localizedCaseInsensitiveCompare(trimmedName) == .orderedSame
        }) {
            genreFilterPresets[existingIndex].genreIDs = selectedGenreIDs.sorted()
        } else {
            genreFilterPresets.append(
                GenreFilterPreset(
                    id: UUID(),
                    name: trimmedName,
                    genreIDs: selectedGenreIDs.sorted()
                )
            )
        }

        genreFilterPresets.sort {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
        persist()
    }

    func deleteGenreFilterPreset(id: UUID) {
        genreFilterPresets.removeAll { $0.id == id }
        persist()
    }

    func searchMovies(query: String) async throws -> [Movie] {
        let results = try await service.searchMovies(query: query)
        if !genres.isEmpty {
            cacheGenreNames(movies: results, genres: genres)
        }
        cache(movies: results)
        return results
    }

    func searchTVSeries(query: String) async throws -> [Movie] {
        let results = try await service.searchTVSeries(query: query)
        if !tvGenres.isEmpty {
            cacheGenreNames(movies: results, genres: tvGenres)
        }
        cache(movies: results)
        return results
    }

    func fetchTMDBCountries() async throws -> [RegionOption] {
        try await service.fetchTMDBCountries()
    }

    func cachedMovieDetails(for movie: Movie) -> MovieDetail? {
        movieDetailCache[movieDetailsKey(for: movie)]
    }

    func fetchMovieDetails(for movie: Movie, forceRefresh: Bool = false) async throws -> MovieDetail {
        let cacheKey = movieDetailsKey(for: movie)
        if !forceRefresh, let cached = movieDetailCache[cacheKey] {
            return cached
        }
        let details = try await service.fetchMediaDetails(mediaType: movie.mediaType, id: movie.id)
        movieDetailCache[cacheKey] = details
        return details
    }

    func cachedPersonDetails(for personID: Int) -> PersonDetail? {
        personDetailCache[personID]
    }

    func fetchPersonDetails(for personID: Int, forceRefresh: Bool = false) async throws -> PersonDetail {
        if !forceRefresh, let cached = personDetailCache[personID] {
            return cached
        }
        let details = try await service.fetchPersonDetails(personID: personID)
        personDetailCache[personID] = details
        return details
    }

    func cachedWatchProviders(for movie: Movie) -> WatchProviderRegionInfo? {
        let cacheKey = watchProvidersKey(for: movie)
        return watchProviderCache[cacheKey]
    }

    func fetchWatchProviders(for movie: Movie, forceRefresh: Bool = false) async throws -> WatchProviderRegionInfo? {
        let cacheKey = watchProvidersKey(for: movie)
        if !forceRefresh, let cached = watchProviderCache[cacheKey] {
            return cached
        }

        let providers = try await service.fetchWatchProviders(mediaType: movie.mediaType, id: movie.id)
        if let providers {
            watchProviderCache[cacheKey] = providers
        }
        return providers
    }

    func cachedCollectionDetails(for collectionID: Int) -> MovieCollectionDetail? {
        collectionCache[collectionID]
    }

    func fetchCollectionDetails(collectionID: Int, forceRefresh: Bool = false) async throws -> MovieCollectionDetail {
        if !forceRefresh, let cached = collectionCache[collectionID] {
            return cached
        }
        let details = try await service.fetchCollectionDetails(collectionID: collectionID)
        collectionCache[collectionID] = details
        return details
    }

    func cachedTVSeasonDetails(tvID: Int, seasonNumber: Int) -> TVSeasonDetail? {
        tvSeasonCache[tvSeasonKey(tvID: tvID, seasonNumber: seasonNumber)]
    }

    func fetchTVSeasonDetails(tvID: Int, seasonNumber: Int, forceRefresh: Bool = false) async throws -> TVSeasonDetail {
        let cacheKey = tvSeasonKey(tvID: tvID, seasonNumber: seasonNumber)
        if !forceRefresh, let cached = tvSeasonCache[cacheKey] {
            return cached
        }
        let details = try await service.fetchTVSeasonDetails(tvID: tvID, seasonNumber: seasonNumber)
        tvSeasonCache[cacheKey] = details
        return details
    }

    func cachedRelatedMedia(for movie: Movie) -> [Movie]? {
        relatedMediaCache[relatedMediaKey(for: movie)]
    }

    func fetchRelatedMedia(for movie: Movie, forceRefresh: Bool = false) async throws -> [Movie] {
        let cacheKey = relatedMediaKey(for: movie)
        if !forceRefresh, let cached = relatedMediaCache[cacheKey] {
            return cached
        }
        let related = try await service.fetchRelatedMedia(mediaType: movie.mediaType, id: movie.id)
        relatedMediaCache[cacheKey] = related
        cache(movies: related)
        return related
    }

    private func watchProvidersKey(for movie: Movie) -> String {
        "\(movie.mediaType.rawValue)-\(movie.id)"
    }

    private func movieDetailsKey(for movie: Movie) -> String {
        "\(movie.mediaType.rawValue)-\(movie.id)"
    }

    private func tvSeasonKey(tvID: Int, seasonNumber: Int) -> String {
        "tv-\(tvID)-season-\(seasonNumber)"
    }

    private func relatedMediaKey(for movie: Movie) -> String {
        "\(movie.mediaType.rawValue)-related-\(movie.id)"
    }

    private func cache(movies: [Movie]) {
        for movie in movies {
            movieCache[movie.id] = movie
        }
        persist()
    }

    private func cacheGenreNames(movies: [Movie], genres: [Genre]) {
        let lookup = Dictionary(uniqueKeysWithValues: genres.map { ($0.id, $0.name) })
        for movie in movies {
            let names = movie.genreIDs.compactMap { lookup[$0] }
            if !names.isEmpty {
                cachedGenreNamesByMovieID[movie.id] = names
            }
        }
    }

    private func filterUpcomingCurrentYear(_ movies: [Movie]) -> [Movie] {
        let today = calendar.startOfDay(for: Date())
        let year = calendar.component(.year, from: today)
        guard let endOfYear = calendar.date(from: DateComponents(year: year, month: 12, day: 31)) else {
            return []
        }

        return movies
            .filter { movie in
                guard let date = movie.releaseDate else {
                    return false
                }
                let day = calendar.startOfDay(for: date)
                return day >= today && day <= endOfYear
            }
            .sorted { lhs, rhs in
                switch (lhs.releaseDate, rhs.releaseDate) {
                case let (left?, right?):
                    return left < right
                case (_?, nil):
                    return true
                case (nil, _?):
                    return false
                case (nil, nil):
                    return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
                }
            }
    }

    private func loadPersistedState() {
        let decoder = JSONDecoder()

        if
            let data = userDefaults.data(forKey: Keys.interestedMovieIDs),
            let decoded = try? decoder.decode(Set<Int>.self, from: data)
        {
            interestedMovieIDs = decoded
        }

        if
            let data = userDefaults.data(forKey: Keys.feedbackByMovieID),
            let decoded = try? decoder.decode([Int: MovieFeedback].self, from: data)
        {
            feedbackByMovieID = decoded
        }

        if
            let data = userDefaults.data(forKey: Keys.movieCache),
            let decoded = try? decoder.decode([Movie].self, from: data)
        {
            movieCache = Dictionary(uniqueKeysWithValues: decoded.map { ($0.id, $0) })
        }

        if
            let data = userDefaults.data(forKey: Keys.genres),
            let decoded = try? decoder.decode([Genre].self, from: data)
        {
            genres = decoded
        }

        if
            let data = userDefaults.data(forKey: Keys.tvGenres),
            let decoded = try? decoder.decode([Genre].self, from: data)
        {
            tvGenres = decoded
        }

        if
            let data = userDefaults.data(forKey: Keys.genreFilterPresets),
            let decoded = try? decoder.decode([GenreFilterPreset].self, from: data)
        {
            genreFilterPresets = decoded.sorted {
                $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
        }

        if
            let data = userDefaults.data(forKey: Keys.cachedGenreNamesByMovieID),
            let decoded = try? decoder.decode([Int: [String]].self, from: data)
        {
            cachedGenreNamesByMovieID = decoded
        }
    }

    private func persist() {
        let encoder = JSONEncoder()

        if let encoded = try? encoder.encode(interestedMovieIDs) {
            userDefaults.set(encoded, forKey: Keys.interestedMovieIDs)
        }

        if let encoded = try? encoder.encode(feedbackByMovieID) {
            userDefaults.set(encoded, forKey: Keys.feedbackByMovieID)
        }

        if let encoded = try? encoder.encode(Array(movieCache.values)) {
            userDefaults.set(encoded, forKey: Keys.movieCache)
        }

        if let encoded = try? encoder.encode(genres) {
            userDefaults.set(encoded, forKey: Keys.genres)
        }

        if let encoded = try? encoder.encode(tvGenres) {
            userDefaults.set(encoded, forKey: Keys.tvGenres)
        }

        if let encoded = try? encoder.encode(genreFilterPresets) {
            userDefaults.set(encoded, forKey: Keys.genreFilterPresets)
        }

        if let encoded = try? encoder.encode(cachedGenreNamesByMovieID) {
            userDefaults.set(encoded, forKey: Keys.cachedGenreNamesByMovieID)
        }
    }
}
