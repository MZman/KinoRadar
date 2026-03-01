import SwiftUI
import SafariServices
import UIKit

struct MovieInfoView: View {
    @EnvironmentObject private var store: MovieStore
    @Environment(\.openURL) private var openURL

    let movie: Movie
    let genreText: String

    @State private var rating: Int = 0
    @State private var comment: String = ""
    @State private var saveMessageVisible = false

    @State private var details: MovieDetail?
    @State private var isLoadingDetails = false
    @State private var detailsError: String?
    @State private var watchProviders: WatchProviderRegionInfo?
    @State private var watchProvidersError: String?
    @State private var selectedImagePreview: MediaPreviewItem?
    @State private var selectedVideoPreview: MovieVideo?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                heroCard

                if isLoadingDetails {
                    ProgressView("Lade Details ...")
                        .frame(maxWidth: .infinity)
                }

                if let detailsError {
                    Text(detailsError)
                        .font(.subheadline)
                        .foregroundStyle(.red)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color.red.opacity(0.08))
                        )
                }

                infoCard
                mediaCard
                streamingCard
                castCard
                newsCard
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
            details = store.cachedMovieDetails(for: movie)
            watchProviders = store.cachedWatchProviders(for: movie)
        }
        .task(id: movie.id) {
            await loadMovieDetails()
        }
        .sheet(item: $selectedImagePreview) { item in
            MediaImagePreviewSheet(item: item)
        }
        .sheet(item: $selectedVideoPreview) { video in
            VideoPreviewSheet(video: video)
        }
    }

    private var heroCard: some View {
        ZStack(alignment: .bottomLeading) {
            heroImage

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
                    detailChip(text: "Wertung \(rating)/5")
                }
            }
            .padding(14)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 230)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color(.separator).opacity(0.25), lineWidth: 1)
        )
    }

    private var heroImage: some View {
        Group {
            if let backdropURL {
                AsyncImage(url: backdropURL) { phase in
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
                        fallbackHero
                    @unknown default:
                        fallbackHero
                    }
                }
            } else {
                fallbackHero
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 230)
    }

    private var fallbackHero: some View {
        ZStack {
            Color(.systemGray4)
            VStack(spacing: 8) {
                Image(systemName: "film")
                    .font(.system(size: 36))
                    .foregroundStyle(.white.opacity(0.85))
                Text("Kein Bild verfuegbar")
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.85))
            }
        }
    }

    private var infoCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Infos zum Film")
                .font(.title3.bold())

            if let tagline = details?.tagline?.trimmingCharacters(in: .whitespacesAndNewlines), !tagline.isEmpty {
                Text(tagline)
                    .font(.subheadline.italic())
                    .foregroundStyle(.secondary)
            }

            Text(overviewText)
                .font(.body)
                .foregroundStyle(.secondary)

            HStack(spacing: 16) {
                infoLine(label: "Release", value: releaseDateText)
                infoLine(label: "Laufzeit", value: runtimeText)
            }

            HStack(spacing: 16) {
                infoLine(label: "Bewertung", value: voteAverageText)
                infoLine(label: "Stimmen", value: voteCountText)
            }

            if !genreNames.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(genreNames, id: \.self) { genreName in
                            detailChip(text: genreName)
                        }
                    }
                    .padding(.vertical, 2)
                }
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

    private var mediaCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Fotos & Poster")
                .font(.title3.bold())

            if backdropImages.isEmpty && posterImages.isEmpty {
                Text("Keine Bilder verfuegbar.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if !backdropImages.isEmpty {
                Text("Hintergrundbilder")
                    .font(.headline)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(backdropImages) { image in
                            Button {
                                selectedImagePreview = MediaPreviewItem(
                                    url: image.imageURL,
                                    title: "\(movie.title) - Hintergrund"
                                )
                            } label: {
                                MediaImageCell(url: image.imageURL, size: CGSize(width: 220, height: 124))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }

            if !posterImages.isEmpty {
                Text("Poster")
                    .font(.headline)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(posterImages) { image in
                            Button {
                                selectedImagePreview = MediaPreviewItem(
                                    url: image.imageURL,
                                    title: "\(movie.title) - Poster"
                                )
                            } label: {
                                MediaImageCell(url: image.imageURL, size: CGSize(width: 110, height: 165))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }

            if !trailerVideos.isEmpty {
                Text("Videos")
                    .font(.headline)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(trailerVideos) { video in
                            Button {
                                selectedVideoPreview = video
                            } label: {
                                MovieVideoCell(video: video)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
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

    private var streamingCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Streamen (JustWatch)")
                .font(.title3.bold())

            if let watchProvidersError {
                Text(watchProvidersError)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else if !hasStreamingProviders {
                Text("Keine Streaming-Infos verfuegbar.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                if !streamFlatrateProviders.isEmpty {
                    providerCategoryRow(title: "Abo", providers: streamFlatrateProviders)
                }
                if !streamFreeProviders.isEmpty {
                    providerCategoryRow(title: "Kostenlos", providers: streamFreeProviders)
                }
                if !streamAdsProviders.isEmpty {
                    providerCategoryRow(title: "Mit Werbung", providers: streamAdsProviders)
                }
                if !streamRentProviders.isEmpty {
                    providerCategoryRow(title: "Leihen", providers: streamRentProviders)
                }
                if !streamBuyProviders.isEmpty {
                    providerCategoryRow(title: "Kaufen", providers: streamBuyProviders)
                }
            }

            if let linkString = watchProviders?.link, let linkURL = URL(string: linkString) {
                Link(destination: linkURL) {
                    Label("Mehr Streaming-Infos", systemImage: "arrow.up.right.square")
                        .font(.subheadline.weight(.semibold))
                }
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

    private var castCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Schauspieler")
                .font(.title3.bold())

            if castMembers.isEmpty {
                Text("Keine Schauspieler-Infos verfuegbar.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: 12) {
                        ForEach(castMembers) { member in
                            NavigationLink {
                                ActorInfoView(castMember: member)
                            } label: {
                                CastMemberCard(member: member)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
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

    private var newsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Nachrichten")
                .font(.title3.bold())

            if reviewItems.isEmpty {
                Text("Keine Nachrichten/Reviews verfuegbar.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(reviewItems) { review in
                    ReviewCard(review: review)
                }
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

    private func detailChip(text: String) -> some View {
        Text(text)
            .font(.caption.bold())
            .foregroundStyle(.primary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color(.systemGray6))
            )
    }

    private func infoLine(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline.weight(.semibold))
                .lineLimit(2)
        }
    }

    @ViewBuilder
    private func providerCategoryRow(title: String, providers: [WatchProvider]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(providers) { provider in
                        Button {
                            openStreamingProvider(provider)
                        } label: {
                            WatchProviderChip(provider: provider)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func loadMovieDetails() async {
        if details?.id != movie.id {
            details = nil
            watchProviders = nil
        }

        isLoadingDetails = true
        detailsError = nil
        watchProvidersError = nil

        do {
            details = try await store.fetchMovieDetails(for: movie, forceRefresh: true)
        } catch {
            detailsError = (error as? LocalizedError)?.errorDescription ?? "Details konnten nicht geladen werden."
        }

        do {
            watchProviders = try await store.fetchWatchProviders(for: movie, forceRefresh: true)
        } catch {
            watchProviders = nil
            watchProvidersError = (error as? LocalizedError)?.errorDescription ?? "Streaming-Infos konnten nicht geladen werden."
        }

        isLoadingDetails = false
    }

    private var backdropURL: URL? {
        details?.backdropURL ?? details?.posterURL ?? movie.posterURL
    }

    private var overviewText: String {
        let detailOverview = details?.overview.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !detailOverview.isEmpty {
            return detailOverview
        }

        let baseOverview = movie.overview.trimmingCharacters(in: .whitespacesAndNewlines)
        if !baseOverview.isEmpty {
            return baseOverview
        }

        return "Keine Beschreibung verfuegbar."
    }

    private var genreNames: [String] {
        if let detailGenres = details?.genres, !detailGenres.isEmpty {
            return detailGenres.map(\.name)
        }
        return genreText
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    private var primaryGenreName: String {
        genreNames.first ?? "Unbekannt"
    }

    private var releaseDateText: String {
        if let releaseDate = details?.releaseDate {
            return Movie.releaseDateFormatter.string(from: releaseDate)
        }
        return movie.releaseDateText
    }

    private var releaseYearText: String {
        if let releaseDate = details?.releaseDate ?? movie.releaseDate {
            return String(Calendar.current.component(.year, from: releaseDate))
        }
        return "Unbekannt"
    }

    private var runtimeText: String {
        guard let runtime = details?.runtime, runtime > 0 else {
            return "Unbekannt"
        }
        let hours = runtime / 60
        let minutes = runtime % 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }

    private var voteAverageText: String {
        let value = details?.voteAverage ?? 0
        if value <= 0 {
            return "Unbekannt"
        }
        return String(format: "%.1f / 10", value)
    }

    private var voteCountText: String {
        let count = details?.voteCount ?? 0
        if count <= 0 {
            return "0"
        }
        return count.formatted(.number)
    }

    private var backdropImages: [MovieImage] {
        Array((details?.images?.backdrops ?? []).prefix(12))
    }

    private var posterImages: [MovieImage] {
        Array((details?.images?.posters ?? []).prefix(12))
    }

    private var trailerVideos: [MovieVideo] {
        let videos = details?.videos?.results ?? []
        let filtered = videos.filter { video in
            video.youtubeURL != nil && (video.type == "Trailer" || video.type == "Teaser" || video.type == "Clip")
        }
        return Array(filtered.prefix(8))
    }

    private var castMembers: [MovieCastMember] {
        let cast = details?.credits?.cast ?? []
        let sorted = cast.sorted { lhs, rhs in
            switch (lhs.order, rhs.order) {
            case let (l?, r?):
                return l < r
            case (_?, nil):
                return true
            case (nil, _?):
                return false
            case (nil, nil):
                return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }
        }
        return Array(sorted.prefix(20))
    }

    private var reviewItems: [MovieReview] {
        Array((details?.reviews?.results ?? []).prefix(4))
    }

    private var streamFlatrateProviders: [WatchProvider] {
        uniqueProviders(from: watchProviders?.flatrate)
    }

    private var streamFreeProviders: [WatchProvider] {
        uniqueProviders(from: watchProviders?.free)
    }

    private var streamAdsProviders: [WatchProvider] {
        uniqueProviders(from: watchProviders?.ads)
    }

    private var streamRentProviders: [WatchProvider] {
        uniqueProviders(from: watchProviders?.rent)
    }

    private var streamBuyProviders: [WatchProvider] {
        uniqueProviders(from: watchProviders?.buy)
    }

    private var hasStreamingProviders: Bool {
        !streamFlatrateProviders.isEmpty ||
            !streamFreeProviders.isEmpty ||
            !streamAdsProviders.isEmpty ||
            !streamRentProviders.isEmpty ||
            !streamBuyProviders.isEmpty
    }

    private func uniqueProviders(from providers: [WatchProvider]?) -> [WatchProvider] {
        guard let providers else {
            return []
        }
        var seen = Set<Int>()
        return providers.filter { provider in
            seen.insert(provider.id).inserted
        }
    }

    private func openStreamingProvider(_ provider: WatchProvider) {
        let candidates = providerDestinationURLs(for: provider)
        openCandidateURLs(candidates)
    }

    private func openCandidateURLs(_ urls: [URL], at index: Int = 0) {
        guard index < urls.count else {
            return
        }
        openURL(urls[index]) { accepted in
            if !accepted {
                openCandidateURLs(urls, at: index + 1)
            }
        }
    }

    private func providerDestinationURLs(for provider: WatchProvider) -> [URL] {
        let normalizedProvider = provider.providerName.lowercased()
        let encodedTitle = movie.title
            .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? movie.title

        var urls: [URL] = []

        if let justWatchLink = watchProviders?.link {
            appendURL(justWatchLink, to: &urls)
        }

        if normalizedProvider.contains("disney") {
            appendURL("disneyplus://", to: &urls)
            appendURL("https://www.disneyplus.com/search/\(encodedTitle)", to: &urls)
        } else if normalizedProvider.contains("netflix") {
            appendURL("nflx://www.netflix.com/search?q=\(encodedTitle)", to: &urls)
            appendURL("https://www.netflix.com/search?q=\(encodedTitle)", to: &urls)
        } else if normalizedProvider.contains("amazon") || normalizedProvider.contains("prime video") {
            appendURL("primevideo://search?query=\(encodedTitle)", to: &urls)
            appendURL("https://www.primevideo.com/search/ref=atv_nb_sr?phrase=\(encodedTitle)", to: &urls)
        } else if normalizedProvider.contains("apple tv") {
            appendURL("videos://", to: &urls)
            appendURL("https://tv.apple.com/search?term=\(encodedTitle)", to: &urls)
        } else if normalizedProvider.contains("hulu") {
            appendURL("hulu://", to: &urls)
            appendURL("https://www.hulu.com/search?q=\(encodedTitle)", to: &urls)
        } else if normalizedProvider.contains("max") {
            appendURL("hbomax://", to: &urls)
            appendURL("https://play.max.com/search?q=\(encodedTitle)", to: &urls)
        } else if normalizedProvider.contains("paramount") {
            appendURL("paramountplus://", to: &urls)
            appendURL("https://www.paramountplus.com/search/?q=\(encodedTitle)", to: &urls)
        } else if normalizedProvider.contains("peacock") {
            appendURL("peacock://", to: &urls)
            appendURL("https://www.peacocktv.com/search?q=\(encodedTitle)", to: &urls)
        }

        appendURL("https://www.justwatch.com/search?q=\(encodedTitle)", to: &urls)

        return uniqueURLs(urls)
    }

    private func appendURL(_ value: String, to urls: inout [URL]) {
        guard let url = URL(string: value) else {
            return
        }
        urls.append(url)
    }

    private func uniqueURLs(_ urls: [URL]) -> [URL] {
        var seen: Set<String> = []
        return urls.filter { seen.insert($0.absoluteString).inserted }
    }
}

private struct MediaPreviewItem: Identifiable {
    let id = UUID()
    let url: URL?
    let title: String
}

private struct MediaImagePreviewSheet: View {
    @Environment(\.dismiss) private var dismiss

    let item: MediaPreviewItem

    @State private var isSaving = false
    @State private var saveMessage: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    AsyncImage(url: item.url) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFit()
                        case .empty:
                            ProgressView("Lade Bild ...")
                                .frame(maxWidth: .infinity, minHeight: 240)
                        case .failure:
                            fallback
                        @unknown default:
                            fallback
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .padding(.horizontal, 12)

                    if let saveMessage {
                        Text(saveMessage)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 16)
            }
            .navigationTitle(item.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Schliessen") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task {
                            await saveImage()
                        }
                    } label: {
                        if isSaving {
                            ProgressView()
                        } else {
                            Label("Speichern", systemImage: "square.and.arrow.down")
                        }
                    }
                    .disabled(item.url == nil || isSaving)
                }
            }
        }
    }

    private var fallback: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(.systemGray5))
            Image(systemName: "photo")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 240)
    }

    private func saveImage() async {
        guard let url = item.url else {
            saveMessage = "Bild konnte nicht gespeichert werden."
            return
        }

        isSaving = true
        defer { isSaving = false }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            guard let image = UIImage(data: data) else {
                saveMessage = "Bildformat wird nicht unterstuetzt."
                return
            }
            UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
            saveMessage = "Bild wurde in Fotos gespeichert."
        } catch {
            saveMessage = "Speichern fehlgeschlagen."
        }
    }
}

private struct VideoPreviewSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    let video: MovieVideo

    var body: some View {
        NavigationStack {
            Group {
                if let url = video.youtubeURL {
                    SafariView(url: url)
                        .ignoresSafeArea(.container, edges: .bottom)
                } else {
                    Text("Video-URL nicht verfuegbar.")
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle(video.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Schliessen") {
                        dismiss()
                    }
                }
                if let youtubeURL = video.youtubeURL {
                    ToolbarItem(placement: .topBarTrailing) {
                        ShareLink(item: youtubeURL) {
                            Image(systemName: "square.and.arrow.up")
                        }
                    }

                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            if let youtubeAppURL = video.youtubeAppURL {
                                openURL(youtubeAppURL)
                            } else {
                                openURL(youtubeURL)
                            }
                        } label: {
                            Image(systemName: "play.rectangle")
                        }
                        .accessibilityLabel("In YouTube oeffnen")
                    }
                }
            }
        }
    }
}

private extension MovieVideo {
    var youtubeAppURL: URL? {
        URL(string: "youtube://watch?v=\(key)")
    }
}

private struct SafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        SFSafariViewController(url: url)
    }

    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}

