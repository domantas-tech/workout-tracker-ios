import Foundation
import Observation

/// Rest countdown between sets. Lives in memory only: the default duration and the auto-start
/// switch reset to 90 s / on at every launch, like the Android app.
///
/// The remaining time is measured against an end time rather than by counting ticks, so the
/// countdown stays correct if the app is briefly in the background.
@Observable
@MainActor
final class RestTimer {
    static let defaultRestSeconds = 90
    static let durations = [30, 60, 90, 120, 180]

    /// Seconds left in the current countdown.
    private(set) var secondsRemaining = 0
    /// Length of the current countdown, used to draw its progress.
    private(set) var totalSeconds = 0
    private(set) var isRunning = false
    /// Duration used when the timer auto-starts after a set is ticked off.
    private(set) var restDurationSeconds = RestTimer.defaultRestSeconds
    var autoStartRest = true

    @ObservationIgnored private var endDate = Date()
    @ObservationIgnored private var task: Task<Void, Never>?
    private let now: () -> Date
    private let runsLoop: Bool

    /// `now` and `runsLoop` exist for tests, which drive `tick()` by hand.
    init(now: @escaping () -> Date = { Date() }, runsLoop: Bool = true) {
        self.now = now
        self.runsLoop = runsLoop
    }

    /// Starts a countdown of `seconds`, replacing any running one; it also becomes the default duration.
    func start(_ seconds: Int) {
        task?.cancel()
        restDurationSeconds = seconds
        totalSeconds = seconds
        secondsRemaining = seconds
        endDate = now().addingTimeInterval(TimeInterval(seconds))
        isRunning = seconds > 0
        guard isRunning, runsLoop else { return }
        task = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 200_000_000)
                guard let self, !Task.isCancelled else { return }
                self.tick()
                if !self.isRunning { return }
            }
        }
    }

    /// Adds or removes time from a running countdown (e.g. ±15 s); reaching zero stops it.
    func adjust(by deltaSeconds: Int) {
        guard isRunning else { return }
        let remaining = max(secondsRemaining + deltaSeconds, 0)
        if remaining == 0 {
            stop()
            return
        }
        endDate = endDate.addingTimeInterval(TimeInterval(remaining - secondsRemaining))
        secondsRemaining = remaining
        totalSeconds = max(totalSeconds, remaining)
    }

    /// Ends the countdown ("Skip").
    func stop() {
        task?.cancel()
        task = nil
        isRunning = false
        secondsRemaining = 0
    }

    /// Recomputes the remaining seconds from the clock.
    func tick() {
        guard isRunning else { return }
        let left = Int(endDate.timeIntervalSince(now()).rounded(.up))
        secondsRemaining = max(left, 0)
        if secondsRemaining == 0 {
            task = nil
            isRunning = false
        }
    }
}
