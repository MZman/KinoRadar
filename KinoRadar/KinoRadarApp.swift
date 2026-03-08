import SwiftUI

@main
struct KinoRadarApp: App {
    @StateObject private var store = MovieStore()
    @StateObject private var settings = AppSettings()
    @StateObject private var localContext = LocalContextStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .environmentObject(settings)
                .environmentObject(localContext)
        }
    }
}
