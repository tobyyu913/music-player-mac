import SwiftUI

// MARK: - iPadOS app entry point (SwiftUI lifecycle)

@main
struct MusicPlayerApp: App {
    @StateObject private var engine = PlayerEngine()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(engine)
                .preferredColorScheme(.dark)
                .statusBarHidden(true)
                .persistentSystemOverlays(.hidden)
        }
    }
}
