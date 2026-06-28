import SwiftUI
import AppKit
import AVFoundation

/// Glowing digital clock. `large` scales it up for the full-screen layout.
struct DigitalClockView: View {
    var large: Bool = false

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let now = context.date
            VStack(alignment: .leading, spacing: large ? 4 : 2) {
                Text(timeString(now))
                    .font(.system(size: large ? 54 : 30, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white)
                    .shadow(color: .cyan.opacity(0.7), radius: large ? 12 : 8)
                Text(dateString(now))
                    .font(.system(size: large ? 18 : 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.55))
            }
            .padding(.horizontal, large ? 22 : 14).padding(.vertical, large ? 16 : 10)
            .background(.black.opacity(0.30), in: RoundedRectangle(cornerRadius: large ? 18 : 12))
            .overlay(RoundedRectangle(cornerRadius: large ? 18 : 12).stroke(.white.opacity(0.08)))
        }
    }

    private func timeString(_ d: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "HH:mm:ss"; return f.string(from: d)
    }
    private func dateString(_ d: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "EEE, MMM d"; return f.string(from: d)
    }
}

/// Alarm. Click the bell to enable and set a time; it flashes and blares a loud looping
/// siren when it fires. Click the (flashing) bell again — or "Stop alarm" — to silence it.
/// `large` scales it up for the full-screen layout.
struct AlarmView: View {
    var large: Bool = false

    @State private var enabled = false
    @State private var alarmTime = Calendar.current.date(
        bySettingHour: 7, minute: 30, second: 0, of: Date()) ?? Date()
    @State private var showPopover = false
    @State private var firedMinute: String? = nil
    @State private var flashing = false

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let now = context.date
            Button {
                if flashing { stopAlarm() } else { showPopover.toggle() }
            } label: {
                HStack(spacing: large ? 9 : 6) {
                    Image(systemName: enabled ? "alarm.fill" : "alarm")
                        .opacity(flashing && Int(now.timeIntervalSince1970) % 2 == 0 ? 0.3 : 1)
                    Text(flashing ? "STOP" : (enabled ? labelString : "Alarm"))
                        .font(.system(size: large ? 22 : 13, weight: .semibold, design: .monospaced))
                }
                .foregroundStyle(flashing ? .red : (enabled ? .yellow : .white.opacity(0.7)))
                .padding(.horizontal, large ? 18 : 12).padding(.vertical, large ? 16 : 10)
                .background(.black.opacity(0.30), in: RoundedRectangle(cornerRadius: large ? 18 : 12))
                .overlay(RoundedRectangle(cornerRadius: large ? 18 : 12)
                    .stroke(flashing ? .red.opacity(0.8) : .white.opacity(0.08),
                            lineWidth: flashing ? 2 : 1))
            }
            .buttonStyle(.plain)
            .onChange(of: now) { _ in checkAlarm(now) }
            .onChange(of: enabled) { on in if !on { stopAlarm() } }
            .popover(isPresented: $showPopover, arrowEdge: .bottom) {
                editor
            }
        }
    }

    private var editor: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle("Alarm enabled", isOn: $enabled)
                .toggleStyle(.switch)
            DatePicker("Wake at", selection: $alarmTime, displayedComponents: .hourAndMinute)
                .datePickerStyle(.stepperField)
            if flashing {
                Button("Stop alarm", role: .destructive) { stopAlarm() }
            }
        }
        .padding(16)
        .frame(width: 230)
    }

    private var labelString: String {
        let f = DateFormatter(); f.dateFormat = "HH:mm"; return f.string(from: alarmTime)
    }

    private func checkAlarm(_ now: Date) {
        guard enabled else { stopAlarm(); return }
        let cal = Calendar.current
        let a = cal.dateComponents([.hour, .minute], from: alarmTime)
        let n = cal.dateComponents([.hour, .minute], from: now)
        let key = "\(n.hour ?? -1):\(n.minute ?? -1)"
        if a.hour == n.hour && a.minute == n.minute, firedMinute != key {
            firedMinute = key
            flashing = true
            AlarmSiren.shared.start()
        }
    }

    private func stopAlarm() {
        flashing = false
        AlarmSiren.shared.stop()
    }
}

/// Generates and loops a loud, piercing two-tone siren — and bumps system volume up — so
/// the alarm can actually wake someone.
final class AlarmSiren {
    static let shared = AlarmSiren()
    private var player: AVAudioPlayer?

    func start() {
        guard player == nil else { return }
        raiseSystemVolume()
        player = try? AVAudioPlayer(data: Self.sirenWAV())
        player?.numberOfLoops = -1      // loop until stopped
        player?.volume = 1.0
        player?.prepareToPlay()
        player?.play()
    }

    func stop() {
        player?.stop()
        player = nil
    }

    private func raiseSystemVolume() {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        p.arguments = ["-e", "set volume output volume 90 without output muted"]
        try? p.run()
    }

    /// An alternating two-tone (C6 / F6) square-wave siren as 16-bit PCM WAV in memory.
    private static func sirenWAV() -> Data {
        let sr = 44100.0
        let toneDur = 0.20
        let tones: [Double] = [1046.5, 1396.9]
        var samples = [Int16]()
        for _ in 0..<3 {
            for f in tones {
                let n = Int(sr * toneDur)
                for i in 0..<n {
                    let t = Double(i) / sr
                    let fade = min(1.0, min(Double(i), Double(n - i)) / 220.0)   // declick edges
                    let square: Double = sin(2 * .pi * f * t) >= 0 ? 1 : -1
                    samples.append(Int16(0.92 * 32767 * fade * square))
                }
            }
        }
        return wav(samples, sampleRate: Int(sr))
    }

    private static func wav(_ samples: [Int16], sampleRate: Int) -> Data {
        var d = Data()
        let dataSize = samples.count * 2
        func str(_ s: String) { d.append(contentsOf: Array(s.utf8)) }
        func u32(_ v: UInt32) { var x = v.littleEndian; withUnsafeBytes(of: &x) { d.append(contentsOf: $0) } }
        func u16(_ v: UInt16) { var x = v.littleEndian; withUnsafeBytes(of: &x) { d.append(contentsOf: $0) } }
        str("RIFF"); u32(UInt32(36 + dataSize)); str("WAVE")
        str("fmt "); u32(16); u16(1); u16(1)
        u32(UInt32(sampleRate)); u32(UInt32(sampleRate * 2)); u16(2); u16(16)
        str("data"); u32(UInt32(dataSize))
        for s in samples { var x = s.littleEndian; withUnsafeBytes(of: &x) { d.append(contentsOf: $0) } }
        return d
    }
}
