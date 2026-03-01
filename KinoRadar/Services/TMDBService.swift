import Foundation

protocol MovieServiceProtocol {
    func fetchNowPlaying() async throws -> [Movie]
    func fetchUpcoming() async throws -> [Movie]
    func fetchGenres() async throws -> [Genre]
    func fetchTVOnTheAir() async throws -> [Movie]
    func fetchUpcomingTV() async throws -> [Movie]
    func fetchTVGenres() async throws -> [Genre]
    func searchMovies(query: String) async throws -> [Movie]
    func searchTVSeries(query: String) async throws -> [Movie]
    func fetchMediaDetails(mediaType: MediaType, id: Int) async throws -> MovieDetail
    func fetchPersonDetails(personID: Int) async throws -> PersonDetail
    func fetchWatchProviders(mediaType: MediaType, id: Int) async throws -> WatchProviderRegionInfo?
    func fetchTMDBCountries() async throws -> [RegionOption]
}

enum APIConfig {
    static let baseURL = URL(string: "https://api.themoviedb.org/3")!
}

enum TMDBError: LocalizedError {
    case missingAPIKey
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "Bitte den TMDB API Key in den Einstellungen hinterlegen."
        case .invalidResponse:
            return "TMDB hat eine unerwartete Antwort geliefert."
        }
    }
}

struct TMDBService: MovieServiceProtocol {
    private let session: URLSession
    private let decoder: JSONDecoder
    private let calendar = Calendar.current

    init(session: URLSession = .shared) {
        self.session = session
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .formatted(DateFormatter.tmdbDateFormatter)
        self.decoder = decoder
    }

    func fetchNowPlaying() async throws -> [Movie] {
        let apiKey = try readAPIKey()
        let localeSettings = readLocaleSettings()

        var page = 1
        var totalPages = 1
        var allMovies: [Movie] = []

        repeat {
            var components = URLComponents(
                url: APIConfig.baseURL.appendingPathComponent("movie/now_playing"),
                resolvingAgainstBaseURL: false
            )
            components?.queryItems = [
                URLQueryItem(name: "api_key", value: apiKey),
                URLQueryItem(name: "language", value: localeSettings.languageCode),
                URLQueryItem(name: "region", value: localeSettings.regionCode),
                URLQueryItem(name: "page", value: String(page))
            ]

            guard let url = components?.url else {
                throw URLError(.badURL)
            }

            let (data, response) = try await session.data(from: url)
            guard let httpResponse = response as? HTTPURLResponse, 200..<300 ~= httpResponse.statusCode else {
                throw TMDBError.invalidResponse
            }

            let decoded = try decoder.decode(MovieResponse.self, from: data)
            allMovies.append(contentsOf: decoded.results)
            totalPages = decoded.totalPages ?? 1
            page += 1
        } while page <= totalPages

        var uniqueMovies: [Movie] = []
        var seenIDs: Set<Int> = []
        for movie in allMovies {
            if seenIDs.insert(movie.id).inserted {
                uniqueMovies.append(movie)
            }
        }

        return uniqueMovies
    }

    func fetchUpcoming() async throws -> [Movie] {
        let today = calendar.startOfDay(for: Date())
        let year = calendar.component(.year, from: today)
        guard
            let endOfYear = calendar.date(from: DateComponents(year: year, month: 12, day: 31))
        else {
            return []
        }
        return try await fetchDiscoverMovies(from: today, to: endOfYear)
    }

    func fetchGenres() async throws -> [Genre] {
        let apiKey = try readAPIKey()
        let localeSettings = readLocaleSettings()
        var components = URLComponents(
            url: APIConfig.baseURL.appendingPathComponent("genre/movie/list"),
            resolvingAgainstBaseURL: false
        )
        components?.queryItems = [
            URLQueryItem(name: "api_key", value: apiKey),
            URLQueryItem(name: "language", value: localeSettings.languageCode)
        ]

        guard let url = components?.url else {
            throw URLError(.badURL)
        }

        let (data, response) = try await session.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse, 200..<300 ~= httpResponse.statusCode else {
            throw TMDBError.invalidResponse
        }

        return try decoder.decode(GenreResponse.self, from: data).genres
    }

