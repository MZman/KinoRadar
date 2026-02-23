import SwiftUI

@main
struct KinoRadarApp: App {
    @StateObject private var store = MovieStore()
    @StateObject private var settings = AppSettings()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .environmentObject(settings)
        }
    }
}
