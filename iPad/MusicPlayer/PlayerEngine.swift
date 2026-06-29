import Foundation
import SwiftUI
import UIKit

/// On macOS this app mirrors and drives Spotify over AppleScript. iPadOS apps are
/// sandboxed and can't automate another app, so the iPad build ships a self-contained
/// demo engine: it simulates a now-playing queue so all the visuals — the spinning
/// vinyl, the sweeping tonearm, the Walkman reels, the clock and alarm — come alive.
@MainActor
final class PlayerEngine: ObservableObject {

    enum Status: Equatable {
        case unknown
        case notRunning
        case stopped
        case playing
        case paused
        case automationDenied
    }

    // MARK: Published state
    @Published var status: Status = .paused
    @Published var now: NowPlaying?
    @Published var isPlaying = false
    @Published var currentTime: TimeInterval = 0
    @Published var volume: Double = 0.7
    @Published var isShuffle = false
    @Published var isRepeat = false
    @Published var artwork: UIImage?
    @Published var accent: Color = Color(red: 0.11, green: 0.73, blue: 0.33) // Spotify green
    @Published var spin: Double = 0
    @Published var isFullScreen = false

    // Live-edit guards so the simulated clock doesn't fight the user.
    var isScrubbing = false
    var isAdjustingVolume = false

    // MARK: Demo queue
    private struct DemoTrack {
        let title: String
        let artist: String
        let album: String
        let duration: TimeInterval
        let accent: Color
    }

    private let queue: [DemoTrack] = [
        DemoTrack(title: "Blinding Lights", artist: "The Weeknd",       album: "After Hours",         duration: 200, accent: Color(red: 0.85, green: 0.16, blue: 0.18)),
        DemoTrack(title: "Get Lucky",       artist: "Daft Punk",        album: "Random Access Memories", duration: 248, accent: Color(red: 0.92, green: 0.70, blue: 0.20)),
        DemoTrack(title: "Dreams",          artist: "Fleetwood Mac",    album: "Rumours",             duration: 257, accent: Color(red: 0.86, green: 0.45, blue: 0.18)),
        DemoTrack(title: "Take On Me",      artist: "a-ha",             album: "Hunting High and Low", duration: 225, accent: Color(red: 0.20, green: 0.52, blue: 0.90)),
        DemoTrack(title: "Redbone",         artist: "Childish Gambino", album: "Awaken, My Love!",    duration: 327, accent: Color(red: 0.13, green: 0.62, blue: 0.55)),
        DemoTrack(title: "Bohemian Rhapsody", artist: "Queen",          album: "A Night at the Opera", duration: 354, accent: Color(red: 0.55, green: 0.30, blue: 0.78)),
    ]
    private var index = 0

    private var uiTimer: Timer?
    private var spinTimer: Timer?

    init() {
        load(index: 0)
        // Advance the simulated playhead.
        uiTimer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
        // Vinyl / reel rotation.
        spinTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, self.isPlaying else { return }
                self.spin = (self.spin + 3).truncatingRemainder(dividingBy: 360)
            }
        }
    }

    private func tick() {
        guard isPlaying, !isScrubbing else { return }
        let dur = now?.duration ?? 0
        currentTime += 0.25
        if currentTime >= dur {
            if isRepeat { seek(to: 0) } else { advance(by: 1) }
        }
    }

    // MARK: - Transport

    func togglePlay() {
        isPlaying.toggle()
        status = isPlaying ? .playing : .paused
    }

    func next() { advance(by: isShuffle ? Int.random(in: 1..<queue.count) : 1) }

    func previous() {
        if currentTime > 3 { seek(to: 0) } else { advance(by: -1) }
    }

    func stop() {
        isPlaying = false
        status = .paused
        seek(to: 0)
    }

    func seek(to t: TimeInterval) {
        currentTime = max(0, min(t, now?.duration ?? 0))
    }

    func setVolume(_ v: Double) { volume = v }
    func toggleShuffle() { isShuffle.toggle() }
    func toggleRepeat()  { isRepeat.toggle() }

    /// The Walkman "eject" / status banner hook — try to hand off to the real Spotify app.
    func openSpotify() {
        if let url = URL(string: "spotify:") {
            UIApplication.shared.open(url)
        }
    }

    // MARK: - Queue

    private func advance(by n: Int) {
        let count = queue.count
        index = ((index + n) % count + count) % count
        load(index: index)
        isPlaying = true
        status = .playing
    }

    private func load(index: Int) {
        let t = queue[index]
        now = NowPlaying(title: t.title, artist: t.artist, album: t.album,
                         duration: t.duration, id: "demo-\(index)")
        currentTime = 0
        artwork = nil
        withAnimation(.easeInOut(duration: 0.7)) { accent = t.accent }
    }
}
