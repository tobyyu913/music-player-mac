import SwiftUI
import AppKit

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

/// Alarm. Click the bell to enable and set a time; when it fires it **pauses your music**
/// (rather than blaring a siren) and flashes. Click the flashing bell — or "Dismiss" — to
/// clear it. `large` scales it up for the full-screen layout.
struct AlarmView: View {
    var large: Bool = false

    @EnvironmentObject private var engine: PlayerEngine
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
                    Text(enabled ? labelString : "Alarm")
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
                Button("Dismiss", role: .destructive) { stopAlarm() }
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
            if engine.isPlaying { engine.togglePlay() }   // pause the music — no siren
        }
    }

    private func stopAlarm() {
        flashing = false
    }
}