private struct MediaImageCell: View {
    let url: URL?
    let size: CGSize

    var body: some View {
        AsyncImage(url: url) { phase in
            switch phase {
            case .success(let image):
                image
                    .resizable()
                    .scaledToFill()
            case .empty:
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color(.systemGray5))
                    ProgressView()
                }
            case .failure:
                fallback
            @unknown default:
                fallback
            }
        }
        .frame(width: size.width, height: size.height)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color(.separator).opacity(0.22), lineWidth: 1)
        )
    }

    private var fallback: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(.systemGray5))
            Image(systemName: "photo")
                .foregroundStyle(.secondary)
        }
    }
}

private struct MovieVideoCell: View {
    let video: MovieVideo

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "play.circle.fill")
                    .foregroundStyle(.red)
                Text(video.type)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text(video.name)
                .font(.subheadline.weight(.semibold))
                .lineLimit(2)
        }
        .padding(10)
        .frame(width: 210, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(.systemGray6))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color(.separator).opacity(0.18), lineWidth: 1)
        )
    }
}

private struct WatchProviderChip: View {
    let provider: WatchProvider

    var body: some View {
        VStack(spacing: 6) {
            AsyncImage(url: provider.logoURL) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                case .empty:
                    ZStack {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color(.systemGray5))
                        ProgressView()
                    }
                case .failure:
                    fallback
                @unknown default:
                    fallback
                }
            }
            .frame(width: 54, height: 54)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            Text(provider.providerName)
                .font(.caption)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .frame(width: 72)
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(.systemGray6))
        )
    }

    private var fallback: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color(.systemGray5))
            Image(systemName: "play.tv")
                .foregroundStyle(.secondary)
        }
    }
}

