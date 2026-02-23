import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var store: MovieStore

    @State private var showAPIKey = false

    var body: some View {
        Form {
            Section("Profil") {
                TextField("Dein Name", text: $settings.userName)
                    .textInputAutocapitalization(.words)
            }

            Section("Inhalt") {
                Picker("Region (Kinostarts)", selection: $settings.regionCode) {
                    ForEach(AppSettings.regionOptions) { option in
                        Text("\(option.name) (\(option.code))")
                            .tag(option.code)
                    }
                }

                Picker("Sprache (Anzeige)", selection: $settings.languageCode) {
                    ForEach(AppSettings.languageOptions) { option in
                        Text("\(option.name) (\(option.code))")
                            .tag(option.code)
                    }
                }

                Text("Region bestimmt, in welchem Land Filmstarts gesucht werden. Sprache bestimmt die angezeigte TMDB-Filmdaten-Sprache.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("TMDB API Key") {
                if showAPIKey {
                    TextField("API Key", text: $settings.apiKey)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                } else {
                    SecureField("API Key", text: $settings.apiKey)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }

                Toggle("API Key anzeigen", isOn: $showAPIKey)

                Text("Den API Key bekommst du in deinem TMDB-Konto unter API-Einstellungen.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("Aktionen") {
                Button("Filme neu laden") {
                    Task {
                        await store.refresh()
                    }
                }
            }

            if !settings.trimmedUserName.isEmpty {
                Section("Vorschau") {
                    Text("Hallo \(settings.trimmedUserName)")
                    Text("Region: \(settings.selectedRegionName)")
                        .foregroundStyle(.secondary)
                    Text("Sprache: \(settings.selectedLanguageName)")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Einstellungen")
    }
}
