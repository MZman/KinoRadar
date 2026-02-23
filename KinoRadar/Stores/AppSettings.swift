import Foundation
import Combine

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

enum SettingsKeys {
    static let tmdbAPIKey = "settings_tmdb_api_key"
    static let userName = "settings_user_name"
    static let regionCode = "settings_region_code"
    static let languageCode = "settings_language_code"
}

@MainActor
final class AppSettings: ObservableObject {
    static let defaultRegionCode = "DE"
    static let defaultLanguageCode = "de-DE"

    static let regionOptions: [RegionOption] = [
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

    private let userDefaults: UserDefaults

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        self.apiKey = userDefaults.string(forKey: SettingsKeys.tmdbAPIKey) ?? ""
        self.userName = userDefaults.string(forKey: SettingsKeys.userName) ?? ""
        self.regionCode = userDefaults.string(forKey: SettingsKeys.regionCode) ?? Self.defaultRegionCode
        self.languageCode = userDefaults.string(forKey: SettingsKeys.languageCode) ?? Self.defaultLanguageCode
    }

    var trimmedUserName: String {
        userName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var selectedRegionName: String {
        Self.regionOptions.first(where: { $0.code == regionCode })?.name ?? regionCode
    }

    var selectedLanguageName: String {
        Self.languageOptions.first(where: { $0.code == languageCode })?.name ?? languageCode
    }
}
