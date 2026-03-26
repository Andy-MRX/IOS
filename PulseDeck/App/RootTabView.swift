import SwiftUI

struct RootTabView: View {
    @ObservedObject var store: PulseDeckStore

    var body: some View {
        TabView {
            DashboardView(store: store)
                .tabItem {
                    Label("Dashboard", systemImage: "waveform.path.ecg.rectangle")
                }

            TimelineView(store: store)
                .tabItem {
                    Label("Timeline", systemImage: "clock.arrow.circlepath")
                }

            SettingsView(store: store)
                .tabItem {
                    Label("Settings", systemImage: "slider.horizontal.3")
                }
        }
        .preferredColorScheme(.dark)
        .tint(store.mode.accentColor)
        .toolbarColorScheme(.dark, for: .tabBar)
        .toolbarBackground(PulsePalette.panel.opacity(0.92), for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
    }
}
