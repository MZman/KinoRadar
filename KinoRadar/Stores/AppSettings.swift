import Foundation
import Combine
import CoreLocation

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

final class LocalContextStore: NSObject, ObservableObject {
    @Published private(set) var cityName: String = ""
    @Published private(set) var countryCode: String = ""
    @Published private(set) var authorizationStatus: CLAuthorizationStatus
    @Published private(set) var isResolving = false
    @Published private(set) var locationErrorMessage: String?

    private let locationManager: CLLocationManager
    private let geocoder = CLGeocoder()

    override init() {
        let manager = CLLocationManager()
        self.locationManager = manager
        self.authorizationStatus = manager.authorizationStatus
        super.init()
        self.locationManager.delegate = self
        applyLocaleFallbackIfNeeded()
    }

    var resolvedCityName: String {
        let trimmed = cityName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            return trimmed
        }
        return Self.cityNameFromTimeZone() ?? "Deine Region"
    }

    func requestLocation() {
        locationErrorMessage = nil
        let status = locationManager.authorizationStatus

        switch status {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            isResolving = true
            locationManager.requestLocation()
        case .restricted, .denied:
            applyLocaleFallbackIfNeeded()
            locationErrorMessage = "Standortzugriff nicht erlaubt. Region wird aus den Geraet-Einstellungen verwendet."
        @unknown default:
            applyLocaleFallbackIfNeeded()
            locationErrorMessage = "Standortstatus unbekannt. Region wird aus den Geraet-Einstellungen verwendet."
        }
    }

    private func applyLocaleFallbackIfNeeded() {
        if countryCode.isEmpty {
            countryCode = Locale.current.region?.identifier.uppercased() ?? SettingsDefaults.defaultRegionCode
        }
        if cityName.isEmpty {
            cityName = Self.cityNameFromTimeZone() ?? ""
        }
    }

    private static func cityNameFromTimeZone() -> String? {
        let identifier = TimeZone.current.identifier
        guard let cityPart = identifier.split(separator: "/").last else {
            return nil
        }
        return cityPart.replacingOccurrences(of: "_", with: " ")
    }
}

extension LocalContextStore: CLLocationManagerDelegate {
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        publishOnMain {
            self.authorizationStatus = manager.authorizationStatus
        }

        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            requestLocation()
        case .restricted, .denied:
            publishOnMain {
                self.applyLocaleFallbackIfNeeded()
                self.isResolving = false
                self.locationErrorMessage = "Standortzugriff nicht erlaubt. Region wird aus den Geraet-Einstellungen verwendet."
            }
        case .notDetermined:
            break
        @unknown default:
            publishOnMain {
                self.applyLocaleFallbackIfNeeded()
                self.isResolving = false
                self.locationErrorMessage = "Standortstatus unbekannt. Region wird aus den Geraet-Einstellungen verwendet."
            }
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.first else {
            publishOnMain {
                self.applyLocaleFallbackIfNeeded()
                self.isResolving = false
            }
            return
        }

        geocoder.reverseGeocodeLocation(location) { [weak self] placemarks, error in
            guard let self else {
                return
            }

            self.publishOnMain {
                defer { self.isResolving = false }

                let placemark = placemarks?.first
                let cityCandidate = placemark?.locality
                    ?? placemark?.subAdministrativeArea
                    ?? placemark?.administrativeArea
                    ?? Self.cityNameFromTimeZone()
                    ?? ""
                let countryCandidate = placemark?.isoCountryCode?.uppercased()
                    ?? Locale.current.region?.identifier.uppercased()
                    ?? SettingsDefaults.defaultRegionCode

                self.cityName = cityCandidate
                self.countryCode = countryCandidate

                if error != nil {
                    self.locationErrorMessage = "Standort nur teilweise aufgeloest. Region wird trotzdem verwendet."
                } else {
                    self.locationErrorMessage = nil
                }
            }
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        publishOnMain {
            self.applyLocaleFallbackIfNeeded()
            self.isResolving = false
            self.locationErrorMessage = "Standort konnte nicht geladen werden. Region wird aus den Geraet-Einstellungen verwendet."
        }
    }

    private func publishOnMain(_ block: @escaping () -> Void) {
        if Thread.isMainThread {
            block()
        } else {
            DispatchQueue.main.async(execute: block)
        }
    }
}
