import XCTest
@testable import RepTrack

final class ProgressReportExportTests: XCTestCase {

    private var factory = WorkoutFactory()

    // Wednesday; with Monday weeks the current week is 19–25 Oct
    private let anchor = LocalDate(2026, 10, 21)

    private func w(_ date: String, _ name: String, _ sets: (Int, Double)..., completed: Bool = true) -> WorkoutWithSets {
        factory.make(date, name, sets: sets, completed: completed)
    }

    private func report(_ period: ProgressPeriod, _ workouts: WorkoutWithSets...) -> ProgressReport {
        ProgressReport.build(period: period, anchor: anchor, workouts: workouts, firstDayOfWeek: .monday)
    }

    private func weekly() -> ProgressReport {
        report(
            .week,
            w("2026-10-19", "Bench Press", (10, 60), (8, 70)),
            w("2026-10-21", "bench press", (5, 80)),
            w("2026-10-21", "Pull Up", (12, 0), (10, 0)),
            w("2026-10-22", "Deadlift", (5, 140), completed: false),
            // Previous week: not part of this export
            w("2026-10-14", "Squat", (5, 100))
        )
    }

    private func number(_ cell: XlsxCell?, file: StaticString = #filePath, line: UInt = #line) -> Double {
        guard case let .number(value, _)? = cell else {
            XCTFail("Expected a number cell, got \(String(describing: cell))", file: file, line: line)
            return .nan
        }
        return value
    }

    private func text(_ cell: XlsxCell?) -> String? {
        guard case let .text(value, _)? = cell else { return nil }
        return value
    }

    private func formula(_ cell: XlsxCell?) -> (formula: String, cached: Double)? {
        guard case let .formula(value, cached, _)? = cell else { return nil }
        return (value, cached)
    }

    func testSheet_hasOneRowPerExerciseWithItsTotals() throws {
        let rows = ProgressReportExport.sheet(weekly()).rows

        XCTAssertEqual(rows[3].map(text), ["Exercise", "Sets", "Reps", "Volume (kg)", "Best e1RM (kg)"])

        // Both bench sessions are one exercise; most trained first
        let bench = rows[4]
        XCTAssertEqual(text(bench[0]), "bench press")
        XCTAssertEqual(number(bench[1]), 3)
        XCTAssertEqual(number(bench[2]), 23)
        XCTAssertEqual(number(bench[3]), 600 + 560 + 400, accuracy: 0.001)
        // Best e1RM across both sessions: 80 × (1 + 5/30) = 93.33 beats 70 × (1 + 8/30) = 88.67
        XCTAssertEqual(number(bench[4]), 93.3)

        // Bodyweight work without added weight has no e1RM
        let pullUp = rows[5]
        XCTAssertEqual(text(pullUp[0]), "Pull Up")
        XCTAssertEqual(number(pullUp[1]), 2)
        XCTAssertEqual(number(pullUp[2]), 22)
        XCTAssertNil(pullUp[4])

        // Deadlift had no completed sets and Squat was last week, so the totals row comes next
        XCTAssertEqual(rows.count, 7)
        let totals = rows[6]
        XCTAssertEqual(text(totals[0]), "Total")
        let setsTotal = try XCTUnwrap(formula(totals[1]))
        XCTAssertEqual(setsTotal.formula, "SUM(B5:B6)")
        XCTAssertEqual(setsTotal.cached, 5)
        XCTAssertEqual(try XCTUnwrap(formula(totals[2])).cached, 45)
        XCTAssertEqual(try XCTUnwrap(formula(totals[3])).cached, 1560, accuracy: 0.001)
        XCTAssertEqual(totals[4]?.style, .total)
    }

    func testSheet_monthlyCoversTheWholeMonth() {
        let monthly = report(
            .month,
            w("2026-10-01", "Squat", (5, 100)),
            w("2026-10-21", "Squat", (5, 110)),
            w("2026-09-30", "Squat", (5, 200))
        )
        let squat = ProgressReportExport.sheet(monthly).rows[4]
        XCTAssertEqual(number(squat[1]), 2)
        XCTAssertEqual(number(squat[3]), 1050, accuracy: 0.001)
        // 110 × (1 + 5/30) = 128.33; September's heavier set doesn't count
        XCTAssertEqual(number(squat[4]), 128.3)
    }

    func testSheet_titleAndPeriodLabel() {
        let sheet = ProgressReportExport.sheet(weekly(), locale: english)
        XCTAssertEqual(sheet.name, "Weekly report")
        XCTAssertEqual(text(sheet.rows[0][0]), "RepTrack weekly report")
        XCTAssertEqual(sheet.rows[0][0]?.style, .title)
        XCTAssertEqual(text(sheet.rows[1][0]), "19 Oct 2026 – 25 Oct 2026")
        XCTAssertEqual(sheet.columnWidths, [16, 8, 8, 13, 16])

        let monthly = ProgressReportExport.sheet(report(.month), locale: english)
        XCTAssertEqual(monthly.name, "Monthly report")
        XCTAssertEqual(text(monthly.rows[1][0]), "October 2026")
        // No exercises -> no totals row
        XCTAssertEqual(monthly.rows.count, 4)
    }

