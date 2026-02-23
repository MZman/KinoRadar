import SwiftUI

struct MovieInfoView: View {
    @EnvironmentObject private var store: MovieStore

    let movie: Movie
    let genreText: String

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top, spacing: 14) {
                    posterView

                    VStack(alignment: .leading, spacing: 8) {
                        Text(movie.title)
                            .font(.title3.bold())

                        infoRow(label: "Release", value: movie.releaseDateText)
                        infoRow(label: "Genre", value: genreText)

                        if !movie.overview.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            Text("Beschreibung")
                                .font(.headline)
                            Text(movie.overview)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                let feedback = store.feedback(for: movie.id)
                if feedback.rating > 0 || !feedback.comment.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Deine Notiz")
                            .font(.headline)
                        if feedback.rating > 0 {
                            Text("Bewertung: \(feedback.rating) / 5")
                                .foregroundStyle(.secondary)
                        }
                        if !feedback.comment.isEmpty {
                            Text(feedback.comment)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .padding(16)
        }
        .navigationTitle("Filmdetails")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    store.toggleInterested(movie)
                } label: {
                    Image(systemName: store.isInterested(movie) ? "bookmark.fill" : "bookmark")
                        .foregroundStyle(store.isInterested(movie) ? .green : .gray)
                }
                .accessibilityLabel("Merken")
            }
        }
    }

    private var posterView: some View {
        Group {
            if let url = movie.posterURL {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    case .empty:
                        ProgressView()
                            .frame(width: 120, height: 178)
                    case .failure:
                        fallbackPoster
                    @unknown default:
                        fallbackPoster
                    }
                }
            } else {
                fallbackPoster
            }
        }
        .frame(width: 120, height: 178)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var fallbackPoster: some View {
        VStack(spacing: 8) {
            Image(systemName: "film")
                .font(.system(size: 30))
                .foregroundStyle(.secondary)
            Text("Kein Poster verfuegbar")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(width: 120, height: 178)
    }

    private func infoRow(label: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text("\(label):")
                .font(.headline)
            Text(value)
                .foregroundStyle(.secondary)
        }
    }
}
