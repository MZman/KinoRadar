import SwiftUI

struct RatingDetailView: View {
    @EnvironmentObject private var store: MovieStore

    let movie: Movie

    @State private var rating: Int = 0
    @State private var comment: String = ""

    var body: some View {
        Form {
            Section("Film") {
                Text(movie.title)
                    .font(.headline)
                Text("Release: \(movie.releaseDateText)")

                if !movie.overview.isEmpty {
                    Text(movie.overview)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Deine Bewertung") {
                StarRatingView(rating: $rating)

                HStack {
                    Text("Aktuell")
                    Spacer()
                    Text("\(rating) / 5 Sterne")
                        .bold()
                }

                Button("Bewertung zuruecksetzen") {
                    rating = 0
                }
            }

            Section("Kommentar (optional)") {
                TextEditor(text: $comment)
                    .frame(minHeight: 120)
            }

            Section {
                Button("Speichern") {
                    store.saveFeedback(for: movie.id, rating: rating, comment: comment)
                }
                .frame(maxWidth: .infinity, alignment: .center)
            }
        }
        .navigationTitle("Bewerten")
        .onAppear {
            let existing = store.feedback(for: movie.id)
            rating = existing.rating
            comment = existing.comment
        }
    }
}

