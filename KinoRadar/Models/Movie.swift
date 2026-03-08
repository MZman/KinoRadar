import Foundation

enum MediaType: String, Codable, Hashable {
    case movie
    case tv
}

struct Movie: Identifiable, Codable, Hashable {
    let id: Int
    let title: String
    let overview: String
    let releaseDate: Date?
    let posterPath: String?
    let genreIDs: [Int]
    let mediaType: MediaType

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case name
        case overview
        case releaseDate = "release_date"
        case firstAirDate = "first_air_date"
        case posterPath = "poster_path"
        case genreIDs = "genre_ids"
        case mediaType = "media_type"
    }

    init(
        id: Int,
        title: String,
        overview: String,
        releaseDate: Date?,
        posterPath: String?,
        genreIDs: [Int],
        mediaType: MediaType
    ) {
        self.id = id
        self.title = title
        self.overview = overview
        self.releaseDate = releaseDate
        self.posterPath = posterPath
        self.genreIDs = genreIDs
        self.mediaType = mediaType
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)

        let titleFromMovie = try container.decodeIfPresent(String.self, forKey: .title)
        let titleFromTV = try container.decodeIfPresent(String.self, forKey: .name)
        let decodedTitle = titleFromMovie ?? titleFromTV ?? "Unbekannt"
        title = decodedTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "Unbekannt"
            : decodedTitle

        overview = try container.decodeIfPresent(String.self, forKey: .overview) ?? ""
        releaseDate =
            container.decodeTMDBDateIfPresent(forKey: .releaseDate) ??
            container.decodeTMDBDateIfPresent(forKey: .firstAirDate)
        posterPath = try container.decodeIfPresent(String.self, forKey: .posterPath)
        genreIDs = try container.decodeIfPresent([Int].self, forKey: .genreIDs) ?? []

        if let explicitType = try container.decodeIfPresent(MediaType.self, forKey: .mediaType) {
            mediaType = explicitType
        } else if (try container.decodeIfPresent(String.self, forKey: .firstAirDate)) != nil {
            mediaType = .tv
        } else {
            mediaType = .movie
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(overview, forKey: .overview)
        try container.encodeIfPresent(releaseDate, forKey: .releaseDate)
        try container.encodeIfPresent(posterPath, forKey: .posterPath)
        try container.encode(genreIDs, forKey: .genreIDs)
        try container.encode(mediaType, forKey: .mediaType)
    }

    var releaseDateText: String {
        guard let releaseDate else {
            return "Unbekannt"
        }
        return Self.releaseDateFormatter.string(from: releaseDate)
    }

    var posterURL: URL? {
        guard let posterPath else {
            return nil
        }
        return URL(string: "https://image.tmdb.org/t/p/w185\(posterPath)")
    }

    static let releaseDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "de_DE")
        formatter.dateStyle = .medium
        return formatter
    }()
}

struct MovieResponse: Decodable {
    let results: [Movie]
    let totalPages: Int?

    enum CodingKeys: String, CodingKey {
        case results
        case totalPages = "total_pages"
    }
}

struct Genre: Identifiable, Codable, Hashable {
    let id: Int
    let name: String
}

struct GenreResponse: Decodable {
    let genres: [Genre]
}

