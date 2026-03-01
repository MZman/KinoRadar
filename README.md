# KinoRadar

KinoRadar ist eine iPhone-App (SwiftUI), mit der du aktuelle und kommende Kinofilme entdecken, nach Genre filtern, markieren und direkt in einer einheitlichen Detailseite bewerten kannst.

## Screenshots

Die folgenden Screenshots sind als Wireframe-Vorlagen vorgesehen:

![Mainseite Wireframe](docs/screenshots/mainseite-wireframe.png)

![Detailseite Wireframe](docs/screenshots/detailseite-wireframe.png)

Hinweis: Lege die zwei von dir bereitgestellten Bilder mit genau diesen Dateinamen in `docs/screenshots/` ab, damit sie im README sichtbar sind.

## Kernfunktionen

### 1. Kinofilme entdecken
- Bereich **Jetzt im Kino** mit aktuell laufenden Filmen
- Bereich **Demnaechst** mit Filmen bis Ende des laufenden Jahres
- Freitext-Suche nach Filmtitel
- Genre-Filter per Button oben rechts

### 2. Merkliste (Meine Filme)
- Filme per Merken-Symbol speichern
- Eigene Liste aller gemerkten Filme
- Sortierung:
  - Alphabetisch
  - Nach Release-Datum

### 3. Einheitliche Detailseite
- Aus **Kinofilme** und **Meine Filme** erreichbar
- Gleiche Struktur und Inhalte auf beiden Wegen
- Poster-/Hero-Bereich, Basisinfos und Zusatzbereiche
- Eigene Bewertung direkt auf der Detailseite

### 4. Bewertung und Notizen
- Sternebewertung von **0 bis 5**
- Optionaler Kommentar
- Lokale Speicherung der Bewertung

### 5. Einstellungen
- TMDB API-Key hinterlegen
- Persönlichen Namen hinterlegen
- Region auswählen (Land)
- Sprache auswählen (lokalisierte Filmdaten)

### 6. Startverhalten
- Splashscreen beim Start
- Daten laden im Hintergrund
- Maximal 2 Sekunden Splash-Dauer

## Technischer Aufbau

- **UI-Framework:** SwiftUI
- **Architektur:** View + Store + Service
- **Datenquelle:** The Movie Database (TMDB)
- **Persistenz:** UserDefaults (z. B. Merkliste, Bewertungen, Filter-Presets)

Projektstruktur:

- `KinoRadar/KinoRadarApp.swift` – App-Entry
- `KinoRadar/RootView.swift` – Tab-Struktur + Splash/Startup
- `KinoRadar/Views/` – Screens und UI-Komponenten
- `KinoRadar/Stores/` – State-Management und Persistenz
- `KinoRadar/Services/TMDBService.swift` – API-Kommunikation
- `KinoRadar/Models/` – Datenmodelle

## API-Endpunkte (TMDB)

Die App nutzt unter anderem:
- `movie/now_playing`
- `discover/movie`
- `genre/movie/list`
- `search/movie`

## Installation und Start

1. Projekt in Xcode öffnen:
   - `KinoRadar/KinoRadar.xcodeproj`
2. iPhone-Simulator oder echtes Gerät auswählen
3. App starten
4. In der App zu **Einstellungen** wechseln und TMDB API-Key eintragen

## Voraussetzungen

- Xcode 15+
- iOS Deployment Target laut Projektkonfiguration
- Gültiger TMDB API-Key

## Hinweise zur Verwendung

- Ohne API-Key können keine Filmdaten geladen werden.
- Region und Sprache beeinflussen Titel, Texte und Verfügbarkeiten.
- Gemerkte Filme und Bewertungen werden lokal gespeichert.

## Nächste sinnvolle Erweiterungen

- Mehr Detaildaten aus der API (z. B. Cast, Bildergalerie, Reviews) vollständig in der Detailseite
- Offline-Cache für erweiterte Filmdetails
- UI-Feinschliff auf Basis finaler Design-Screenshots
