import Foundation

/// Day of the week, numbered like `Calendar.firstWeekday` (1 = Sunday … 7 = Saturday).
enum Weekday: Int, CaseIterable {
    case sunday = 1, monday, tuesday, wednesday, thursday, friday, saturday

    /// The first day of the week for the user's locale, as used by the calendar header and reports.
    static var localeFirstDay: Weekday {
        Weekday(rawValue: Calendar.current.firstWeekday) ?? .monday
    }
}

/// A date without a time or time zone, like `java.time.LocalDate`.
/// Day arithmetic is plain integer maths on the proleptic Gregorian calendar, so it never
/// depends on the device time zone or daylight saving.
struct LocalDate: Hashable, Comparable, CustomStringConvertible {
    let year: Int
    let month: Int
    let day: Int

    init(_ year: Int, _ month: Int, _ day: Int) {
        self.year = year
        self.month = month
        self.day = day
    }

    /// Days since 1970-01-01 -> date (Howard Hinnant's civil_from_days).
    init(epochDay: Int) {
        let z = epochDay + 719_468
        let era = (z >= 0 ? z : z - 146_096) / 146_097
        let doe = z - era * 146_097
        let yoe = (doe - doe / 1460 + doe / 36524 - doe / 146_096) / 365
        let doy = doe - (365 * yoe + yoe / 4 - yoe / 100)
        let mp = (5 * doy + 2) / 153
        let d = doy - (153 * mp + 2) / 5 + 1
        let m = mp < 10 ? mp + 3 : mp - 9
        let y = yoe + era * 400
        self.init(m <= 2 ? y + 1 : y, m, d)
    }

    /// Date -> days since 1970-01-01 (days_from_civil).
    var epochDay: Int {
        let y = month <= 2 ? year - 1 : year
        let era = (y >= 0 ? y : y - 399) / 400
        let yoe = y - era * 400
        let doy = (153 * (month > 2 ? month - 3 : month + 9) + 2) / 5 + day - 1
        let doe = yoe * 365 + yoe / 4 - yoe / 100 + doy
        return era * 146_097 + doe - 719_468
    }

    // MARK: - Parsing and formatting

    /// Parses the storage format "yyyy-MM-dd"; nil for anything else or an impossible date.
    static func parse(_ text: String) -> LocalDate? {
        let parts = text.split(separator: "-", omittingEmptySubsequences: false)
        guard parts.count == 3, parts[0].count == 4, parts[1].count == 2, parts[2].count == 2,
              parts.allSatisfy({ part in part.allSatisfy { ("0"..."9").contains($0) } }),
              let year = Int(parts[0]), let month = Int(parts[1]), let day = Int(parts[2]),
              (1...12).contains(month), day >= 1, day <= daysInMonth(year: year, month: month)
        else { return nil }
        return LocalDate(year, month, day)
    }

    /// "2026-10-21" — the format dates are stored in.
    var isoString: String { String(format: "%04d-%02d-%02d", year, month, day) }

    var description: String { isoString }

    /// Formats with a `DateFormatter` pattern such as "d MMMM" in the given locale.
    func formatted(_ pattern: String, locale: Locale = .current) -> String {
        let formatter = DateFormatter()
        formatter.calendar = LocalDate.utcCalendar
        formatter.timeZone = LocalDate.utcCalendar.timeZone
        formatter.locale = locale
        formatter.dateFormat = pattern
        return formatter.string(from: date(in: LocalDate.utcCalendar))
    }

    // MARK: - Arithmetic

    func plusDays(_ days: Int) -> LocalDate { LocalDate(epochDay: epochDay + days) }

    func plusWeeks(_ weeks: Int) -> LocalDate { plusDays(weeks * 7) }

    /// Like `LocalDate.plusMonths`: the day is clamped to the target month's length.
    func plusMonths(_ months: Int) -> LocalDate {
        let total = year * 12 + (month - 1) + months
        let newYear = total >= 0 ? total / 12 : (total - 11) / 12
        let newMonth = total - newYear * 12 + 1
        return LocalDate(newYear, newMonth, min(day, LocalDate.daysInMonth(year: newYear, month: newMonth)))
    }

    var dayOfWeek: Weekday {
        // 1970-01-01 was a Thursday
        let sundayBased = ((epochDay + 4) % 7 + 7) % 7
        return Weekday(rawValue: sundayBased + 1)!
    }

    /// The most recent `first` on or before this date.
    func startOfWeek(_ first: Weekday) -> LocalDate {
        plusDays(-(((dayOfWeek.rawValue - first.rawValue) % 7 + 7) % 7))
    }

    var firstDayOfMonth: LocalDate { LocalDate(year, month, 1) }

    var lastDayOfMonth: LocalDate { LocalDate(year, month, LocalDate.daysInMonth(year: year, month: month)) }

    static func < (lhs: LocalDate, rhs: LocalDate) -> Bool {
        (lhs.year, lhs.month, lhs.day) < (rhs.year, rhs.month, rhs.day)
    }

    // MARK: - Distances (same results as java.time ChronoUnit.between)

    static func daysBetween(_ start: LocalDate, _ end: LocalDate) -> Int { end.epochDay - start.epochDay }

    /// Whole months from `start` to `end`, truncated toward zero.
    static func monthsBetween(_ start: LocalDate, _ end: LocalDate) -> Int {
        let packed1 = (start.year * 12 + start.month - 1) * 32 + start.day
        let packed2 = (end.year * 12 + end.month - 1) * 32 + end.day
        return (packed2 - packed1) / 32
    }

    static func yearsBetween(_ start: LocalDate, _ end: LocalDate) -> Int { monthsBetween(start, end) / 12 }

    static func daysInMonth(year: Int, month: Int) -> Int {
        switch month {
        case 2: return isLeapYear(year) ? 29 : 28
        case 4, 6, 9, 11: return 30
        default: return 31
        }
    }

    static func isLeapYear(_ year: Int) -> Bool { (year % 4 == 0 && year % 100 != 0) || year % 400 == 0 }

    // MARK: - Foundation bridging

    /// Today in the device's calendar and time zone.
    static func today(calendar: Calendar = .current, now: Date = Date()) -> LocalDate {
        LocalDate(date: now, calendar: calendar)
    }

    init(date: Date, calendar: Calendar = .current) {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        self.init(parts.year ?? 1970, parts.month ?? 1, parts.day ?? 1)
    }

    /// Midnight at the start of this date in `calendar`'s time zone.
    func date(in calendar: Calendar = .current) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day)) ?? Date(timeIntervalSince1970: 0)
    }

    private static let utcCalendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }()
}
