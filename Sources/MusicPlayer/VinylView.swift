import SwiftUI

/// A vinyl turntable. In full screen it becomes a Lenco-style wooden turntable with a
/// silver platter, tonearm, and a control pod (with the transport buttons) at the
/// bottom-right. In the small window it's a compact platter with a transport bar.
struct VinylView: View {
    @EnvironmentObject private var engine: PlayerEngine

    var body: some View {
        if engine.isFullScreen {
            lencoTurntable
        } else {
            compact
        }
    }

    // MARK: Compact (windowed)

    private var compact: some View {
        VStack(spacing: 10) {
            platter.frame(maxWidth: .infinity, maxHeight: .infinity)
            DeviceTransportBar(style: .minimal)
        }
    }

    // MARK: Full-screen Lenco turntable

    private var lencoTurntable: some View {
        GeometryReader { geo in
            let d = min(geo.size.height * 0.82, geo.size.width * 0.5)
            WoodPlinth()
                .overlay(alignment: .leading) {
                    platterWithArm(diameter: d)
                        .frame(width: d, height: d)
                        .padding(.leading, geo.size.width * 0.07)
                }
                .overlay(alignment: .bottomTrailing) {
                    controlPod.padding(22)
                }
        }
    }

    private func platterWithArm(diameter d: CGFloat) -> some View {
        ZStack {
            // silver platter under the vinyl
            Circle()
                .fill(LinearGradient(colors: [Color(white: 0.78), Color(white: 0.45)],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: d * 1.1, height: d * 1.1)
                .shadow(color: .black.opacity(0.5), radius: 12, y: 6)

            record(diameter: d)
                .rotationEffect(.degrees(engine.spin))

            tonearm(side: d)
        }
        .frame(width: d * 1.1, height: d * 1.1)
    }

    // MARK: Shared platter (used by compact mode)

    private var platter: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            ZStack {
                record(diameter: side).rotationEffect(.degrees(engine.spin))
                tonearm(side: side)
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
    }

    private func record(diameter: CGFloat) -> some View {
        ZStack {
            Circle()
                .fill(RadialGradient(colors: [Color(white: 0.16), .black],
                                     center: .center, startRadius: 0, endRadius: diameter / 2))
                .shadow(color: .black.opacity(0.6), radius: 16, y: 8)

            ForEach(0..<14) { i in
                Circle()
                    .stroke(Color.white.opacity(0.05), lineWidth: 1)
                    .padding(CGFloat(i) * (diameter / 34))
            }

            Circle()
                .trim(from: 0.0, to: 0.18)
                .stroke(Color.white.opacity(0.18), lineWidth: diameter / 2)
                .scaleEffect(0.5)
                .blur(radius: 12)

            Group {
                if let art = engine.artwork {
                    Image(nsImage: art).resizable().scaledToFill()
                } else {
                    LinearGradient(colors: [engine.accent, engine.accent.opacity(0.55)],
                                   startPoint: .top, endPoint: .bottom)
                        .overlay(
                            VStack(spacing: 2) {
                                Text(engine.now?.title ?? "Not Playing")
                                    .font(.system(size: 11, weight: .bold))
                                Text(engine.now?.artist ?? "")
                                    .font(.system(size: 8, weight: .medium)).opacity(0.85)
                            }
                            .foregroundStyle(.white)
                            .padding(.horizontal, 8)
                            .multilineTextAlignment(.center)
                            .lineLimit(1)
                        )
                }
            }
            .frame(width: diameter * 0.38, height: diameter * 0.38)
            .clipShape(Circle())
            .overlay(Circle().stroke(.black.opacity(0.35), lineWidth: 2))

            Circle().fill(Color(white: 0.1)).frame(width: 10, height: 10)
            Circle().stroke(Color.white.opacity(0.3), lineWidth: 1).frame(width: 10, height: 10)
        }
        .frame(width: diameter, height: diameter)
    }

    private func tonearm(side: CGFloat) -> some View {
        let angle: Double = engine.isPlaying ? 24 : 8
        return ZStack(alignment: .topTrailing) {
            Circle()
                .fill(Color(white: 0.22))
                .frame(width: max(24, side * 0.09), height: max(24, side * 0.09))
                .overlay(Circle().stroke(.white.opacity(0.15)))

            RoundedRectangle(cornerRadius: 3)
                .fill(LinearGradient(colors: [Color(white: 0.85), Color(white: 0.5)],
                                     startPoint: .top, endPoint: .bottom))
                .frame(width: 6, height: side * 0.46)
                .overlay(alignment: .bottom) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color(white: 0.3))
                        .frame(width: 14, height: 18)
                }
                .offset(y: 6)
                .rotationEffect(.degrees(angle), anchor: .top)
                .padding(.trailing, side * 0.04)
                .padding(.top, side * 0.04)
        }
        .frame(width: side, height: side, alignment: .topTrailing)
        .animation(.spring(response: 0.5, dampingFraction: 0.7), value: engine.isPlaying)
    }

    // MARK: Lenco control pod (bottom-right)

    private var controlPod: some View {
        VStack(spacing: 7) {
            HStack {
                Text("OFF").font(.system(size: 7, weight: .bold)).foregroundStyle(.white.opacity(0.6))
                Spacer()
                knob
            }
            HStack(spacing: 6) {
                padButton("STOP") { engine.stop() }
                padButton("START") { if !engine.isPlaying { engine.togglePlay() } }
            }
            HStack(spacing: 6) {
                padIcon("backward.fill") { engine.previous() }
                padIcon(engine.isPlaying ? "pause.fill" : "play.fill") { engine.togglePlay() }
                padIcon("forward.fill") { engine.next() }
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(LinearGradient(colors: [Color(white: 0.16), Color(white: 0.09)],
                                     startPoint: .top, endPoint: .bottom))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(.black.opacity(0.5), lineWidth: 1))
        )
        .shadow(color: .black.opacity(0.5), radius: 6, y: 3)
    }

    private var knob: some View {
        Circle()
            .fill(LinearGradient(colors: [Color(white: 0.85), Color(white: 0.45)],
                                 startPoint: .topLeading, endPoint: .bottomTrailing))
            .frame(width: 26, height: 26)
            .overlay(
                Rectangle().fill(Color(white: 0.2)).frame(width: 2, height: 9).offset(y: -5)
            )
            .overlay(Circle().stroke(.black.opacity(0.3), lineWidth: 1))
    }

    private func padButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 8, weight: .heavy))
                .foregroundStyle(Color(white: 0.2))
                .frame(width: 42, height: 18)
                .background(keyGradient, in: RoundedRectangle(cornerRadius: 3))
                .overlay(RoundedRectangle(cornerRadius: 3).stroke(.black.opacity(0.3), lineWidth: 0.5))
        }
        .buttonStyle(.plain)
    }

    private func padIcon(_ name: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: name)
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(Color(white: 0.2))
                .frame(width: 28, height: 18)
                .background(keyGradient, in: RoundedRectangle(cornerRadius: 3))
                .overlay(RoundedRectangle(cornerRadius: 3).stroke(.black.opacity(0.3), lineWidth: 0.5))
        }
        .buttonStyle(.plain)
    }

    private var keyGradient: LinearGradient {
        LinearGradient(colors: [Color(white: 0.92), Color(white: 0.72)], startPoint: .top, endPoint: .bottom)
    }
}