struct MovieDetail: Decodable, Hashable {
    let id: Int
    let title: String
    let overview: String
    let releaseDate: Date?
    let runtime: Int?
    let numberOfSeasons: Int?
    let numberOfEpisodes: Int?
    let voteAverage: Double
    let voteCount: Int
    let status: String?
    let tagline: String?
    let backdropPath: String?
    let posterPath: String?
    let genres: [Genre]
    let belongsToCollection: MovieCollectionSummary?
    let seasons: [TVSeasonSummary]
    let credits: MovieCreditsResponse?
    let images: MovieImagesResponse?
    let reviews: MovieReviewsResponse?
    let videos: MovieVideosResponse?

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case name
        case overview
        case releaseDate = "release_date"
        case firstAirDate = "first_air_date"
        case runtime
        case episodeRuntime = "episode_run_time"
        case numberOfSeasons = "number_of_seasons"
        case numberOfEpisodes = "number_of_episodes"
        case voteAverage = "vote_average"
        case voteCount = "vote_count"
        case status
        case tagline
        case backdropPath = "backdrop_path"
        case posterPath = "poster_path"
        case genres
        case belongsToCollection = "belongs_to_collection"
        case seasons
        case credits
        case images
        case reviews
        case videos
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)

        let titleFromMovie = try container.decodeIfPresent(String.self, forKey: .title)
        let titleFromTV = try container.decodeIfPresent(String.self, forKey: .name)
        let resolvedTitle = (titleFromMovie ?? titleFromTV ?? "Unbekannt")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        title = resolvedTitle.isEmpty ? "Unbekannt" : resolvedTitle

        overview = try container.decodeIfPresent(String.self, forKey: .overview) ?? ""
        releaseDate =
            container.decodeTMDBDateIfPresent(forKey: .releaseDate)
            ?? container.decodeTMDBDateIfPresent(forKey: .firstAirDate)

        if let runtimeValue = try container.decodeIfPresent(Int.self, forKey: .runtime) {
            runtime = runtimeValue
        } else if let episodeRuntime = try container.decodeIfPresent([Int].self, forKey: .episodeRuntime) {
            runtime = episodeRuntime.first
        } else {
            runtime = nil
        }

        numberOfSeasons = try container.decodeIfPresent(Int.self, forKey: .numberOfSeasons)
        numberOfEpisodes = try container.decodeIfPresent(Int.self, forKey: .numberOfEpisodes)
        voteAverage = try container.decodeIfPresent(Double.self, forKey: .voteAverage) ?? 0
        voteCount = try container.decodeIfPresent(Int.self, forKey: .voteCount) ?? 0
        status = try container.decodeIfPresent(String.self, forKey: .status)
        tagline = try container.decodeIfPresent(String.self, forKey: .tagline)
        backdropPath = try container.decodeIfPresent(String.self, forKey: .backdropPath)
        posterPath = try container.decodeIfPresent(String.self, forKey: .posterPath)
        genres = try container.decodeIfPresent([Genre].self, forKey: .genres) ?? []
        belongsToCollection = try container.decodeIfPresent(MovieCollectionSummary.self, forKey: .belongsToCollection)
        seasons = try container.decodeIfPresent([TVSeasonSummary].self, forKey: .seasons) ?? []
        credits = try container.decodeIfPresent(MovieCreditsResponse.self, forKey: .credits)
        images = try container.decodeIfPresent(MovieImagesResponse.self, forKey: .images)
        reviews = try container.decodeIfPresent(MovieReviewsResponse.self, forKey: .reviews)
        videos = try container.decodeIfPresent(MovieVideosResponse.self, forKey: .videos)
    }

    var backdropURL: URL? {
        guard let backdropPath else {
            return nil
        }
        return URL(string: "https://image.tmdb.org/t/p/w780\(backdropPath)")
    }

    var posterURL: URL? {
        guard let posterPath else {
            return nil
        }
        return URL(string: "https://image.tmdb.org/t/p/w500\(posterPath)")
    }
}

struct MovieCreditsResponse: Codable, Hashable {
    let cast: [MovieCastMember]
}

struct MovieCastMember: Identifiable, Codable, Hashable {
    let id: Int
    let name: String
    let character: String?
    let profilePath: String?
    let order: Int?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case character
        case profilePath = "profile_path"
        case order
    }

    var profileURL: URL? {
        guard let profilePath else {
            return nil
        }
        return URL(string: "https://image.tmdb.org/t/p/w185\(profilePath)")
    }
}

struct MovieImagesResponse: Codable, Hashable {
    let backdrops: [MovieImage]
    let posters: [MovieImage]
}

struct MovieImage: Identifiable, Codable, Hashable {
    let filePath: String
    let width: Int?
    let height: Int?
    let voteAverage: Double?

    enum CodingKeys: String, CodingKey {
        case filePath = "file_path"
        case width
        case height
        case voteAverage = "vote_average"
    }

    var id: String { filePath }

