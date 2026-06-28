import Foundation
import AppKit
import CoreImage
import SwiftUI

@MainActor
final class PlayerEngine: ObservableObject {

    enum Status: Equatable {
        case unknown
        case notRunning          // Spotify app isn't running
        case stopped             // running but nothing loaded
        case playing
        case paused
        case automationDenied    // user hasn't granted Automation permission
    }

    // MARK: Published state (driven by Spotify)
    @Published var status: Status = .unknown
    @Published var now: NowPlaying?
    @Published var isPlaying = false
    @Published var currentTime: TimeInterval = 0
    @Published var volume: Double = 0.7
    @Published var isShuffle = false
    @Published var isRepeat = false
    @Published var artwork: NSImage?
    @Published var accent: Color = Color(red: 0.11, green: 0.73, blue: 0.33) // Spotify green
    @Published var spin: Double = 0
    @Published var isFullScreen = false

    // Live-edit guards so polling doesn't fight the user.
    var isScrubbing = false
    var isAdjustingVolume = false

    private var lastArtworkURL: String?
    private var pollTimer: Timer?
    private var uiTimer: Timer?
    private var spinTimer: Timer?

    init() {
        // Poll Spotify ~1x/sec.
        pollTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in await self?.refresh() }
        }
        // Smooth out the scrubber between polls.
        uiTimer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, self.isPlaying, !self.isScrubbing else { return }
                let dur = self.now?.duration ?? 0
                self.currentTime = min(self.currentTime + 0.25, dur)
            }
        }
        // Vinyl / reel rotation.
        spinTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, self.isPlaying else { return }
                self.spin = (self.spin + 3).truncatingRemainder(dividingBy: 360)
            }
        }
        Task { @MainActor in await refresh() }
    }

    // MARK: - Transport (drives Spotify)

    func togglePlay() {
        isPlaying.toggle()                       // optimistic
        status = isPlaying ? .playing : .paused
        runControl("playpause")
        scheduleQuickRefresh()
    }

    func next() { runControl("next track"); scheduleQuickRefresh() }
    func previous() {
        if currentTime > 3 { seek(to: 0) } else { runControl("previous track"); scheduleQuickRefresh() }
    }

    func stop() {
        isPlaying = false; status = .paused
        runControl("pause")
        seek(to: 0)
    }

    func seek(to t: TimeInterval) {
        currentTime = t
        runControl(String(format: "set player position to %.2f", t))
    }

    func setVolume(_ v: Double) {
        volume = v
        runControl("set sound volume to \(Int((v * 100).rounded()))")
    }

    func toggleShuffle() { isShuffle.toggle(); runControl("set shuffling to \(isShuffle)") }
    func toggleRepeat()  { isRepeat.toggle();  runControl("set repeating to \(isRepeat)") }

    func openSpotify() {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.spotify.client") else { return }
        NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
        scheduleQuickRefresh()
    }

    // MARK: - Polling

    func refresh() async {
        let result = await Self.runAppleScript(Self.fetchScript)
        apply(result)
    }

    private func apply(_ result: Result<String, ScriptError>) {
        switch result {
        case .failure(.automationDenied):
            status = .automationDenied; isPlaying = false; now = nil; artwork = nil
        case .failure:
            status = .notRunning; isPlaying = false
        case .success(let raw):
            let s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            if s == "notrunning" { status = .notRunning; isPlaying = false; now = nil; artwork = nil; return }
            if s == "stopped"    { status = .stopped;    isPlaying = false; return }

            let f = s.components(separatedBy: "\t")
            guard f.count >= 11 else { status = .unknown; return }

            let st = f[0]
            isPlaying = (st == "playing")
            status = isPlaying ? .playing : .paused
            now = NowPlaying(
                title: f[1], artist: f[2], album: f[3],
                duration: (Double(f[4]) ?? 0) / 1000.0,  // Spotify gives ms
                id: f[7]
            )
            if !isScrubbing { currentTime = Double(f[5]) ?? 0 }
            if !isAdjustingVolume { volume = (Double(f[8]) ?? 70) / 100.0 }
            isShuffle = (f[9] == "true")
            isRepeat  = (f[10] == "true")

            let artURL = f[6]
            if artURL != lastArtworkURL {
                lastArtworkURL = artURL
                loadArtwork(from: artURL)
            }
        }
    }

    private func scheduleQuickRefresh() {
        Timer.scheduledTimer(withTimeInterval: 0.3, repeats: false) { [weak self] _ in
            Task { @MainActor in await self?.refresh() }
        }
    }

    // MARK: - Artwork + accent color

    private func loadArtwork(from urlString: String) {
        guard let url = URL(string: urlString), urlString.hasPrefix("http") else {
            artwork = nil; accent = Color(red: 0.11, green: 0.73, blue: 0.33); return
        }
        Task {
            guard let (data, _) = try? await URLSession.shared.data(from: url),
                  let image = NSImage(data: data) else { return }
            let color = Self.averageColor(of: data)
            await MainActor.run {
                self.artwork = image
                if let color { self.accent = color }
            }
        }
    }

    private nonisolated static func averageColor(of data: Data) -> Color? {
        guard let ci = CIImage(data: data) else { return nil }
        let params: [String: Any] = [kCIInputImageKey: ci,
                                     kCIInputExtentKey: CIVector(cgRect: ci.extent)]
        guard let out = CIFilter(name: "CIAreaAverage", parameters: params)?.outputImage else { return nil }
        var px = [UInt8](repeating: 0, count: 4)
        CIContext().render(out, toBitmap: &px, rowBytes: 4,
                           bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
                           format: .RGBA8, colorSpace: CGColorSpaceCreateDeviceRGB())
        return Color(red: Double(px[0]) / 255, green: Double(px[1]) / 255, blue: Double(px[2]) / 255)
    }

    // MARK: - AppleScript plumbing

    enum ScriptError: Error { case automationDenied, launchFailed, other(String) }

    private func runControl(_ command: String) {
        let src = "if application \"Spotify\" is running then tell application \"Spotify\" to \(command)"
        Task.detached { _ = await Self.runAppleScript(src) }
    }

    private static let fetchScript = """
    if application "Spotify" is running then
    \ttell application "Spotify"
    \t\tset pstate to player state as text
    \t\tif pstate is "stopped" then return "stopped"
    \t\tset artURL to ""
    \t\ttry
    \t\t\tset artURL to artwork url of current track
    \t\tend try
    \t\treturn pstate & tab & (name of current track) & tab & (artist of current track) & tab & (album of current track) & tab & (duration of current track) & tab & (player position) & tab & artURL & tab & (id of current track) & tab & (sound volume) & tab & (shuffling) & tab & (repeating)
    \tend tell
    else
    \treturn "notrunning"
    end if
    """

    private nonisolated static func runAppleScript(_ source: String) async -> Result<String, ScriptError> {
        await withCheckedContinuation { cont in
            DispatchQueue.global(qos: .userInitiated).async {
                let task = Process()
                task.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
                task.arguments = ["-e", source]
                let out = Pipe(); let err = Pipe()
                task.standardOutput = out; task.standardError = err
                do { try task.run() } catch { cont.resume(returning: .failure(.launchFailed)); return }
                let oData = out.fileHandleForReading.readDataToEndOfFile()
                let eData = err.fileHandleForReading.readDataToEndOfFile()
                task.waitUntilExit()
                let oStr = String(data: oData, encoding: .utf8) ?? ""
                let eStr = String(data: eData, encoding: .utf8) ?? ""
                if task.terminationStatus != 0 {
                    let low = eStr.lowercased()
                    if eStr.contains("-1743") || low.contains("not authorized") || low.contains("not allowed") {
                        cont.resume(returning: .failure(.automationDenied))
                    } else {
                        cont.resume(returning: .failure(.other(eStr)))
                    }
                } else {
                    cont.resume(returning: .success(oStr))
                }
            }
        }
    }
}
