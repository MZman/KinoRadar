# KinoRadar (iPhone App)

SwiftUI-App fuer iOS, die aktuelle und kommende Kinofilme anzeigt.

## Funktionen
- Splashscreen beim App-Start (maximal 2 Sekunden), waehrend Filme im Hintergrund laden
- Liste mit `Jetzt im Kino` und `Demnaechst` Filmen
- Auf `Kinofilme` gibt es einen Suchbutton fuer Freitextsuche nach Filmtiteln
- Genre-Filter per rundem Button oben rechts; Auswahl oeffnet sich als Sheet
- `Jetzt im Kino` zeigt nur aktuell laufende Filme
- `Demnaechst` zeigt Filme von heute bis Ende des laufenden Jahres
- Genre-Filter kann zurueckgesetzt werden und als gespeicherter Filter erneut per Klick genutzt werden
- Genre-Auswahl im Filter erfolgt per Wheel-Picker (Rad)
- Bereich `Aktuelle Auswahl speichern` wird erst ueber den Speichern-Button neben `Zuruecksetzen` eingeblendet
- Filme als `interessant` markieren
- Eigene Liste aller markierten Filme
- Sortierung in der eigenen Liste:
  - Alphabetisch
  - Nach Releasedatum
- Detailseite pro Film:
  - Bewertung von 0 bis 5 Sternen
  - Optionaler Kommentar
- Filmzeile mit Poster, Titel, Releasedatum und Genre
- Antippen eines Films oeffnet eine Detailseite mit allen Film-Infos
- Einstellungsseite:
  - TMDB API Key hinterlegen
  - Persoenlichen Namen hinterlegen
  - Region fuer Kinostarts auswaehlen
  - Sprache fuer Filmdaten auswaehlen
- Lokale Speicherung (Merkliste, Film-Infos inkl. Genre, Bewertung, Kommentar, Filter-Presets)

## Setup
1. Projekt in Xcode oeffnen: `KinoRadar/KinoRadar.xcodeproj`
2. App auf iPhone-Simulator starten.
3. In der App zum Tab `Einstellungen` wechseln und den TMDB API Key eintragen.

## API
Die App nutzt The Movie Database (TMDB):
- Endpoint `movie/now_playing`
- Endpoint `discover/movie`
- Endpoint `genre/movie/list`
- Endpoint `search/movie`