    var imageURL: URL? {
        URL(string: "https://image.tmdb.org/t/p/w500\(filePath)")
    }
}

struct MovieReviewsResponse: Codable, Hashable {
    let results: [MovieReview]
}

struct MovieReview: Identifiable, Codable, Hashable {
    let id: String
    let author: String
    let content: String
    let createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case author
        case content
        case createdAt = "created_at"
    }

    var createdDateText: String {
        guard let createdAt else {
            return "Unbekannt"
        }
        let date = ISO8601DateFormatter.full.date(from: createdAt)
            ?? ISO8601DateFormatter.standard.date(from: createdAt)
        guard let date else {
            return "Unbekannt"
        }
        return Movie.reviewDateFormatter.string(from: date)
    }
}

struct MovieVideosResponse: Codable, Hashable {
    let results: [MovieVideo]
}

struct MovieVideo: Identifiable, Codable, Hashable {
    let id: String
    let key: String
    let name: String
    let site: String
    let type: String
    let official: Bool?

    var youtubeURL: URL? {
        guard site.lowercased() == "youtube" else {
            return nil
        }
        return URL(string: "https://www.youtube.com/watch?v=\(key)")
    }
}

struct MediaListResponse: Decodable {
    let results: [Movie]
}

struct MovieCollectionSummary: Codable, Hashable {
    let id: Int
    let name: String
    let posterPath: String?
    let backdropPath: String?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case posterPath = "poster_path"
        case backdropPath = "backdrop_path"
    }
}

struct MovieCollectionDetail: Codable, Hashable {
    let id: Int
    let name: String
    let overview: String?
    let parts: [MovieCollectionPart]
}

struct MovieCollectionPart: Identifiable, Codable, Hashable {
    let id: Int
    let title: String
    let overview: String
    let releaseDate: Date?
    let posterPath: String?
    let genreIDs: [Int]
    let mediaType: MediaType

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case name
        case overview
        case releaseDate = "release_date"
        case firstAirDate = "first_air_date"
        case posterPath = "poster_path"
        case genreIDs = "genre_ids"
        case mediaType = "media_type"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)

        let titleFromMovie = try container.decodeIfPresent(String.self, forKey: .title)
        let titleFromTV = try container.decodeIfPresent(String.self, forKey: .name)
        let resolvedTitle = (titleFromMovie ?? titleFromTV ?? "Unbekannt")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        title = resolvedTitle.isEmpty ? "Unbekannt" : resolvedTitle

        overview = try container.decodeIfPresent(String.self, forKey: .overview) ?? ""
        releaseDate =
            container.decodeTMDBDateIfPresent(forKey: .releaseDate)
            ?? container.decodeTMDBDateIfPresent(forKey: .firstAirDate)
        posterPath = try container.decodeIfPresent(String.self, forKey: .posterPath)
        genreIDs = try container.decodeIfPresent([Int].self, forKey: .genreIDs) ?? []

        if let explicitMediaType = try container.decodeIfPresent(MediaType.self, forKey: .mediaType) {
            mediaType = explicitMediaType
        } else if (try container.decodeIfPresent(String.self, forKey: .firstAirDate)) != nil {
            mediaType = .tv
        } else {
            mediaType = .movie
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(overview, forKey: .overview)
        try container.encodeIfPresent(releaseDate, forKey: .releaseDate)
        try container.encodeIfPresent(posterPath, forKey: .posterPath)
        try container.encode(genreIDs, forKey: .genreIDs)
        try container.encode(mediaType, forKey: .mediaType)
    }

    var asMovie: Movie {
        Movie(
            id: id,
            title: title,
            overview: overview,
            releaseDate: releaseDate,
            posterPath: posterPath,
            genreIDs: genreIDs,
            mediaType: mediaType
        )
    }
}

