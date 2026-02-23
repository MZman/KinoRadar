import Foundation

struct MovieFeedback: Codable, Equatable {
    var rating: Int
    var comment: String

    static let empty = MovieFeedback(rating: 0, comment: "")
}

