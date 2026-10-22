import SwiftUI

/// Shown at the bottom of the screen while a rest countdown is running.
struct RestTimerBar: View {
    let timer: RestTimer

    private var progress: Double {
        timer.totalSeconds == 0 ? 0 : Double(timer.secondsRemaining) / Double(timer.totalSeconds)
    }

    var body: some View {
        VStack(spacing: 0) {
            ProgressBar(progress: progress, height: 3, rounded: false)
                .animation(.linear(duration: 1), value: timer.secondsRemaining)
            HStack(spacing: 4) {
                VStack(alignment: .leading, spacing: 0) {
                    Text("REST")
                        .font(AppFont.labelSmall)
                        .tracking(0.8)
                        .foregroundStyle(Palette.textSecondary)
                    Text(Format.duration(timer.secondsRemaining))
                        .font(AppFont.displaySmall)
                        .foregroundStyle(Palette.lime)
                        .contentTransition(.numericText(countsDown: true))
                        .animation(.default, value: timer.secondsRemaining)
                        .accessibilityLabel("Rest \(Format.duration(timer.secondsRemaining))")
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                adjustButton("\u{2212}15", delta: -15, label: "Remove 15 seconds")
                adjustButton("+15", delta: 15, label: "Add 15 seconds")

                Button { timer.stop() } label: {
                    Text("Skip")
                        .font(AppFont.labelLarge)
                        .foregroundStyle(Palette.textPrimary)
                        .padding(.horizontal, 20)
                        .frame(height: 40)
                        .background(Palette.surfaceHighest, in: Capsule())
                }
                .buttonStyle(.plain)
                .padding(.leading, 4)
            }
            .padding(.leading, 20)
            .padding(.trailing, 12)
            .padding(.vertical, 10)
        }
        .background(Palette.surfaceHigh.ignoresSafeArea(edges: .bottom))
    }

    private func adjustButton(_ title: String, delta: Int, label: String) -> some View {
        Button { timer.adjust(by: delta) } label: {
            Text(title)
                .font(AppFont.labelLarge)
                .foregroundStyle(Palette.lime)
                .frame(minWidth: 44, minHeight: 40)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

/// Header action: start a rest timer manually and choose whether it auto-starts after each set.
struct RestTimerMenu: View {
    @Bindable var timer: RestTimer

    var body: some View {
        Menu {
            Section("Start rest") {
                ForEach(RestTimer.durations, id: \.self) { seconds in
                    Button { timer.start(seconds) } label: {
                        if seconds == timer.restDurationSeconds {
                            Label(Format.duration(seconds), systemImage: "checkmark")
                        } else {
                            Text(Format.duration(seconds))
                        }
                    }
                }
            }
            Divider()
            Toggle("Auto-start after set", isOn: $timer.autoStartRest)
        } label: {
            HeaderIcon(systemImage: "timer")
        }
        .accessibilityLabel("Rest timer")
    }
}
