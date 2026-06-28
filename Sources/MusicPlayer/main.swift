import AppKit
import SwiftUI

// MARK: - App bootstrap (SwiftPM executable -> AppKit window hosting SwiftUI)

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var window: NSWindow!
    private let engine = PlayerEngine()

    func applicationDidFinishLaunching(_ notification: Notification) {
        let root = ContentView().environmentObject(engine)

        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 440, height: 780),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "Music Player"
        window.titlebarAppearsTransparent = true
        window.isReleasedWhenClosed = false
        window.contentMinSize = NSSize(width: 380, height: 680)
        window.center()
        window.contentView = NSHostingView(rootView: root)
        window.makeKeyAndOrderFront(nil)

        // Track full-screen so the UI can switch to its 2/3-device + 1/3-settings layout.
        let nc = NotificationCenter.default
        nc.addObserver(forName: NSWindow.didEnterFullScreenNotification, object: window, queue: .main) { [engine] _ in
            MainActor.assumeIsolated { engine.isFullScreen = true }
        }
        nc.addObserver(forName: NSWindow.didExitFullScreenNotification, object: window, queue: .main) { [engine] _ in
            MainActor.assumeIsolated { engine.isFullScreen = false }
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}

MainActor.assumeIsolated {
    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    app.setActivationPolicy(.regular)
    app.activate(ignoringOtherApps: true)
    app.run()
}
