import Foundation

/// Human-readable labels for dates and report periods.
enum DateLabels {

    // MARK: - Tracker header

    /// Title and subtitle never repeat each other: a relative day name pairs with the full date,
    /// an absolute date pairs with the weekday and its distance from today.
    static func header(selected: LocalDate, today: LocalDate, locale: Locale = .current) -> (title: String, subtitle: String) {
        let dateText = selected.formatted(selected.year == today.year ? "d MMMM" : "d MMMM yyyy", locale: locale)
        let weekday = selected.formatted("EEEE", locale: locale)
        let relativeDay: String?
        switch LocalDate.daysBetween(today, selected) {
        case 0: relativeDay = "Today"
        case -1: relativeDay = "Yesterday"
        case 1: relativeDay = "Tomorrow"
        default: relativeDay = nil
        }
        if let relativeDay {
            return (relativeDay, "\(weekday), \(dateText)")
        }
        return (dateText, "\(weekday) · \(relativeDistance(today: today, date: selected))")
    }

    /// Human-friendly distance from `today`, e.g. "3 days ago", "In 2 weeks", "Last month".
    static func relativeDistance(today: LocalDate, date: LocalDate) -> String {
        let days = LocalDate.daysBetween(today, date)
        let past = days < 0
        let absDays = abs(days)
        let absMonths = abs(LocalDate.monthsBetween(today, date))
        let absYears = abs(LocalDate.yearsBetween(today, date))
        let count: Int
        let unit: String
        if absDays < 7 {
            count = absDays
            unit = "day"
        } else if absMonths < 1 {
            count = absDays / 7
            unit = "week"
        } else if absYears < 1 {
            count = absMonths
            unit = "month"
        } else {
            count = absYears
            unit = "year"
        }
        if count == 1 && unit != "day" {
            return past ? "Last \(unit)" : "Next \(unit)"
        }
        return past ? "\(count) \(unit)s ago" : "In \(count) \(unit)s"
    }

    // MARK: - Progress periods

    /// "13 – 19 Oct", "28 Sep – 4 Oct", "October 2026"
    static func longLabel(_ period: ProgressPeriod, _ range: DateRange, locale: Locale = .current) -> String {
        switch period {
        case .week:
            if range.start.month == range.endInclusive.month {
                return "\(range.start.day) – \(range.endInclusive.formatted("d MMM", locale: locale))"
            }
            return "\(range.start.formatted("d MMM", locale: locale)) – \(range.endInclusive.formatted("d MMM", locale: locale))"
        case .month:
            return range.start.formatted("MMMM yyyy", locale: locale)
        }
    }

    /// Chart axis label: week start ("13 Oct") or month ("Oct").
    static func shortLabel(_ period: ProgressPeriod, _ range: DateRange, locale: Locale = .current) -> String {
        switch period {
        case .week: return range.start.formatted("d MMM", locale: locale)
        case .month: return range.start.formatted("MMM", locale: locale)
        }
    }

    /// "this week", "last month", or the date label for anything older.
    static func relativeName(_ period: ProgressPeriod, _ range: DateRange, today: LocalDate, locale: Locale = .current) -> String {
        let unit = period.unitName
        if range.contains(today) { return "this \(unit)" }
        // A week range starts on the configured first day of the week, so reuse it
        let following = period.rangeContaining(period.shift(range.start, by: 1), firstDayOfWeek: range.start.dayOfWeek)
        if following.contains(today) { return "last \(unit)" }
        return longLabel(period, range, locale: locale)
    }

    /// "This week · so far vs 12 – 18 Oct"
    static func navigatorSubtitle(_ report: ProgressReport, today: LocalDate, locale: Locale = .current) -> String {
        let relative = relativeName(report.period, report.current, today: today, locale: locale)
        var text = relative.prefix(1).uppercased() + relative.dropFirst()
        if report.current.contains(today) { text += " · so far" }
        text += " vs "
        text += longLabel(report.period, report.previous, locale: locale)
        return text
    }
}