    func fetchTVOnTheAir() async throws -> [Movie] {
        let apiKey = try readAPIKey()
        let localeSettings = readLocaleSettings()

        var page = 1
        var totalPages = 1
        var allSeries: [Movie] = []

        repeat {
            var components = URLComponents(
                url: APIConfig.baseURL.appendingPathComponent("tv/on_the_air"),
                resolvingAgainstBaseURL: false
            )
            components?.queryItems = [
                URLQueryItem(name: "api_key", value: apiKey),
                URLQueryItem(name: "language", value: localeSettings.languageCode),
                URLQueryItem(name: "page", value: String(page))
            ]

            guard let url = components?.url else {
                throw URLError(.badURL)
            }

            let (data, response) = try await session.data(from: url)
            guard let httpResponse = response as? HTTPURLResponse, 200..<300 ~= httpResponse.statusCode else {
                throw TMDBError.invalidResponse
            }

            let decoded = try decoder.decode(MovieResponse.self, from: data)
            allSeries.append(contentsOf: decoded.results)
            totalPages = decoded.totalPages ?? 1
            page += 1
        } while page <= totalPages

        var uniqueSeries: [Movie] = []
        var seenIDs: Set<Int> = []
        for series in allSeries {
            if seenIDs.insert(series.id).inserted {
                uniqueSeries.append(series)
            }
        }

        return uniqueSeries.map { series in
            Movie(
                id: series.id,
                title: series.title,
                overview: series.overview,
                releaseDate: series.releaseDate,
                posterPath: series.posterPath,
                genreIDs: series.genreIDs,
                mediaType: .tv
            )
        }
    }

    func fetchUpcomingTV() async throws -> [Movie] {
        let today = calendar.startOfDay(for: Date())
        let year = calendar.component(.year, from: today)
        guard
            let endOfYear = calendar.date(from: DateComponents(year: year, month: 12, day: 31))
        else {
            return []
        }
        return try await fetchDiscoverSeries(from: today, to: endOfYear)
    }

    func fetchTVGenres() async throws -> [Genre] {
        let apiKey = try readAPIKey()
        let localeSettings = readLocaleSettings()
        var components = URLComponents(
            url: APIConfig.baseURL.appendingPathComponent("genre/tv/list"),
            resolvingAgainstBaseURL: false
        )
        components?.queryItems = [
            URLQueryItem(name: "api_key", value: apiKey),
            URLQueryItem(name: "language", value: localeSettings.languageCode)
        ]

        guard let url = components?.url else {
            throw URLError(.badURL)
        }

        let (data, response) = try await session.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse, 200..<300 ~= httpResponse.statusCode else {
            throw TMDBError.invalidResponse
        }

        return try decoder.decode(GenreResponse.self, from: data).genres
    }

    func searchMovies(query: String) async throws -> [Movie] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else {
            return []
        }

        let apiKey = try readAPIKey()
        let localeSettings = readLocaleSettings()
        var components = URLComponents(
            url: APIConfig.baseURL.appendingPathComponent("search/movie"),
            resolvingAgainstBaseURL: false
        )
        components?.queryItems = [
            URLQueryItem(name: "api_key", value: apiKey),
            URLQueryItem(name: "language", value: localeSettings.languageCode),
            URLQueryItem(name: "region", value: localeSettings.regionCode),
            URLQueryItem(name: "include_adult", value: "false"),
            URLQueryItem(name: "query", value: trimmedQuery),
            URLQueryItem(name: "page", value: "1")
        ]

        guard let url = components?.url else {
            throw URLError(.badURL)
        }

        let (data, response) = try await session.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse, 200..<300 ~= httpResponse.statusCode else {
            throw TMDBError.invalidResponse
        }

