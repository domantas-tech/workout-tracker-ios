import Foundation

/// The weekly / monthly progress report as a spreadsheet: one row per exercise done in the period
/// (completed sets only, like the report itself) with its sets, reps, volume and best e1RM, then totals.
enum ProgressReportExport {

    private static let headers = ["Exercise", "Sets", "Reps", "Volume (kg)", "Best e1RM (kg)"]

    /// "RepTrack-week-2026-10-19.xlsx", "RepTrack-month-2026-10.xlsx"
    static func fileName(_ report: ProgressReport) -> String {
        let start = report.current.start
        switch report.period {
        case .week: return "RepTrack-week-\(start.isoString).xlsx"
        case .month: return "RepTrack-month-\(String(format: "%04d-%02d", start.year, start.month)).xlsx"
        }
    }

    static func write(_ report: ProgressReport, locale: Locale = .current) throws -> Data {
        try XlsxWriter.write(sheet(report, locale: locale))
    }

    static func sheet(_ report: ProgressReport, locale: Locale = .current) -> XlsxSheet {
        var rows: [[XlsxCell?]] = []
        rows.append([.text(title(report.period), style: .title)])
        rows.append([.text(periodLabel(report, locale: locale))])
        rows.append([])
        rows.append(headers.map { XlsxCell.text($0, style: .header) })

        let firstExerciseRow = rows.count + 1
        for exercise in report.exercises {
            let stats = exercise.current
            rows.append([
                .text(exercise.name),
                .number(Double(stats.sets), style: .integer),
                .number(Double(stats.reps), style: .integer),
                .number(stats.volume, style: .integer),
                // Unweighted exercises have no e1RM; rounded to 0.1 kg like the app shows it
                stats.isWeighted ? XlsxCell.number(Format.roundHalfUp(stats.bestOneRepMax * 10) / 10, style: .decimal) : nil,
            ])
        }
        let lastExerciseRow = rows.count

        if !report.exercises.isEmpty {
            // Formulas keep the totals right if the sheet is edited
            func total(_ column: String, _ cached: Double) -> XlsxCell {
                .formula("SUM(\(column)\(firstExerciseRow):\(column)\(lastExerciseRow))", cached: cached, style: .totalInteger)
            }
            let stats = report.exercises.map(\.current)
            rows.append([
                .text("Total", style: .total),
                total("B", Double(stats.reduce(0) { $0 + $1.sets })),
                total("C", Double(stats.reduce(0) { $0 + $1.reps })),
                total("D", stats.reduce(0.0) { $0 + $1.volume }),
                .blank(style: .total),
            ])
        }

        let longestName = report.exercises.map { $0.name.utf16.count }.max() ?? 0
        return XlsxSheet(
            name: report.period == .week ? "Weekly report" : "Monthly report",
            rows: rows,
            columnWidths: [Double(min(max(longestName + 2, 16), 48)), 8, 8, 13, 16]
        )
    }

    private static func title(_ period: ProgressPeriod) -> String {
        switch period {
        case .week: return "RepTrack weekly report"
        case .month: return "RepTrack monthly report"
        }
    }

    /// "19 Oct 2026 – 25 Oct 2026", "October 2026" (in the current locale)
    private static func periodLabel(_ report: ProgressReport, locale: Locale) -> String {
        switch report.period {
        case .week:
            return "\(report.current.start.formatted("d MMM yyyy", locale: locale)) – \(report.current.endInclusive.formatted("d MMM yyyy", locale: locale))"
        case .month:
            return report.current.start.formatted("MMMM yyyy", locale: locale)
        }
    }
}
