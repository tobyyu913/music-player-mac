# Music Player

A native macOS SwiftUI player that mirrors **what you're playing in Spotify right now**.
Your current track is shown either as a spinning **vinyl disc** or a **Walkman cassette**
(both display the real album artwork), with a digital clock and an alarm in the top
corners and full transport controls underneath that drive Spotify.

Requires macOS 13+, the Swift toolchain, and the **Spotify desktop app**.

## Run as a real app (installed to /Applications)

```bash
./build_app.sh
```

This compiles a release build, packages **`Music Player.app`** (with a generated vinyl
icon), ad-hoc code-signs it, and installs it to **`/Applications/Music Player.app`**.
Launch it from Spotlight / Launchpad / Finder like any other app.

### Keep the installed app in sync with your edits

```bash
./build_app.sh --watch
```

Leave this running while you work. Every time you save a file under `Sources/`, it
rebuilds, reinstalls to `/Applications`, and relaunches the app automatically — so the
copy on your Mac always reflects your latest change.

Other modes:

```bash
./build_app.sh --no-install   # build "Music Player.app" next to the sources only
swift run                     # quick dev run without packaging
```

### Spotify permission

The first time the app talks to Spotify, macOS shows an **Automation** permission prompt
("…wants to control Spotify"). Click **OK**. If you miss it, enable it under
**System Settings ▸ Privacy & Security ▸ Automation**. (Because the app is ad-hoc signed,
macOS may ask again after a rebuild changes the binary — just click OK.)

## How the Spotify integration works

The app reads and controls Spotify through its built-in AppleScript interface — no API
keys, no login. About once a second it polls:

- player state (playing / paused / stopped), track title, artist, album
- playback position + duration, volume, shuffle and repeat state
- the album **artwork URL** (downloaded and shown on the disc / cassette; its average
  color tints the whole UI)

The transport controls send commands back to Spotify (`playpause`, `next track`,
`previous track`, `set player position`, `set sound volume`, `set shuffling`,
`set repeating`).

If Spotify isn't running, the app shows an **Open Spotify** button.

## Features

- **Two skins** — switch (bottom-left button) between a rotating *Disc* turntable and a
  *Walkman* cassette deck. **Each device has its own working transport buttons** (rewind,
  play/pause, fast-forward, stop).
- **Full-screen turntable cabinet** — go full screen and the disc sits in a **wooden
  turntable plinth** (grain texture, chrome keys) instead of floating on the dark
  background; the layout stays a tidy centered column.
- **Now Playing** — title / artist / album pulled straight from Spotify, updated live;
  the disc still shows the live album art.
- **Digital clock** — top-left, live, with date.
- **Alarm** — top-right. Click the bell to enable it and pick a wake time; it beeps and
  flashes when it fires.
- **Secondary controls** — scrubber with elapsed / remaining time (seeks on release),
  shuffle, repeat, and a volume slider — all driving Spotify.

## Project layout

```
build_app.sh                 # build → bundle → sign → install (+ --watch dev loop)
Sources/MusicPlayer/
  main.swift                 # AppKit bootstrap; hosts SwiftUI; tracks full-screen
  PlayerEngine.swift         # polls + controls Spotify; artwork + accent
  Track.swift                # NowPlaying snapshot model
  ContentView.swift          # layout, skin switcher, backdrop
  VinylView.swift            # disc skin + wooden plinth + device transport bar
  WalkmanView.swift          # Sony TPS-L2-style cassette deck with working transport keys
  ClockAndAlarm.swift        # digital clock + alarm widgets
  PlaybackControlsView.swift # scrubber + shuffle/repeat + volume
```
