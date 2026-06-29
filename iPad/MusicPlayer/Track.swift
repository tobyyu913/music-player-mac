import Foundation

/// A snapshot of whatever the player currently has loaded.
struct NowPlaying: Equatable {
    var title: String
    var artist: String
    var album: String
    var duration: TimeInterval   // seconds
    var id: String               // track id (used to detect track changes)
}