private struct CastMemberCard: View {
    let member: MovieCastMember

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            AsyncImage(url: member.profileURL) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                case .empty:
                    ZStack {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color(.systemGray5))
                        ProgressView()
                    }
                case .failure:
                    fallback
                @unknown default:
                    fallback
                }
            }
            .frame(width: 120, height: 150)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            Text(member.name)
                .font(.subheadline.bold())
                .lineLimit(2)

            Text(member.character?.isEmpty == false ? member.character! : "Unbekannte Rolle")
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .padding(8)
        .frame(width: 136, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(.systemGray6))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color(.separator).opacity(0.16), lineWidth: 1)
        )
    }

    private var fallback: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(.systemGray5))
            Image(systemName: "person.crop.rectangle")
                .foregroundStyle(.secondary)
        }
    }
}

private struct ReviewCard: View {
    let review: MovieReview

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(review.author)
                    .font(.subheadline.bold())
                Spacer()
                Text(review.createdDateText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text(review.content)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(5)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(.systemGray6))
        )
    }
}

private struct ActorInfoView: View {
    @EnvironmentObject private var store: MovieStore

    let castMember: MovieCastMember

    @State private var details: PersonDetail?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var selectedImagePreview: MediaPreviewItem?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                profileHero

                if isLoading {
                    ProgressView("Lade Schauspieler-Infos ...")
                        .frame(maxWidth: .infinity)
                }

