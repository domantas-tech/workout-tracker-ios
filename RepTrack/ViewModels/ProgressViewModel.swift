import Foundation
import Observation

/// Weekly / monthly progress report, compared with the period before.
/// Rebuilt whenever the period, the viewed date or the stored data changes.
@Observable
@MainActor
final class ProgressViewModel {
    private let store: DataStore
    private let todayProvider: () -> LocalDate

    /// Same week start as the calendar header.
    let firstDayOfWeek: Weekday

    private(set) var period: ProgressPeriod = .week
    /// Any date inside the period being viewed.
    private(set) var anchor: LocalDate
    private(set) var report: ProgressReport?

    init(store: DataStore, firstDayOfWeek: Weekday = .localeFirstDay, today: @escaping () -> LocalDate = { .today() }) {
        self.store = store
        self.firstDayOfWeek = firstDayOfWeek
        self.todayProvider = today
        self.anchor = today()
        rebuild()
        store.observe { [weak self] in self?.rebuild() }
    }

    var today: LocalDate { todayProvider() }

    func selectPeriod(_ period: ProgressPeriod) {
        guard period != self.period else { return }
        self.period = period
        rebuild()
    }

    func goToPreviousPeriod() {
        anchor = period.shift(anchor, by: -1)
        rebuild()
    }

    func goToNextPeriod() {
        guard canGoForward else { return }
        anchor = period.shift(anchor, by: 1)
        rebuild()
    }

    func goToPeriodContaining(_ date: LocalDate) {
        anchor = min(date, today)
        rebuild()
    }

    func goToCurrentPeriod() {
        anchor = today
        rebuild()
    }

    /// No point browsing into periods that haven't finished.
    var canGoForward: Bool {
        period.rangeContaining(anchor, firstDayOfWeek: firstDayOfWeek).endInclusive < today
    }

    private func rebuild() {
        let range = ProgressReport.dataRange(period: period, anchor: anchor, firstDayOfWeek: firstDayOfWeek)
        let workouts = store.workouts.workoutsWithSets(from: range.start.isoString, through: range.endInclusive.isoString)
        report = ProgressReport.build(period: period, anchor: anchor, workouts: workouts, firstDayOfWeek: firstDayOfWeek)
    }
}