        return try decoder.decode(MovieResponse.self, from: data).results
    }

    func searchTVSeries(query: String) async throws -> [Movie] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else {
            return []
        }

        let apiKey = try readAPIKey()
        let localeSettings = readLocaleSettings()
        var components = URLComponents(
            url: APIConfig.baseURL.appendingPathComponent("search/tv"),
            resolvingAgainstBaseURL: false
        )
        components?.queryItems = [
            URLQueryItem(name: "api_key", value: apiKey),
            URLQueryItem(name: "language", value: localeSettings.languageCode),
            URLQueryItem(name: "include_adult", value: "false"),
            URLQueryItem(name: "query", value: trimmedQuery),
            URLQueryItem(name: "page", value: "1")
        ]

        guard let url = components?.url else {
            throw URLError(.badURL)
        }

        let (data, response) = try await session.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse, 200..<300 ~= httpResponse.statusCode else {
            throw TMDBError.invalidResponse
        }

        let results = try decoder.decode(MovieResponse.self, from: data).results
        return results.map { series in
            Movie(
                id: series.id,
                title: series.title,
                overview: series.overview,
                releaseDate: series.releaseDate,
                posterPath: series.posterPath,
                genreIDs: series.genreIDs,
                mediaType: .tv
            )
        }
    }

    func fetchMediaDetails(mediaType: MediaType, id: Int) async throws -> MovieDetail {
        let apiKey = try readAPIKey()
        let localeSettings = readLocaleSettings()
        var components = URLComponents(
            url: APIConfig.baseURL
                .appendingPathComponent(mediaType.rawValue)
                .appendingPathComponent(String(id)),
            resolvingAgainstBaseURL: false
        )
        components?.queryItems = [
            URLQueryItem(name: "api_key", value: apiKey),
            URLQueryItem(name: "language", value: localeSettings.languageCode),
            URLQueryItem(name: "append_to_response", value: "images,credits,reviews,videos"),
            URLQueryItem(name: "include_image_language", value: "\(localeSettings.languageCode),null")
        ]

        guard let url = components?.url else {
            throw URLError(.badURL)
        }

        let (data, response) = try await session.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse, 200..<300 ~= httpResponse.statusCode else {
            throw TMDBError.invalidResponse
        }

        return try decoder.decode(MovieDetail.self, from: data)
    }

    func fetchPersonDetails(personID: Int) async throws -> PersonDetail {
        let apiKey = try readAPIKey()
        let localeSettings = readLocaleSettings()
        var components = URLComponents(
            url: APIConfig.baseURL
                .appendingPathComponent("person")
                .appendingPathComponent(String(personID)),
            resolvingAgainstBaseURL: false
        )
        components?.queryItems = [
            URLQueryItem(name: "api_key", value: apiKey),
            URLQueryItem(name: "language", value: localeSettings.languageCode),
            URLQueryItem(name: "append_to_response", value: "images,combined_credits,movie_credits,external_ids"),
            URLQueryItem(name: "include_image_language", value: "\(localeSettings.languageCode),null")
        ]

        guard let url = components?.url else {
            throw URLError(.badURL)
        }

        let (data, response) = try await session.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse, 200..<300 ~= httpResponse.statusCode else {
            throw TMDBError.invalidResponse
        }

        return try decoder.decode(PersonDetail.self, from: data)
    }

    func fetchWatchProviders(mediaType: MediaType, id: Int) async throws -> WatchProviderRegionInfo? {
        let apiKey = try readAPIKey()
        let localeSettings = readLocaleSettings()
        var components = URLComponents(
            url: APIConfig.baseURL
                .appendingPathComponent(mediaType.rawValue)
                .appendingPathComponent(String(id))
                .appendingPathComponent("watch")
                .appendingPathComponent("providers"),
            resolvingAgainstBaseURL: false
        )
        components?.queryItems = [
            URLQueryItem(name: "api_key", value: apiKey)
        ]

        guard let url = components?.url else {
            throw URLError(.badURL)
        }

        let (data, response) = try await session.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse, 200..<300 ~= httpResponse.statusCode else {
            throw TMDBError.invalidResponse
        }

        let decoded = try decoder.decode(WatchProviderResponse.self, from: data)
        let regionCode = localeSettings.regionCode.uppercased()

        if let regionResult = decoded.results[regionCode] {
            return regionResult
        }

        // Fallback: if no match for selected region, return first available region.
        return decoded.results.values.first
    }

    func fetchTMDBCountries() async throws -> [RegionOption] {
        let apiKey = try readAPIKey()
        var components = URLComponents(
            url: APIConfig.baseURL.appendingPathComponent("configuration/countries"),
            resolvingAgainstBaseURL: false
        )
        components?.queryItems = [
            URLQueryItem(name: "api_key", value: apiKey)
        ]

        guard let url = components?.url else {
            throw URLError(.badURL)
        }

        let (data, response) = try await session.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse, 200..<300 ~= httpResponse.statusCode else {
            throw TMDBError.invalidResponse
        }

        let decoded = try decoder.decode([TMDBCountryConfig].self, from: data)
        var seenCodes: Set<String> = []
        let regions = decoded.compactMap { item -> RegionOption? in
            let code = item.iso3166_1.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
            guard !code.isEmpty, seenCodes.insert(code).inserted else {
                return nil
            }
            let nameCandidate = (item.nativeName ?? item.englishName).trimmingCharacters(in: .whitespacesAndNewlines)
            let name = nameCandidate.isEmpty ? code : nameCandidate
            return RegionOption(code: code, name: name)
        }
        return regions.sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }

    private func fetchDiscoverMovies(from startDate: Date, to endDate: Date) async throws -> [Movie] {
        let apiKey = try readAPIKey()
        let localeSettings = readLocaleSettings()
        let startDateString = DateFormatter.tmdbDateFormatter.string(from: startDate)
        let endDateString = DateFormatter.tmdbDateFormatter.string(from: endDate)

        var page = 1
        var totalPages = 1
        var allMovies: [Movie] = []

        repeat {
            var components = URLComponents(
                url: APIConfig.baseURL.appendingPathComponent("discover/movie"),
                resolvingAgainstBaseURL: false
            )
            components?.queryItems = [
                URLQueryItem(name: "api_key", value: apiKey),
                URLQueryItem(name: "language", value: localeSettings.languageCode),
                URLQueryItem(name: "region", value: localeSettings.regionCode),
                URLQueryItem(name: "include_adult", value: "false"),
                URLQueryItem(name: "include_video", value: "false"),
                URLQueryItem(name: "sort_by", value: "primary_release_date.asc"),
                URLQueryItem(name: "primary_release_date.gte", value: startDateString),
                URLQueryItem(name: "primary_release_date.lte", value: endDateString),
                URLQueryItem(name: "page", value: String(page))
            ]

            guard let url = components?.url else {
                throw URLError(.badURL)
            }

            let (data, response) = try await session.data(from: url)
            guard let httpResponse = response as? HTTPURLResponse, 200..<300 ~= httpResponse.statusCode else {
                throw TMDBError.invalidResponse
            }

            let decoded = try decoder.decode(MovieResponse.self, from: data)
            allMovies.append(contentsOf: decoded.results)
            totalPages = decoded.totalPages ?? 1
            page += 1
        } while page <= totalPages

        var uniqueMovies: [Int: Movie] = [:]
        for movie in allMovies {
            uniqueMovies[movie.id] = movie
        }

        return Array(uniqueMovies.values).sorted {
            switch ($0.releaseDate, $1.releaseDate) {
            case let (lhs?, rhs?):
                return lhs < rhs
            case (_?, nil):
                return true
            case (nil, _?):
                return false
            case (nil, nil):
                return $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
            }
        }
    }

    private func fetchDiscoverSeries(from startDate: Date, to endDate: Date) async throws -> [Movie] {
        let apiKey = try readAPIKey()
        let localeSettings = readLocaleSettings()
        let startDateString = DateFormatter.tmdbDateFormatter.string(from: startDate)
        let endDateString = DateFormatter.tmdbDateFormatter.string(from: endDate)

        var page = 1
        var totalPages = 1
        var allSeries: [Movie] = []

        repeat {
            var components = URLComponents(
                url: APIConfig.baseURL.appendingPathComponent("discover/tv"),
                resolvingAgainstBaseURL: false
            )
            components?.queryItems = [
                URLQueryItem(name: "api_key", value: apiKey),
                URLQueryItem(name: "language", value: localeSettings.languageCode),
                URLQueryItem(name: "include_adult", value: "false"),
                URLQueryItem(name: "include_null_first_air_dates", value: "false"),
                URLQueryItem(name: "sort_by", value: "first_air_date.asc"),
                URLQueryItem(name: "first_air_date.gte", value: startDateString),
                URLQueryItem(name: "first_air_date.lte", value: endDateString),
                URLQueryItem(name: "page", value: String(page))
            ]

            guard let url = components?.url else {
                throw URLError(.badURL)
            }

            let (data, response) = try await session.data(from: url)
            guard let httpResponse = response as? HTTPURLResponse, 200..<300 ~= httpResponse.statusCode else {
                throw TMDBError.invalidResponse
            }

            let decoded = try decoder.decode(MovieResponse.self, from: data)
            allSeries.append(contentsOf: decoded.results)
            totalPages = decoded.totalPages ?? 1
            page += 1
        } while page <= totalPages

        var uniqueSeries: [Int: Movie] = [:]
        for series in allSeries {
            uniqueSeries[series.id] = Movie(
                id: series.id,
                title: series.title,
                overview: series.overview,
                releaseDate: series.releaseDate,
                posterPath: series.posterPath,
                genreIDs: series.genreIDs,
                mediaType: .tv
            )
        }

        return Array(uniqueSeries.values).sorted {
            switch ($0.releaseDate, $1.releaseDate) {
            case let (lhs?, rhs?):
                return lhs < rhs
            case (_?, nil):
                return true
            case (nil, _?):
                return false
            case (nil, nil):
                return $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
            }
        }
    }

    private func readAPIKey() throws -> String {
        let apiKey = UserDefaults.standard
            .string(forKey: SettingsKeys.tmdbAPIKey)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        guard !apiKey.isEmpty else {
            throw TMDBError.missingAPIKey
        }
        return apiKey
    }

    private func readLocaleSettings() -> (regionCode: String, languageCode: String) {
        let regionCodeValue = UserDefaults.standard
            .string(forKey: SettingsKeys.regionCode)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()
        let languageCodeValue = UserDefaults.standard
            .string(forKey: SettingsKeys.languageCode)?
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let resolvedRegionCode: String
        if let regionCodeValue, !regionCodeValue.isEmpty {
            resolvedRegionCode = regionCodeValue
        } else {
            resolvedRegionCode = SettingsDefaults.defaultRegionCode
        }

        let resolvedLanguageCode: String
        if let languageCodeValue, !languageCodeValue.isEmpty {
            resolvedLanguageCode = languageCodeValue
        } else {
            resolvedLanguageCode = SettingsDefaults.defaultLanguageCode
        }

        return (
            regionCode: resolvedRegionCode,
            languageCode: resolvedLanguageCode
        )
    }
}

private struct TMDBCountryConfig: Decodable {
    let iso3166_1: String
    let englishName: String
    let nativeName: String?

    enum CodingKeys: String, CodingKey {
        case iso3166_1 = "iso_3166_1"
        case englishName = "english_name"
        case nativeName = "native_name"
    }
}

private extension DateFormatter {
    static let tmdbDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}