    func testFileName_namesThePeriod() {
        XCTAssertEqual(ProgressReportExport.fileName(weekly()), "RepTrack-week-2026-10-19.xlsx")
        XCTAssertEqual(ProgressReportExport.fileName(report(.month)), "RepTrack-month-2026-10.xlsx")
    }

    func testWrite_producesWellFormedWorkbook() throws {
        let data = try ProgressReportExport.write(report(.week, w("2026-10-20", "Curl & Press <DB>", (10, 12.5))))

        let parts = try ZipReader.entries(data)
        XCTAssertEqual(parts.map(\.name), [
            "[Content_Types].xml", "_rels/.rels", "xl/workbook.xml",
            "xl/_rels/workbook.xml.rels", "xl/styles.xml", "xl/worksheets/sheet1.xml",
        ])
        for part in parts {
            XCTAssertTrue(XMLParser(data: part.contents).parse(), "\(part.name) is not well-formed XML")
        }

        let files = Dictionary(uniqueKeysWithValues: parts.map { ($0.name, String(decoding: $0.contents, as: UTF8.self)) })
        let sheet = try XCTUnwrap(files["xl/worksheets/sheet1.xml"])
        XCTAssertTrue(sheet.contains("<t xml:space=\"preserve\">Curl &amp; Press &lt;DB&gt;</t>"))
        XCTAssertTrue(sheet.contains("<c r=\"D5\" s=\"3\"><v>125</v></c>"))
        XCTAssertTrue(sheet.contains("<c r=\"B6\" s=\"6\"><f>SUM(B5:B5)</f><v>1</v></c>"))
        XCTAssertTrue(try XCTUnwrap(files["xl/workbook.xml"]).contains("name=\"Weekly report\""))
    }

    func testColumnName_usesSpreadsheetLetters() {
        XCTAssertEqual(
            [0, 1, 25, 26, 27, 51, 52, 701, 702].map(XlsxWriter.columnName),
            ["A", "B", "Z", "AA", "AB", "AZ", "BA", "ZZ", "AAA"]
        )
    }

    func testWrite_rejectsInvalidSheetNames() {
        XCTAssertThrowsError(try XlsxWriter.write(XlsxSheet(name: "Bad/Name", rows: [])))
        XCTAssertThrowsError(try XlsxWriter.write(XlsxSheet(name: "", rows: [])))
        XCTAssertThrowsError(try XlsxWriter.write(XlsxSheet(name: String(repeating: "x", count: 32), rows: [])))
    }

    func testEscape_dropsControlCharacters() {
        XCTAssertEqual(XlsxWriter.escape("a\u{1}b\tc\"d"), "ab\tc&quot;d")
    }

    func testCrc32_matchesReferenceValue() {
        XCTAssertEqual(CRC32.checksum(Data("123456789".utf8)), 0xCBF4_3926)
    }
}

/// Reads the stored (uncompressed) entries written by `ZipWriter`, checking each CRC.
enum ZipReader {
    struct Entry {
        let name: String
        let contents: Data
    }

    enum Failure: Error {
        case truncated, compressed, badChecksum(String)
    }

    static func entries(_ data: Data) throws -> [Entry] {
        let bytes = [UInt8](data)
        func u16(_ at: Int) throws -> Int {
            guard at + 2 <= bytes.count else { throw Failure.truncated }
            return Int(bytes[at]) | Int(bytes[at + 1]) << 8
        }
        func u32(_ at: Int) throws -> UInt32 {
            guard at + 4 <= bytes.count else { throw Failure.truncated }
            return UInt32(bytes[at]) | UInt32(bytes[at + 1]) << 8 | UInt32(bytes[at + 2]) << 16 | UInt32(bytes[at + 3]) << 24
        }

        var result: [Entry] = []
        var offset = 0
        while offset + 4 <= bytes.count, try u32(offset) == 0x0403_4B50 {
            guard try u16(offset + 8) == 0 else { throw Failure.compressed }
            let crc = try u32(offset + 14)
            let size = Int(try u32(offset + 18))
            let nameLength = try u16(offset + 26)
            let extraLength = try u16(offset + 28)
            let nameStart = offset + 30
            let dataStart = nameStart + nameLength + extraLength
            guard dataStart + size <= bytes.count else { throw Failure.truncated }
            let name = String(decoding: bytes[nameStart..<(nameStart + nameLength)], as: UTF8.self)
            let contents = Data(bytes[dataStart..<(dataStart + size)])
            guard CRC32.checksum(contents) == crc else { throw Failure.badChecksum(name) }
            result.append(Entry(name: name, contents: contents))
            offset = dataStart + size
        }
        guard offset + 4 <= bytes.count, try u32(offset) == 0x0201_4B50 else { throw Failure.truncated }
        return result
    }
}
