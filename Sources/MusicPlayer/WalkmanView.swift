import SwiftUI

/// A Sony TPS-L2-style Walkman: brushed-silver top, cobalt-blue body, vertical SONY /
/// WALKMAN lettering, the left tape-direction arrow, and a cassette window with two big
/// 3-spoke reels. Functional transport keys along the bottom. (No album art.)
struct WalkmanView: View {
    @EnvironmentObject private var engine: PlayerEngine

    private var progress: Double {
        let dur = engine.now?.duration ?? 0
        guard dur > 0 else { return 0 }
        return min(1, max(0, engine.currentTime / dur))
    }

    // TPS-L2 palette
    private let blue       = Color(red: 0.18, green: 0.31, blue: 0.64)
    private let blueDark   = Color(red: 0.12, green: 0.22, blue: 0.50)
    private let silver     = Color(red: 0.86, green: 0.88, blue: 0.90)
    private let silverDark = Color(red: 0.55, green: 0.58, blue: 0.62)
    private let cream      = Color(red: 0.95, green: 0.92, blue: 0.80)
    private let orange     = Color(red: 0.95, green: 0.52, blue: 0.12)

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            ZStack {
                // ----- Body: blue with a brushed-silver top band -----
                VStack(spacing: 0) {
                    silverTop.frame(height: h * 0.24)
                    blueFace
                }
                .background(blue)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(.black.opacity(0.35), lineWidth: 1))
                .shadow(color: .black.opacity(0.55), radius: 16, y: 8)
            }
            .frame(width: w, height: h)
        }
    }

    // MARK: Silver top band (cassette lid + window + LED)

    private var silverTop: some View {
        ZStack {
            LinearGradient(colors: [silver, silverDark], startPoint: .top, endPoint: .bottom)
            // brushed sheen line
            Rectangle().fill(.white.opacity(0.5)).frame(height: 1).offset(y: -4)

            HStack(spacing: 10) {
                // cassette-door seam
                RoundedRectangle(cornerRadius: 2)
                    .stroke(.black.opacity(0.18), lineWidth: 1)
                    .frame(width: 26, height: 14)
                Spacer()
                // little inset window
                RoundedRectangle(cornerRadius: 2)
                    .fill(.black.opacity(0.15))
                    .frame(width: 40, height: 12)
                Spacer()
                // power LED
                Circle()
                    .fill(engine.isPlaying ? .red : Color(white: 0.45))
                    .frame(width: 7, height: 7)
                    .shadow(color: engine.isPlaying ? .red.opacity(0.8) : .clear, radius: 3)
            }
            .padding(.horizontal, 16)
        }
    }

    // MARK: Blue face (labels + arrow + cassette window + transport)

    private var blueFace: some View {
        ZStack {
            LinearGradient(colors: [blue, blueDark], startPoint: .top, endPoint: .bottom)

            // Vertical SONY (left) and WALKMAN (right)
            HStack {
                verticalLabel("SONY", size: 15)
                Spacer()
                verticalLabel("WALKMAN", size: 13)
            }
            .padding(.horizontal, 10)

            VStack(spacing: 6) {
                // tape-direction arrow
                Image(systemName: "arrowtriangle.left.fill")
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.9))
                    .padding(.top, 8)

                cassetteWindow
                    .padding(.horizontal, 44)

                Spacer(minLength: 4)

                transportButtons
                    .padding(.bottom, 10)
            }
        }
    }

    private func verticalLabel(_ text: String, size: CGFloat) -> some View {
        Text(text)
            .font(.system(size: size, weight: .heavy, design: .rounded))
            .foregroundStyle(.white)
            .fixedSize()
            .rotationEffect(.degrees(-90))
            .frame(width: size + 6)
    }

    // MARK: Cassette window with two big 3-spoke reels

    private var cassetteWindow: some View {
        ZStack {
            // dark window
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(white: 0.08))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(.black.opacity(0.6), lineWidth: 2))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(LinearGradient(colors: [.white.opacity(0.16), .clear],
                                             startPoint: .top, endPoint: .center))
                )

            // title on a thin cream strip across the top of the window
            VStack {
                Text(engine.now?.title ?? "No Tape")
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundStyle(Color(white: 0.15))
                    .lineLimit(1)
                    .padding(.horizontal, 6).padding(.vertical, 1)
                    .frame(maxWidth: .infinity)
                    .background(cream, in: RoundedRectangle(cornerRadius: 2))
                    .padding(.horizontal, 10).padding(.top, 8)
                Spacer()
            }

            // reels + center index window
            HStack(spacing: 0) {
                reel
                Spacer()
                centerWindow
                Spacer()
                reel
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)
        }
        .aspectRatio(1.7, contentMode: .fit)
    }

    /// Big reel with a 3-spoke hub.
    private var reel: some View {
        GeometryReader { g in
            let d = min(g.size.width, g.size.height)
            ZStack {
                // wound tape
                Circle()
                    .fill(LinearGradient(colors: [Color(red: 0.28, green: 0.20, blue: 0.14),
                                                  Color(red: 0.14, green: 0.10, blue: 0.07)],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                Circle().stroke(.white.opacity(0.10), lineWidth: 1)

                // 3-spoke hub
                ZStack {
                    Circle().fill(cream).frame(width: d * 0.42, height: d * 0.42)
                    ForEach(0..<3) { i in
                        Capsule()
                            .fill(Color(white: 0.12))
                            .frame(width: d * 0.07, height: d * 0.20)
                            .offset(y: -d * 0.11)
                            .rotationEffect(.degrees(Double(i) / 3 * 360))
                    }
                    Circle().fill(Color(white: 0.3)).frame(width: d * 0.10, height: d * 0.10)
                }
                .rotationEffect(.degrees(engine.spin))
            }
            .frame(width: d, height: d)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .aspectRatio(1, contentMode: .fit)
    }

    private var centerWindow: some View {
        RoundedRectangle(cornerRadius: 3)
            .fill(cream)
            .frame(width: 36, height: 26)
            .overlay(RoundedRectangle(cornerRadius: 3).stroke(.black.opacity(0.3)))
            .overlay(
                Text(timeString(engine.currentTime))
                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Color(white: 0.2))
            )
    }

    // MARK: Functional transport keys

    private var transportButtons: some View {
        HStack(spacing: 7) {
            key("backward.fill") { engine.previous() }
            key(engine.isPlaying ? "pause.fill" : "play.fill", tint: orange, big: true) { engine.togglePlay() }
            key("forward.fill") { engine.next() }
            key("stop.fill") { engine.stop() }
            key("eject.fill") { engine.openSpotify() }
        }
    }

    private func key(_ name: String, tint: Color? = nil, big: Bool = false,
                     action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: name)
                .font(.system(size: big ? 12 : 10, weight: .bold))
                .foregroundStyle(tint == nil ? Color(white: 0.22) : .white)
                .frame(width: big ? 42 : 32, height: 22)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(tint != nil
                              ? LinearGradient(colors: [tint!, tint!.opacity(0.7)], startPoint: .top, endPoint: .bottom)
                              : LinearGradient(colors: [silver, silverDark], startPoint: .top, endPoint: .bottom))
                )
                .overlay(RoundedRectangle(cornerRadius: 4).stroke(.black.opacity(0.3), lineWidth: 0.5))
                .shadow(color: .black.opacity(0.3), radius: 1, y: 1)
        }
        .buttonStyle(.plain)
    }

    private func timeString(_ t: TimeInterval) -> String {
        let s = max(0, Int(t.rounded()))
        return String(format: "%02d:%02d", s / 60, s % 60)
    }
}
