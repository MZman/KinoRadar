import SwiftUI

struct RootView: View {
    @EnvironmentObject private var store: MovieStore
    @EnvironmentObject private var settings: AppSettings

    @State private var showSplash = true
    @State private var didStartStartupFlow = false

    var body: some View {
        Group {
            if showSplash {
                SplashScreenView(userName: settings.trimmedUserName)
            } else {
                TabView {
                    NavigationStack {
                        BrowseMoviesView()
                    }
                    .tabItem {
                        Label("Filme", systemImage: "film")
                    }

                    NavigationStack {
                        InterestedMoviesView()
                    }
                    .tabItem {
                        Label("Meine Filme", systemImage: "list.bullet.rectangle.portrait")
                    }

                    NavigationStack {
                        SettingsView()
                    }
                    .tabItem {
                        Label("Einstellungen", systemImage: "gearshape")
                    }
                }
            }
        }
        .task {
            guard !didStartStartupFlow else {
                return
            }
            didStartStartupFlow = true
            await runStartupFlow()
        }
    }

    private func runStartupFlow() async {
        let loadTask = Task { @MainActor in
            await store.refresh()
        }

        let timeoutTask = Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            await MainActor.run {
                if showSplash {
                    withAnimation(.easeOut(duration: 0.25)) {
                        showSplash = false
                    }
                }
            }
        }

        _ = await loadTask.value

        await MainActor.run {
            if showSplash {
                timeoutTask.cancel()
                withAnimation(.easeOut(duration: 0.25)) {
                    showSplash = false
                }
            }
        }
    }
}

private struct SplashScreenView: View {
    let userName: String

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.orange.opacity(0.85), Color.red.opacity(0.85)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 16) {
                Image(systemName: "film.stack.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(.white)

                Text("KinoRadar")
                    .font(.largeTitle.bold())
                    .foregroundStyle(.white)

                if !userName.isEmpty {
                    Text("Hallo \(userName)")
                        .foregroundStyle(.white.opacity(0.9))
                }

                ProgressView("Lade Filme ...")
                    .progressViewStyle(.circular)
                    .tint(.white)
                    .foregroundStyle(.white)
            }
            .padding(24)
        }
    }
}