                if let errorMessage {
                    Text(errorMessage)
                        .font(.subheadline)
                        .foregroundStyle(.red)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color.red.opacity(0.08))
                        )
                }

                bioCard
                actorImagesCard
                filmographyCard
                socialCard
            }
            .padding(12)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(castMember.name)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            details = store.cachedPersonDetails(for: castMember.id)
        }
        .task(id: castMember.id) {
            await loadActorDetails()
        }
        .sheet(item: $selectedImagePreview) { item in
            MediaImagePreviewSheet(item: item)
        }
    }

    private var profileHero: some View {
        HStack(alignment: .top, spacing: 12) {
            AsyncImage(url: details?.profileURL ?? castMember.profileURL) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                case .empty:
                    ZStack {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color(.systemGray5))
                        ProgressView()
                    }
                case .failure:
                    fallbackProfile
                @unknown default:
                    fallbackProfile
                }
            }
            .frame(width: 128, height: 180)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 8) {
                Text(details?.name ?? castMember.name)
                    .font(.title3.bold())

                if let department = details?.knownForDepartment, !department.isEmpty {
                    actorInfoRow(label: "Bereich", value: department)
                }

                actorInfoRow(label: "Rolle", value: castMember.character ?? "Unbekannt")

                if let birthday = details?.birthday {
                    actorInfoRow(label: "Geburt", value: Movie.releaseDateFormatter.string(from: birthday))
                }

                if let deathday = details?.deathday {
                    actorInfoRow(label: "Tod", value: Movie.releaseDateFormatter.string(from: deathday))
                }

                if let place = details?.placeOfBirth, !place.isEmpty {
                    actorInfoRow(label: "Ort", value: place)
                }

                if let popularity = details?.popularity {
                    actorInfoRow(label: "Popularitaet", value: String(format: "%.1f", popularity))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(.systemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color(.separator).opacity(0.2), lineWidth: 1)
        )
    }

    private var bioCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Biografie")
                .font(.title3.bold())

            Text(bioText)
                .font(.body)
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(.systemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color(.separator).opacity(0.2), lineWidth: 1)
        )
    }

    private var actorImagesCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Bilder")
                .font(.title3.bold())

            if actorImages.isEmpty {
                Text("Keine Bilder verfuegbar.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(actorImages) { image in
                            Button {
                                selectedImagePreview = MediaPreviewItem(
                                    url: image.imageURL,
                                    title: details?.name ?? castMember.name
                                )
                            } label: {
                                MediaImageCell(url: image.imageURL, size: CGSize(width: 120, height: 170))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(.systemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color(.separator).opacity(0.2), lineWidth: 1)
        )
    }

    private var filmographyCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Filmografie")
                .font(.title3.bold())

            if filmography.isEmpty {
                Text("Keine Filmografie verfuegbar.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(filmography) { credit in
                    NavigationLink {
                        MovieInfoView(
                            movie: credit.asMovieItem,
                            genreText: genreText(for: credit)
                        )
                    } label: {
                        HStack(alignment: .top, spacing: 10) {
                            AsyncImage(url: credit.posterURL) { phase in
                                switch phase {
                                case .success(let image):
                                    image
                                        .resizable()
                                        .scaledToFill()
                                case .empty:
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                                            .fill(Color(.systemGray5))
                                        ProgressView()
                                    }
                                case .failure:
                                    fallbackPoster
                                @unknown default:
                                    fallbackPoster
                                }
                            }
                            .frame(width: 48, height: 70)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                            VStack(alignment: .leading, spacing: 4) {
                                Text(credit.displayTitle)
                                    .font(.subheadline.bold())
                                    .lineLimit(2)

                                Text("\(credit.releaseYearText)  |  \(credit.character ?? "Unbekannt")")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)

                                Text(credit.normalizedMediaType == .tv ? "Serie" : "Film")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer(minLength: 0)
                        }
                        .padding(.vertical, 3)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(.systemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color(.separator).opacity(0.2), lineWidth: 1)
        )
    }

    private var socialCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Weitere Infos")
                .font(.title3.bold())

            let hasSocial = instagramURL != nil || twitterURL != nil || facebookURL != nil || homepageURL != nil
            if !hasSocial {
                Text("Keine weiteren Links verfuegbar.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                if let instagramURL {
                    Link(destination: instagramURL) {
                        Label("Instagram", systemImage: "link")
                    }
                }
                if let twitterURL {
                    Link(destination: twitterURL) {
                        Label("Twitter/X", systemImage: "link")
                    }
                }
                if let facebookURL {
                    Link(destination: facebookURL) {
                        Label("Facebook", systemImage: "link")
                    }
                }
                if let homepageURL {
                    Link(destination: homepageURL) {
                        Label("Homepage", systemImage: "link")
                    }
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(.systemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color(.separator).opacity(0.2), lineWidth: 1)
        )
    }

    private func actorInfoRow(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline.weight(.semibold))
                .lineLimit(2)
        }
    }

    private func loadActorDetails() async {
        if details?.id != castMember.id {
            details = nil
        }

        isLoading = true
        errorMessage = nil

        do {
            details = try await store.fetchPersonDetails(for: castMember.id, forceRefresh: true)
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "Schauspieler-Infos konnten nicht geladen werden."
        }

        isLoading = false
    }

    private var bioText: String {
        let text = details?.biography.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if text.isEmpty {
            return "Keine Biografie verfuegbar."
        }
        return text
    }

    private var actorImages: [PersonImage] {
        Array((details?.images?.profiles ?? []).prefix(15))
    }

    private var filmography: [PersonMovieCredit] {
        let rawCredits = details?.combinedCredits?.cast ?? details?.movieCredits?.cast ?? []
        var uniqueCreditsByKey: [String: PersonMovieCredit] = [:]

        for credit in rawCredits {
            let mediaType = credit.normalizedMediaType.rawValue
            let key = "\(mediaType)-\(credit.id)"

            guard let existing = uniqueCreditsByKey[key] else {
                uniqueCreditsByKey[key] = credit
                continue
            }

            switch (credit.releaseDate, existing.releaseDate) {
            case let (newDate?, oldDate?):
                if newDate > oldDate {
                    uniqueCreditsByKey[key] = credit
                }
            case (_?, nil):
                uniqueCreditsByKey[key] = credit
            default:
                break
            }
        }

        return uniqueCreditsByKey.values.sorted { lhs, rhs in
            switch (lhs.releaseDate, rhs.releaseDate) {
            case let (l?, r?):
                return l > r
            case (_?, nil):
                return true
            case (nil, _?):
                return false
            case (nil, nil):
                return lhs.displayTitle.localizedCaseInsensitiveCompare(rhs.displayTitle) == .orderedAscending
            }
        }
    }

    private func genreText(for credit: PersonMovieCredit) -> String {
        let lookup = Dictionary(
            uniqueKeysWithValues: store.sortedGenres(for: credit.normalizedMediaType).map { ($0.id, $0.name) }
        )
        let names = credit.genreIDs.compactMap { lookup[$0] }
        if names.isEmpty {
            return "Unbekannt"
        }
        return names.joined(separator: ", ")
    }

    private var instagramURL: URL? {
        guard let id = details?.externalIDs?.instagramID, !id.isEmpty else {
            return nil
        }
        return URL(string: "https://instagram.com/\(id)")
    }

    private var twitterURL: URL? {
        guard let id = details?.externalIDs?.twitterID, !id.isEmpty else {
            return nil
        }
        return URL(string: "https://x.com/\(id)")
    }

    private var facebookURL: URL? {
        guard let id = details?.externalIDs?.facebookID, !id.isEmpty else {
            return nil
        }
        return URL(string: "https://facebook.com/\(id)")
    }

    private var homepageURL: URL? {
        guard let homepage = details?.homepage, !homepage.isEmpty else {
            return nil
        }
        return URL(string: homepage)
    }

    private var fallbackProfile: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(.systemGray5))
            Image(systemName: "person.crop.rectangle")
                .foregroundStyle(.secondary)
        }
    }

    private var fallbackPoster: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color(.systemGray5))
            Image(systemName: "film")
                .foregroundStyle(.secondary)
        }
    }
}