struct TVSeasonSummary: Identifiable, Codable, Hashable {
    let id: Int
    let name: String
    let seasonNumber: Int
    let episodeCount: Int?
    let airDate: Date?
    let posterPath: String?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case seasonNumber = "season_number"
        case episodeCount = "episode_count"
        case airDate = "air_date"
        case posterPath = "poster_path"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? "Staffel"
        seasonNumber = try container.decodeIfPresent(Int.self, forKey: .seasonNumber) ?? 0
        episodeCount = try container.decodeIfPresent(Int.self, forKey: .episodeCount)
        airDate = container.decodeTMDBDateIfPresent(forKey: .airDate)
        posterPath = try container.decodeIfPresent(String.self, forKey: .posterPath)
    }
}

struct TVSeasonDetail: Codable, Hashable {
    let id: Int
    let name: String
    let overview: String
    let seasonNumber: Int
    let episodes: [TVEpisode]

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case overview
        case seasonNumber = "season_number"
        case episodes
    }
}

struct TVEpisode: Identifiable, Codable, Hashable {
    let id: Int
    let name: String
    let overview: String
    let episodeNumber: Int
    let airDate: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case overview
        case episodeNumber = "episode_number"
        case airDate = "air_date"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? "Episode"
        overview = try container.decodeIfPresent(String.self, forKey: .overview) ?? ""
        episodeNumber = try container.decodeIfPresent(Int.self, forKey: .episodeNumber) ?? 0
        airDate = container.decodeTMDBDateIfPresent(forKey: .airDate)
    }
}

struct WatchProviderResponse: Codable, Hashable {
    let id: Int
    let results: [String: WatchProviderRegionInfo]
}

struct WatchProviderRegionInfo: Codable, Hashable {
    let link: String?
    let flatrate: [WatchProvider]?
    let free: [WatchProvider]?
    let ads: [WatchProvider]?
    let rent: [WatchProvider]?
    let buy: [WatchProvider]?
}

struct WatchProvider: Identifiable, Codable, Hashable {
    let providerID: Int
    let providerName: String
    let logoPath: String?

    enum CodingKeys: String, CodingKey {
        case providerID = "provider_id"
        case providerName = "provider_name"
        case logoPath = "logo_path"
    }

    var id: Int { providerID }

    var logoURL: URL? {
        guard let logoPath else {
            return nil
        }
        return URL(string: "https://image.tmdb.org/t/p/w92\(logoPath)")
    }
}

struct PersonDetail: Codable, Hashable {
    let id: Int
    let name: String
    let biography: String
    let birthday: Date?
    let deathday: Date?
    let placeOfBirth: String?
    let knownForDepartment: String?
    let popularity: Double
    let profilePath: String?
    let homepage: String?
    let images: PersonImagesResponse?
    let movieCredits: PersonMovieCreditsResponse?
    let combinedCredits: PersonMovieCreditsResponse?
    let externalIDs: PersonExternalIDs?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case biography
        case birthday
        case deathday
        case placeOfBirth = "place_of_birth"
        case knownForDepartment = "known_for_department"
        case popularity
        case profilePath = "profile_path"
        case homepage
        case images
        case movieCredits = "movie_credits"
        case combinedCredits = "combined_credits"
        case externalIDs = "external_ids"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        biography = try container.decodeIfPresent(String.self, forKey: .biography) ?? ""
        birthday = container.decodeTMDBDateIfPresent(forKey: .birthday)
        deathday = container.decodeTMDBDateIfPresent(forKey: .deathday)
        placeOfBirth = try container.decodeIfPresent(String.self, forKey: .placeOfBirth)
        knownForDepartment = try container.decodeIfPresent(String.self, forKey: .knownForDepartment)
        popularity = try container.decodeIfPresent(Double.self, forKey: .popularity) ?? 0
        profilePath = try container.decodeIfPresent(String.self, forKey: .profilePath)
        homepage = try container.decodeIfPresent(String.self, forKey: .homepage)
        images = try container.decodeIfPresent(PersonImagesResponse.self, forKey: .images)
        movieCredits = try container.decodeIfPresent(PersonMovieCreditsResponse.self, forKey: .movieCredits)
        combinedCredits = try container.decodeIfPresent(PersonMovieCreditsResponse.self, forKey: .combinedCredits)
        externalIDs = try container.decodeIfPresent(PersonExternalIDs.self, forKey: .externalIDs)
    }

    var profileURL: URL? {
        guard let profilePath else {
            return nil
        }
        return URL(string: "https://image.tmdb.org/t/p/w500\(profilePath)")
    }
}

