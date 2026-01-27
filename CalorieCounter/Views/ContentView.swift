import SwiftUI
import SwiftData

struct ContentView: View {
    @State private var selectedTab = 0
    @ObservedObject private var settings = UserSettings.shared

    var body: some View {
        TabView(selection: $selectedTab) {
            CameraView()
                .tabItem {
                    Label("Capture", systemImage: "camera.fill")
                }
                .tag(0)

            HistoryView()
                .tabItem {
                    Label("History", systemImage: "clock.fill")
                }
                .tag(1)

            DashboardView()
                .tabItem {
                    Label("Dashboard", systemImage: "chart.bar.fill")
                }
                .tag(2)

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                }
                .tag(3)
        }
        .tint(.green)
        .onAppear {
            // Show settings tab if no API key is configured
            if !settings.hasAPIKey && !settings.hasCompletedOnboarding {
                selectedTab = 3
            }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: MealEntry.self, inMemory: true)
}
