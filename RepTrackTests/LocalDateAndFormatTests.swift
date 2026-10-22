import XCTest
@testable import RepTrack

final class LocalDateTests: XCTestCase {

    func testEpochDayRoundTrip() {
        XCTAssertEqual(LocalDate(1970, 1, 1).epochDay, 0)
        XCTAssertEqual(LocalDate(2026, 10, 21).epochDay, 20_747)
        for day in stride(from: -800_000, through: 800_000, by: 997) {
            XCTAssertEqual(LocalDate(epochDay: day).epochDay, day)
        }
    }

    func testParseAndFormat() {
        XCTAssertEqual(LocalDate.parse("2026-10-21"), LocalDate(2026, 10, 21))
        XCTAssertEqual(LocalDate(2026, 3, 5).isoString, "2026-03-05")
        XCTAssertNil(LocalDate.parse("2026-02-30"))
        XCTAssertNil(LocalDate.parse("2026-13-01"))
        XCTAssertNil(LocalDate.parse("26-10-21"))
        XCTAssertNil(LocalDate.parse("2026-1-21"))
        XCTAssertNil(LocalDate.parse("not-a-date"))
        XCTAssertNotNil(LocalDate.parse("2024-02-29"))
    }

    func testArithmetic() {
        XCTAssertEqual(LocalDate(2026, 12, 31).plusDays(1), LocalDate(2027, 1, 1))
        XCTAssertEqual(LocalDate(2026, 3, 1).plusDays(-1), LocalDate(2026, 2, 28))
        XCTAssertEqual(LocalDate(2026, 3, 31).plusMonths(-1), LocalDate(2026, 2, 28))
        XCTAssertEqual(LocalDate(2024, 1, 31).plusMonths(1), LocalDate(2024, 2, 29))
        XCTAssertEqual(LocalDate(2026, 1, 15).plusMonths(-13), LocalDate(2024, 12, 15))
        XCTAssertEqual(LocalDate(2026, 10, 21).plusWeeks(-2), LocalDate(2026, 10, 7))
    }

    func testDayOfWeekAndWeekStart() {
        XCTAssertEqual(LocalDate(2026, 10, 21).dayOfWeek, .wednesday)
        XCTAssertEqual(LocalDate(1970, 1, 1).dayOfWeek, .thursday)
        XCTAssertEqual(LocalDate(2026, 10, 21).startOfWeek(.monday), LocalDate(2026, 10, 19))
        XCTAssertEqual(LocalDate(2026, 10, 21).startOfWeek(.sunday), LocalDate(2026, 10, 18))
        XCTAssertEqual(LocalDate(2026, 10, 19).startOfWeek(.monday), LocalDate(2026, 10, 19))
        XCTAssertEqual(LocalDate(2026, 10, 18).startOfWeek(.monday), LocalDate(2026, 10, 12))
    }

    func testBetween_matchesJavaChronoUnit() {
        XCTAssertEqual(LocalDate.daysBetween(LocalDate(2026, 10, 21), LocalDate(2026, 10, 1)), -20)
        XCTAssertEqual(LocalDate.monthsBetween(LocalDate(2026, 10, 21), LocalDate(2026, 11, 20)), 0)
        XCTAssertEqual(LocalDate.monthsBetween(LocalDate(2026, 10, 21), LocalDate(2026, 11, 21)), 1)
        XCTAssertEqual(LocalDate.monthsBetween(LocalDate(2026, 10, 21), LocalDate(2026, 9, 22)), 0)
        XCTAssertEqual(LocalDate.monthsBetween(LocalDate(2026, 10, 21), LocalDate(2026, 9, 21)), -1)
        XCTAssertEqual(LocalDate.yearsBetween(LocalDate(2026, 10, 21), LocalDate(2025, 10, 22)), 0)
        XCTAssertEqual(LocalDate.yearsBetween(LocalDate(2026, 10, 21), LocalDate(2025, 10, 21)), -1)
    }

    func testFormatted() {
        XCTAssertEqual(LocalDate(2026, 10, 21).formatted("d MMMM", locale: english), "21 October")
        XCTAssertEqual(LocalDate(2026, 10, 21).formatted("EEEE", locale: english), "Wednesday")
    }
}

final class FormatTests: XCTestCase {

    func testRoundHalfUp_matchesMathRound() {
        XCTAssertEqual(Format.roundHalfUp(2.5), 3)
        XCTAssertEqual(Format.roundHalfUp(-2.5), -2)
        XCTAssertEqual(Format.roundHalfUp(-2.6), -3)
        XCTAssertEqual(Format.roundHalfUp(783.75), 784)
    }

