import Foundation

struct Movie: Identifiable, Codable, Hashable {
    let id: Int
    let title: String
    let overview: String
    let releaseDate: Date?
    let posterPath: String?
    let genreIDs: [Int]

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case overview
        case releaseDate = "release_date"
        case posterPath = "poster_path"
        case genreIDs = "genre_ids"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        overview = try container.decodeIfPresent(String.self, forKey: .overview) ?? ""
        releaseDate = try container.decodeIfPresent(Date.self, forKey: .releaseDate)
        posterPath = try container.decodeIfPresent(String.self, forKey: .posterPath)
        genreIDs = try container.decodeIfPresent([Int].self, forKey: .genreIDs) ?? []
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

struct MovieDetail: Codable, Hashable {
    let id: Int
    let title: String
    let overview: String
    let releaseDate: Date?
    let runtime: Int?
    let voteAverage: Double
    let voteCount: Int
    let status: String?
    let tagline: String?
    let backdropPath: String?
    let posterPath: String?
    let genres: [Genre]
    let credits: MovieCreditsResponse?
    let images: MovieImagesResponse?
    let reviews: MovieReviewsResponse?
    let videos: MovieVideosResponse?

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case overview
        case releaseDate = "release_date"
        case runtime
        case voteAverage = "vote_average"
        case voteCount = "vote_count"
        case status
        case tagline
        case backdropPath = "backdrop_path"
        case posterPath = "poster_path"
        case genres
        case credits
        case images
        case reviews
        case videos
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
        guard
            let createdAt,
            let date = ISO8601DateFormatter.full.date(from: createdAt)
        else {
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

private extension ISO8601DateFormatter {
    static let full: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
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
