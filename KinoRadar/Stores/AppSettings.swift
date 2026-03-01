import Foundation
import Combine

struct SettingsDefaults {
    static let defaultRegionCode = "DE"
    static let defaultLanguageCode = "de-DE"
}

struct RegionOption: Identifiable, Hashable {
    let code: String
    let name: String

    var id: String { code }
}

struct LanguageOption: Identifiable, Hashable {
    let code: String
    let name: String

    var id: String { code }
}

struct PredefinedGenreFilter: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var genreIDs: [Int]
}

enum SettingsKeys {
    static let tmdbAPIKey = "settings_tmdb_api_key"
    static let userName = "settings_user_name"
    static let regionCode = "settings_region_code"
    static let languageCode = "settings_language_code"
    static let predefinedGenreFilters = "settings_predefined_genre_filters"
}

@MainActor
final class AppSettings: ObservableObject {
    static let fallbackRegionOptions: [RegionOption] = [
        RegionOption(code: "DE", name: "Deutschland"),
        RegionOption(code: "AT", name: "Oesterreich"),
        RegionOption(code: "CH", name: "Schweiz"),
        RegionOption(code: "US", name: "USA"),
        RegionOption(code: "GB", name: "Vereinigtes Koenigreich"),
        RegionOption(code: "TR", name: "Tuerkei"),
        RegionOption(code: "FR", name: "Frankreich"),
        RegionOption(code: "ES", name: "Spanien"),
        RegionOption(code: "IT", name: "Italien")
    ]

    static let languageOptions: [LanguageOption] = [
        LanguageOption(code: "de-DE", name: "Deutsch"),
        LanguageOption(code: "en-US", name: "Englisch"),
        LanguageOption(code: "tr-TR", name: "Tuerkisch"),
        LanguageOption(code: "fr-FR", name: "Franzoesisch"),
        LanguageOption(code: "es-ES", name: "Spanisch"),
        LanguageOption(code: "it-IT", name: "Italienisch")
    ]

    @Published private(set) var regionOptions: [RegionOption]

    @Published var apiKey: String {
        didSet {
            userDefaults.set(apiKey, forKey: SettingsKeys.tmdbAPIKey)
        }
    }

    @Published var userName: String {
        didSet {
            userDefaults.set(userName, forKey: SettingsKeys.userName)
        }
    }

    @Published var regionCode: String {
        didSet {
            let normalized = regionCode
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .uppercased()
            if normalized != regionCode {
                regionCode = normalized
                return
            }
            if normalized.isEmpty {
                regionCode = SettingsDefaults.defaultRegionCode
                return
            }
            userDefaults.set(normalized, forKey: SettingsKeys.regionCode)
        }
    }

    @Published var languageCode: String {
        didSet {
            let normalized = languageCode.trimmingCharacters(in: .whitespacesAndNewlines)
            if normalized != languageCode {
                languageCode = normalized
                return
            }
            userDefaults.set(normalized, forKey: SettingsKeys.languageCode)
        }
    }

    @Published private(set) var predefinedGenreFilters: [PredefinedGenreFilter] = []

    private let userDefaults: UserDefaults

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        self.apiKey = userDefaults.string(forKey: SettingsKeys.tmdbAPIKey) ?? ""
        self.userName = userDefaults.string(forKey: SettingsKeys.userName) ?? ""
        self.regionCode = userDefaults.string(forKey: SettingsKeys.regionCode) ?? SettingsDefaults.defaultRegionCode
        self.languageCode = userDefaults.string(forKey: SettingsKeys.languageCode) ?? SettingsDefaults.defaultLanguageCode
        self.regionOptions = Self.fallbackRegionOptions

        if
            let data = userDefaults.data(forKey: SettingsKeys.predefinedGenreFilters),
            let decoded = try? JSONDecoder().decode([PredefinedGenreFilter].self, from: data)
        {
            self.predefinedGenreFilters = Self.normalizePredefinedGenreFilters(decoded)
        }
    }

    var trimmedUserName: String {
        userName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var selectedRegionName: String {
        regionOptions.first(where: { $0.code == regionCode })?.name ?? regionCode
    }

    var selectedLanguageName: String {
        Self.languageOptions.first(where: { $0.code == languageCode })?.name ?? languageCode
    }

    func updateRegionOptions(_ options: [RegionOption]) {
        let cleaned = options
            .map { option in
                RegionOption(
                    code: option.code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased(),
                    name: option.name.trimmingCharacters(in: .whitespacesAndNewlines)
                )
            }
            .filter { !$0.code.isEmpty && !$0.name.isEmpty }

        guard !cleaned.isEmpty else {
            regionOptions = Self.fallbackRegionOptions
            return
        }

        var seenCodes: Set<String> = []
        let uniqueSorted = cleaned
            .filter { seenCodes.insert($0.code).inserted }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }

        regionOptions = uniqueSorted

        if !uniqueSorted.contains(where: { $0.code == regionCode }) {
            regionCode = uniqueSorted.first?.code ?? SettingsDefaults.defaultRegionCode
        }
    }

    @discardableResult
    func upsertPredefinedGenreFilter(id: UUID?, name: String, genreIDs: Set<Int>) -> Bool {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let shortName = String(trimmed.prefix(5))
        let normalizedGenreIDs = Array(genreIDs).sorted()

        guard !shortName.isEmpty, !normalizedGenreIDs.isEmpty else {
            return false
        }

        if let id, let index = predefinedGenreFilters.firstIndex(where: { $0.id == id }) {
            predefinedGenreFilters[index].name = shortName
            predefinedGenreFilters[index].genreIDs = normalizedGenreIDs
        } else {
            guard predefinedGenreFilters.count < 2 else {
                return false
            }
            predefinedGenreFilters.append(
                PredefinedGenreFilter(id: UUID(), name: shortName, genreIDs: normalizedGenreIDs)
            )
        }

        predefinedGenreFilters = Self.normalizePredefinedGenreFilters(predefinedGenreFilters)
        persistPredefinedGenreFilters()
        return true
    }

    func deletePredefinedGenreFilter(id: UUID) {
        predefinedGenreFilters.removeAll { $0.id == id }
        persistPredefinedGenreFilters()
    }

    private func persistPredefinedGenreFilters() {
        if let encoded = try? JSONEncoder().encode(predefinedGenreFilters) {
            userDefaults.set(encoded, forKey: SettingsKeys.predefinedGenreFilters)
        }
    }

    private static func normalizePredefinedGenreFilters(_ filters: [PredefinedGenreFilter]) -> [PredefinedGenreFilter] {
        filters
            .map { filter in
                let trimmed = filter.name.trimmingCharacters(in: .whitespacesAndNewlines)
                return PredefinedGenreFilter(
                    id: filter.id,
                    name: String(trimmed.prefix(5)),
                    genreIDs: Array(Set(filter.genreIDs)).sorted()
                )
            }
            .filter { !$0.name.isEmpty && !$0.genreIDs.isEmpty }
            .prefix(2)
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            .map { $0 }
    }
}
