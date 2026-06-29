import SwiftUI

enum PlayerSkin: String, CaseIterable, Identifiable {
    case disc = "Disc"
    case walkman = "Walkman"
    var id: String { rawValue }
}

struct ContentView: View {
    @EnvironmentObject private var engine: PlayerEngine
    @State private var skin: PlayerSkin = .disc

    var body: some View {
        GeometryReader { geo in
            ZStack {
                backdrop
                    .ignoresSafeArea()
                    .animation(.easeInOut(duration: 0.7), value: engine.accent)

                if engine.isFullScreen {
                    fullScreenLayout
                } else {
                    windowedLayout
                }
            }
            .overlay(alignment: .bottomLeading) { skinToggle }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            // On iPad, landscape gets the expansive 2/3-device layout; portrait gets the
            // tidy centered column — mirroring the macOS windowed/full-screen split.
            .onAppear { updateLayout(geo.size) }
            .onChange(of: geo.size) { updateLayout(geo.size) }
        }
    }

    private func updateLayout(_ size: CGSize) {
        let full = size.width > size.height
        if engine.isFullScreen != full { engine.isFullScreen = full }
    }

    private var device: some View {
        Group {
            switch skin {
            case .disc:    VinylView()
            case .walkman: WalkmanView()
            }
        }
        .transition(.scale.combined(with: .opacity))
    }

    private var nowPlaying: some View {
        VStack(spacing: 4) {
            Text(engine.now?.title ?? "Not Playing")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(.white)
            Text(engine.now?.artist ?? "Demo")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white.opacity(0.65))
        }
        .lineLimit(1)
    }

    // Portrait: a tidy centered column. Now-playing rides up top under the clock so the
    // device — and its transport bar — drops toward the bottom of the screen.
    private var windowedLayout: some View {
        VStack(spacing: 16) {
            HStack(alignment: .top) {
                DigitalClockView()
                Spacer()
                AlarmView()
            }
            nowPlaying.multilineTextAlignment(.center)
            statusBanner
            Spacer(minLength: 6)
            device.frame(height: 320)
            Spacer(minLength: 0)
        }
        .padding(22)
        .frame(maxWidth: 460)
        .frame(maxWidth: .infinity)
    }

    // Landscape: device fills ~2/3, settings column takes ~1/3.
    private var fullScreenLayout: some View {
        GeometryReader { geo in
            HStack(spacing: 28) {
                device
                    .frame(width: geo.size.width * 0.62)
                    .frame(maxHeight: .infinity)

                VStack(alignment: .leading, spacing: 26) {
                    DigitalClockView(large: true)
                    AlarmView(large: true)
                    Spacer()
                    nowPlaying
                    statusBanner
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
            .padding(36)
        }
    }

    // Floating skin switcher tucked into the bottom-left corner.
    private var skinToggle: some View {
        Button {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                skin = (skin == .disc) ? .walkman : .disc
            }
        } label: {
            Image(systemName: skin == .disc ? "opticaldisc.fill" : "recordingtape")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(.white.opacity(0.12), in: Circle())
                .overlay(Circle().stroke(.white.opacity(0.15), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .padding(16)
    }

    @ViewBuilder
    private var statusBanner: some View {
        switch engine.status {
        case .stopped:
            Text("Press play to begin")
                .font(.system(size: 11))
                .foregroundStyle(.white.opacity(0.5))
        default:
            Color.clear.frame(height: 0)
        }
    }

    private var backdrop: some View {
        ZStack {
            LinearGradient(colors: [Color(white: 0.06), Color(white: 0.02)],
                           startPoint: .top, endPoint: .bottom)
            RadialGradient(colors: [engine.accent.opacity(0.45), .clear],
                           center: .topLeading, startRadius: 10, endRadius: 520)
            RadialGradient(colors: [engine.accent.opacity(0.30), .clear],
                           center: .bottomTrailing, startRadius: 10, endRadius: 520)
        }
    }
}
