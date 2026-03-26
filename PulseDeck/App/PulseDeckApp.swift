import SwiftUI

@main
struct PulseDeckApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var store = PulseDeckStore()

    var body: some Scene {
        WindowGroup {
            RootTabView(store: store)
                .onAppear {
                    store.start()
                }
                .onChange(of: scenePhase) { _, newPhase in
                    store.handleScenePhase(newPhase)
                }
        }
    }
}