    func testWeight() {
        XCTAssertEqual(Format.weight(60), "60")
        XCTAssertEqual(Format.weight(62.5), "62.5")
        XCTAssertEqual(Format.weight(0), "0")
        XCTAssertEqual(Format.weight(78.4), "78.4")
        XCTAssertEqual(Format.weight(0.000_01), "0.00001")
    }

    func testVolumeUsesGroupingAndRounding() {
        let us = Locale(identifier: "en_US")
        XCTAssertEqual(Format.volume(12450, locale: us), "12,450")
        XCTAssertEqual(Format.volume(830.5, locale: us), "831")
        XCTAssertEqual(Format.volume(0, locale: us), "0")
    }

    func testDuration() {
        XCTAssertEqual(Format.duration(95), "1:35")
        XCTAssertEqual(Format.duration(30), "0:30")
        XCTAssertEqual(Format.duration(180), "3:00")
    }

    func testParseDecimal() {
        XCTAssertEqual(Format.parseDecimal("82,5"), 82.5)
        XCTAssertEqual(Format.parseDecimal("82.5"), 82.5)
        XCTAssertEqual(Format.parseDecimal("5."), 5)
        XCTAssertNil(Format.parseDecimal(""))
        XCTAssertNil(Format.parseDecimal("."))
    }

    func testPercentChange() {
        XCTAssertEqual(Format.percentChange(12.4), "+12%")
        XCTAssertEqual(Format.percentChange(-4.2), "\u{2212}4%")
        XCTAssertEqual(Format.percentChange(0.3), "0%")
        XCTAssertEqual(Format.percentChange(-0.5), "0%")
        XCTAssertNil(Format.percentChange(nil))
    }

    func testSignedDelta() {
        XCTAssertEqual(Format.signedDelta(2.5), "+2.5")
        XCTAssertEqual(Format.signedDelta(-1), "\u{2212}1")
        XCTAssertEqual(Format.signedDelta(0.04), "\u{00B1}0")
    }

    func testCompactAndOneRepMax() {
        let us = Locale(identifier: "en_US")
        XCTAssertEqual(Format.compact(12450, locale: us), "12.5k")
        XCTAssertEqual(Format.compact(830, locale: us), "830")
        XCTAssertEqual(Format.compact(1000, locale: us), "1k")
        XCTAssertEqual(Format.oneRepMax(93.333), "93.3 kg")
    }

    func testStableSortAndOrderedGroups() {
        let items = [("b", 1), ("a", 2), ("c", 1), ("d", 2)]
        XCTAssertEqual(items.stableSorted { $0.1 < $1.1 }.map(\.0), ["b", "c", "a", "d"])
        let groups = ["x1", "y1", "x2", "z1", "y2"].orderedGroups { $0.prefix(1) }
        XCTAssertEqual(groups.map { String($0.key) }, ["x", "y", "z"])
        XCTAssertEqual(groups[0].values, ["x1", "x2"])
    }
}

final class DateLabelsTests: XCTestCase {

    private let today = LocalDate(2026, 10, 21)

    func testRelativeDistance() {
        XCTAssertEqual(DateLabels.relativeDistance(today: today, date: LocalDate(2026, 10, 18)), "3 days ago")
        XCTAssertEqual(DateLabels.relativeDistance(today: today, date: LocalDate(2026, 10, 25)), "In 4 days")
        XCTAssertEqual(DateLabels.relativeDistance(today: today, date: LocalDate(2026, 10, 14)), "Last week")
        XCTAssertEqual(DateLabels.relativeDistance(today: today, date: LocalDate(2026, 11, 4)), "In 2 weeks")
        XCTAssertEqual(DateLabels.relativeDistance(today: today, date: LocalDate(2026, 9, 21)), "Last month")
        XCTAssertEqual(DateLabels.relativeDistance(today: today, date: LocalDate(2027, 1, 30)), "In 3 months")
        XCTAssertEqual(DateLabels.relativeDistance(today: today, date: LocalDate(2025, 10, 1)), "Last year")
        XCTAssertEqual(DateLabels.relativeDistance(today: today, date: LocalDate(2029, 12, 1)), "In 3 years")
    }

    func testHeader() {
        XCTAssertEqual(DateLabels.header(selected: today, today: today, locale: english).title, "Today")
        XCTAssertEqual(DateLabels.header(selected: today, today: today, locale: english).subtitle, "Wednesday, 21 October")
        XCTAssertEqual(DateLabels.header(selected: LocalDate(2026, 10, 20), today: today, locale: english).title, "Yesterday")
        XCTAssertEqual(DateLabels.header(selected: LocalDate(2026, 10, 22), today: today, locale: english).title, "Tomorrow")
        let older = DateLabels.header(selected: LocalDate(2026, 10, 14), today: today, locale: english)
        XCTAssertEqual(older.title, "14 October")
        XCTAssertEqual(older.subtitle, "Wednesday · Last week")
        XCTAssertEqual(DateLabels.header(selected: LocalDate(2025, 12, 31), today: today, locale: english).title, "31 December 2025")
    }