/// Wooden turntable cabinet shown behind the platter in full screen.
struct WoodPlinth: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 26)
            .fill(LinearGradient(colors: [Color(red: 0.47, green: 0.30, blue: 0.16),
                                          Color(red: 0.31, green: 0.18, blue: 0.09)],
                                 startPoint: .top, endPoint: .bottom))
            .overlay(grain)
            .overlay(RoundedRectangle(cornerRadius: 26).stroke(.white.opacity(0.10), lineWidth: 1))
            .shadow(color: .black.opacity(0.6), radius: 22, y: 12)
    }

    private var grain: some View {
        Canvas { ctx, size in
            let step = 7.0
            var i = 0.0
            while i < size.height {
                var p = Path()
                p.move(to: CGPoint(x: 0, y: i))
                p.addCurve(
                    to: CGPoint(x: size.width, y: i),
                    control1: CGPoint(x: size.width * 0.33, y: i + (i.truncatingRemainder(dividingBy: 14) < 7 ? 2.5 : -2.5)),
                    control2: CGPoint(x: size.width * 0.66, y: i + (i.truncatingRemainder(dividingBy: 21) < 10 ? -3 : 2))
                )
                ctx.stroke(p, with: .color(.black.opacity(0.07)), lineWidth: 1)
                i += step
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 26))
    }
}

/// Working transport buttons attached to a device skin (used by the compact disc).
struct DeviceTransportBar: View {
    enum Style { case minimal, wood }
    @EnvironmentObject private var engine: PlayerEngine
    let style: Style

    var body: some View {
        HStack(spacing: 14) {
            key("backward.fill") { engine.previous() }
            key(engine.isPlaying ? "pause.fill" : "play.fill", big: true) { engine.togglePlay() }
            key("forward.fill") { engine.next() }
            key("stop.fill") { engine.stop() }
        }
        .padding(.vertical, 2)
    }

    private func key(_ name: String, big: Bool = false, action: @escaping () -> Void) -> some View {
        let bg: AnyShapeStyle = big
            ? AnyShapeStyle(LinearGradient(colors: [engine.accent, engine.accent.opacity(0.7)],
                                           startPoint: .top, endPoint: .bottom))
            : AnyShapeStyle(Color.white.opacity(0.12))
        return Button(action: action) {
            Image(systemName: name)
                .font(.system(size: big ? 18 : 13, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: big ? 54 : 40, height: 34)
                .background(bg, in: RoundedRectangle(cornerRadius: 11))
                .overlay(RoundedRectangle(cornerRadius: 11).stroke(.black.opacity(0.18), lineWidth: 0.5))
                .shadow(color: .black.opacity(0.3), radius: 1, y: 1)
        }
        .buttonStyle(.plain)
    }
}