struct PersonImagesResponse: Codable, Hashable {
    let profiles: [PersonImage]
}

struct PersonImage: Identifiable, Codable, Hashable {
    let filePath: String
    let width: Int?
    let height: Int?

    enum CodingKeys: String, CodingKey {
        case filePath = "file_path"
        case width
        case height
    }

    var id: String { filePath }

    var imageURL: URL? {
        URL(string: "https://image.tmdb.org/t/p/w500\(filePath)")
    }
}

struct PersonMovieCreditsResponse: Codable, Hashable {
    let cast: [PersonMovieCredit]
}

struct PersonMovieCredit: Identifiable, Codable, Hashable {
    let id: Int
    let title: String?
    let character: String?
    let releaseDate: Date?
    let posterPath: String?
    let mediaType: MediaType?
    let genreIDs: [Int]

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case name
        case character
        case releaseDate = "release_date"
        case firstAirDate = "first_air_date"
        case posterPath = "poster_path"
        case mediaType = "media_type"
        case genreIDs = "genre_ids"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        title = try container.decodeIfPresent(String.self, forKey: .title)
            ?? container.decodeIfPresent(String.self, forKey: .name)
        character = try container.decodeIfPresent(String.self, forKey: .character)
        releaseDate =
            container.decodeTMDBDateIfPresent(forKey: .releaseDate)
            ?? container.decodeTMDBDateIfPresent(forKey: .firstAirDate)
        posterPath = try container.decodeIfPresent(String.self, forKey: .posterPath)
        mediaType = try container.decodeIfPresent(MediaType.self, forKey: .mediaType)
        genreIDs = try container.decodeIfPresent([Int].self, forKey: .genreIDs) ?? []
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encodeIfPresent(title, forKey: .title)
        try container.encodeIfPresent(character, forKey: .character)
        try container.encodeIfPresent(releaseDate, forKey: .releaseDate)
        try container.encodeIfPresent(posterPath, forKey: .posterPath)
        try container.encodeIfPresent(mediaType, forKey: .mediaType)
        try container.encode(genreIDs, forKey: .genreIDs)
    }

    var displayTitle: String {
        let trimmed = title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? "Unbekannter Titel" : trimmed
    }

    var releaseYearText: String {
        guard let releaseDate else {
            return "?"
        }
        return String(Calendar.current.component(.year, from: releaseDate))
    }

    var posterURL: URL? {
        guard let posterPath else {
            return nil
        }
        return URL(string: "https://image.tmdb.org/t/p/w185\(posterPath)")
    }

    var normalizedMediaType: MediaType {
        mediaType ?? .movie
    }

    var asMovieItem: Movie {
        Movie(
            id: id,
            title: displayTitle,
            overview: "",
            releaseDate: releaseDate,
            posterPath: posterPath,
            genreIDs: genreIDs,
            mediaType: normalizedMediaType
        )
    }
}

struct PersonExternalIDs: Codable, Hashable {
    let instagramID: String?
    let twitterID: String?
    let facebookID: String?

    enum CodingKeys: String, CodingKey {
        case instagramID = "instagram_id"
        case twitterID = "twitter_id"
        case facebookID = "facebook_id"
    }
}

private extension ISO8601DateFormatter {
    static let full: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    static let standard: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()
}

private extension Movie {
    static let reviewDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "de_DE")
        formatter.dateStyle = .medium
        return formatter
    }()
}

private extension KeyedDecodingContainer {
    func decodeTMDBDateIfPresent(forKey key: Key) -> Date? {
        if let decodedDate = try? decodeIfPresent(Date.self, forKey: key) {
            return decodedDate
        }

        guard let rawDate = (try? decodeIfPresent(String.self, forKey: key)) ?? nil else {
            return nil
        }

        let trimmed = rawDate.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return nil
        }

        return DateFormatter.tmdbFlexibleDateFormatter.date(from: trimmed)
    }
}

private extension DateFormatter {
    static let tmdbFlexibleDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}