    func testPeriodLabels() {
        let week = DateRange(start: LocalDate(2026, 10, 13), endInclusive: LocalDate(2026, 10, 19))
        let crossing = DateRange(start: LocalDate(2026, 9, 28), endInclusive: LocalDate(2026, 10, 4))
        let month = DateRange(start: LocalDate(2026, 10, 1), endInclusive: LocalDate(2026, 10, 31))
        XCTAssertEqual(DateLabels.longLabel(.week, week, locale: english), "13 – 19 Oct")
        XCTAssertEqual(DateLabels.longLabel(.week, crossing, locale: english), "28 Sep – 4 Oct")
        XCTAssertEqual(DateLabels.longLabel(.month, month, locale: english), "October 2026")
        XCTAssertEqual(DateLabels.shortLabel(.week, week, locale: english), "13 Oct")
        XCTAssertEqual(DateLabels.shortLabel(.month, month, locale: english), "Oct")
    }

    func testRelativeName() {
        let thisWeek = DateRange(start: LocalDate(2026, 10, 19), endInclusive: LocalDate(2026, 10, 25))
        let lastWeek = DateRange(start: LocalDate(2026, 10, 12), endInclusive: LocalDate(2026, 10, 18))
        let older = DateRange(start: LocalDate(2026, 10, 5), endInclusive: LocalDate(2026, 10, 11))
        XCTAssertEqual(DateLabels.relativeName(.week, thisWeek, today: today, locale: english), "this week")
        XCTAssertEqual(DateLabels.relativeName(.week, lastWeek, today: today, locale: english), "last week")
        XCTAssertEqual(DateLabels.relativeName(.week, older, today: today, locale: english), "5 – 11 Oct")
        let lastMonth = DateRange(start: LocalDate(2026, 9, 1), endInclusive: LocalDate(2026, 9, 30))
        XCTAssertEqual(DateLabels.relativeName(.month, lastMonth, today: today, locale: english), "last month")
    }

    func testNavigatorSubtitle() {
        let report = ProgressReport.build(period: .week, anchor: today, workouts: [], firstDayOfWeek: .monday)
        XCTAssertEqual(DateLabels.navigatorSubtitle(report, today: today, locale: english), "This week · so far vs 12 – 18 Oct")
        let previous = ProgressReport.build(period: .week, anchor: LocalDate(2026, 10, 14), workouts: [], firstDayOfWeek: .monday)
        XCTAssertEqual(DateLabels.navigatorSubtitle(previous, today: today, locale: english), "Last week vs 5 – 11 Oct")
    }
}

final class ExerciseSuggestionsTests: XCTestCase {

    func testDefaultViewShowsRecentThenPopular_maxTen() {
        let result = ExerciseSuggestions.suggestions(typed: "", recentNames: ["Squats", "Hip Thrust"], savedNames: [], showMyList: false)
        XCTAssertEqual(result.count, 10)
        XCTAssertEqual(result[0], .init(name: "Squats", isRecent: true))
        XCTAssertEqual(result[1], .init(name: "Hip Thrust", isRecent: true))
        // "Squats" isn't repeated in the popular part
        XCTAssertEqual(result.filter { $0.name == "Squats" }.count, 1)
        XCTAssertEqual(result[2], .init(name: "Bench Press", isRecent: false))
    }

    func testTypingFiltersAndHidesExactMatch() {
        let result = ExerciseSuggestions.suggestions(typed: " press ", recentNames: [], savedNames: [], showMyList: false)
        XCTAssertEqual(result.map(\.name), ["Bench Press", "Shoulder Press", "Leg Press"])
        let exact = ExerciseSuggestions.suggestions(typed: "bench press", recentNames: [], savedNames: [], showMyList: false)
        XCTAssertTrue(exact.isEmpty)
    }

    func testMyListHasNoLimitOrRecentIcon() {
        let saved = (1...12).map { "Move \($0)" }
        let result = ExerciseSuggestions.suggestions(typed: "", recentNames: ["Squats"], savedNames: saved, showMyList: true)
        XCTAssertEqual(result.map(\.name), saved)
        XCTAssertTrue(result.allSatisfy { !$0.isRecent })
    }

    func testRecentNames_newestFirstGroupedByExactName() {
        let names = ExerciseSuggestions.recentNames([
            (name: "Squat", createdAt: 10), (name: "Bench", createdAt: 20),
            (name: "Squat", createdAt: 30), (name: "squat", createdAt: 5),
        ], limit: 2)
        XCTAssertEqual(names, ["Squat", "Bench"])
    }
}
