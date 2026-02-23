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
