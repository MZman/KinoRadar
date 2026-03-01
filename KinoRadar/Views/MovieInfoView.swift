import SwiftUI

struct MovieInfoView: View {
    @EnvironmentObject private var store: MovieStore

    let movie: Movie
    let genreText: String

    @State private var rating: Int = 0
    @State private var comment: String = ""
    @State private var saveMessageVisible = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                heroCard
                infoCard
                ratingCard
                actionRow
            }
            .padding(12)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(movie.title)
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
        .onAppear {
            let existing = store.feedback(for: movie.id)
            rating = existing.rating
            comment = existing.comment
        }
    }

    private var heroCard: some View {
        ZStack(alignment: .bottomLeading) {
            posterBanner

            LinearGradient(
                colors: [Color.clear, Color.black.opacity(0.72)],
                startPoint: .top,
                endPoint: .bottom
            )

            VStack(alignment: .leading, spacing: 10) {
                Text(movie.title)
                    .font(.title2.bold())
                    .foregroundStyle(.white)
                    .lineLimit(2)

                HStack(spacing: 8) {
                    detailChip(text: primaryGenreName)
                    detailChip(text: releaseYearText)
                    detailChip(text: "Eigene Wertung \(rating)/5")
                }
            }
            .padding(14)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 225)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color(.separator).opacity(0.25), lineWidth: 1)
        )
    }

    private var posterBanner: some View {
        Group {
            if let url = movie.posterURL {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    case .empty:
                        ZStack {
                            Color(.systemGray5)
                            ProgressView()
                        }
                    case .failure:
                        fallbackPosterBanner
                    @unknown default:
                        fallbackPosterBanner
                    }
                }
            } else {
                fallbackPosterBanner
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 225)
    }

    private var fallbackPosterBanner: some View {
        VStack(spacing: 8) {
            Image(systemName: "film")
                .font(.system(size: 36))
                .foregroundStyle(.white.opacity(0.85))
            Text("Kein Poster verfuegbar")
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.85))
        }
        .frame(maxWidth: .infinity)
        .frame(height: 225)
        .background(Color(.systemGray4))
    }

    private var infoCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Infos zum Film")
                .font(.title3.bold())

            Text(overviewText)
                .font(.body)
                .foregroundStyle(.secondary)

            HStack(spacing: 18) {
                infoLine(label: "Release", value: movie.releaseDateText)
                infoLine(label: "Genre", value: genreText)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(genreNames, id: \.self) { genreName in
                        detailChip(text: genreName)
                    }
                }
                .padding(.vertical, 2)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(.systemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color(.separator).opacity(0.2), lineWidth: 1)
        )
    }

    private var ratingCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Deine Bewertung")
                .font(.title3.bold())

            StarRatingView(rating: $rating)

            Text("Aktuell: \(rating) / 5 Sterne")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text("Kommentar (optional)")
                .font(.subheadline.bold())

            TextEditor(text: $comment)
                .frame(minHeight: 108)
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color(.systemGray6))
                )

            HStack(spacing: 10) {
                Button("Zuruecksetzen") {
                    rating = 0
                    comment = ""
                }
                .buttonStyle(.bordered)

                Button("Bewertung speichern") {
                    store.saveFeedback(for: movie.id, rating: rating, comment: comment)
                    saveMessageVisible = true
                }
                .buttonStyle(.borderedProminent)
            }

            if saveMessageVisible {
                Text("Bewertung gespeichert.")
                    .font(.footnote)
                    .foregroundStyle(.green)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(.systemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color(.separator).opacity(0.2), lineWidth: 1)
        )
    }

    private var actionRow: some View {
        HStack(spacing: 10) {
            Button {
                store.toggleInterested(movie)
            } label: {
                Label(
                    store.isInterested(movie) ? "In Merkliste" : "Auf Merkliste",
                    systemImage: store.isInterested(movie) ? "bookmark.fill" : "plus"
                )
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(store.isInterested(movie) ? .green : .accentColor)

            Button {
                store.saveFeedback(for: movie.id, rating: rating, comment: comment)
                saveMessageVisible = true
            } label: {
                Label("Speichern", systemImage: "square.and.arrow.down")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
    }

    private var overviewText: String {
        let trimmed = movie.overview.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return "Keine Beschreibung verfuegbar."
        }
        return trimmed
    }

    private var genreNames: [String] {
        genreText
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    private var primaryGenreName: String {
        genreNames.first ?? "Unbekannt"
    }

    private var releaseYearText: String {
        guard let releaseDate = movie.releaseDate else {
            return "Unbekannt"
        }
        return String(Calendar.current.component(.year, from: releaseDate))
    }

    private func detailChip(text: String) -> some View {
        Text(text)
            .font(.caption.bold())
            .foregroundStyle(.primary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color(.systemBackground).opacity(0.9))
            )
    }

    private func infoLine(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
        }
    }
}
