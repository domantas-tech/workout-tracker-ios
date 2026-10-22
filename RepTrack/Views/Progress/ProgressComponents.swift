import Charts
import SwiftUI

private func deltaColor(_ delta: Double?) -> Color {
    guard let delta, abs(delta) >= 0.5 else { return Palette.textSecondary }
    return delta > 0 ? Palette.lime : Palette.coral
}

/// Week | Month
struct PeriodSelector: View {
    let period: ProgressPeriod
    let onSelect: (ProgressPeriod) -> Void

    var body: some View {
        Picker("Period", selection: Binding(get: { period }, set: onSelect)) {
            Text("Week").tag(ProgressPeriod.week)
            Text("Month").tag(ProgressPeriod.month)
        }
        .pickerStyle(.segmented)
    }
}

/// ‹ "13 – 19 Oct" › with "This week · so far vs 6 – 12 Oct", and a way back to the current period.
struct PeriodNavigator: View {
    let report: ProgressReport
    let today: LocalDate
    let onPrevious: () -> Void
    let onNext: () -> Void
    let onCurrent: () -> Void

    var body: some View {
        let isCurrent = report.current.contains(today)
        let canGoForward = report.current.endInclusive < today
        let unit = report.period.unitName

        VStack(spacing: 0) {
            HStack(spacing: 0) {
                arrow("chevron.left", label: "Previous \(unit)", enabled: true, action: onPrevious)
                VStack(spacing: 2) {
                    Text(DateLabels.longLabel(report.period, report.current))
                        .font(AppFont.titleMedium)
                        .foregroundStyle(Palette.textPrimary)
                        .lineLimit(1)
                    Text(DateLabels.navigatorSubtitle(report, today: today))
                        .font(AppFont.bodySmall)
                        .foregroundStyle(Palette.textSecondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                .frame(maxWidth: .infinity)
                arrow("chevron.right", label: "Next \(unit)", enabled: canGoForward, action: onNext)
            }
            if !isCurrent {
                Button(report.period == .week ? "Back to this week" : "Back to this month", action: onCurrent)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Palette.lime)
                    .frame(minHeight: 40)
            }
        }
    }

    private func arrow(_ systemImage: String, label: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(enabled ? Palette.textPrimary : Palette.surfaceHighest)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .accessibilityLabel(label)
    }
}

/// Headline card: how many exercises were overloaded vs the previous period.
struct OverloadSummaryCard: View {
    let report: ProgressReport
    let previousLabel: String

    var body: some View {
        let comparable = report.comparableCount
        let improved = report.improvedCount

        VStack(alignment: .leading, spacing: 0) {
            Text("Progressive overload")
                .font(AppFont.labelLarge)
                .foregroundStyle(Palette.textSecondary)
                .padding(.bottom, 8)

            if comparable == 0 {
                Text("Nothing to compare yet")
                    .font(AppFont.titleMedium)
                    .foregroundStyle(Palette.textPrimary)
                Text("Repeat an exercise from \(previousLabel) to see whether you're getting stronger.")
                    .font(AppFont.bodyMedium)
                    .foregroundStyle(Palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 4)
            } else {
                HStack(alignment: .lastTextBaseline, spacing: 6) {
                    Text("\(improved)")
                        .font(AppFont.displaySmall)
                        .foregroundStyle(Palette.lime)
                    Text("of \(comparable) exercises improved")
                        .font(AppFont.bodyLarge)
                        .foregroundStyle(Palette.textPrimary)
                }
                .accessibilityElement(children: .combine)

                // Segmented bar: one segment per comparable exercise
                HStack(spacing: 3) {
                    ForEach(0..<comparable, id: \.self) { index in
                        RoundedRectangle(cornerRadius: 3)
                            .fill(index < improved ? Palette.lime : Palette.surfaceHighest)
                    }
                }
                .frame(height: 6)
                .padding(.top, 12)
                .animation(.easeInOut(duration: 0.3), value: improved)
                .accessibilityHidden(true)

                Text("Compared with \(previousLabel): a higher best e1RM (or more reps in your best unweighted set) counts as progress.")
                    .font(AppFont.bodySmall)
                    .foregroundStyle(Palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 10)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }
}

/// A single metric with its change vs the previous period.
struct StatTile: View {
    let label: String
    let value: String
    var unit: String?
    let percentChange: Double?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(label)
                .font(AppFont.labelMedium)
                .foregroundStyle(Palette.textSecondary)
            HStack(alignment: .lastTextBaseline, spacing: 4) {
                Text(value)
                    .font(AppFont.headlineSmall)
                    .foregroundStyle(Palette.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                if let unit {
                    Text(unit)
                        .font(AppFont.bodySmall)
                        .foregroundStyle(Palette.textSecondary)
                }
            }
            .padding(.top, 4)
            Text(Format.percentChange(percentChange) ?? "—")
                .font(.system(size: 12, weight: .semibold).monospacedDigit())
                .foregroundStyle(deltaColor(percentChange))
                .padding(.top, 2)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .card(radius: Radius.medium)
        .accessibilityElement(children: .combine)
    }
}

struct StatsGrid: View {
    let report: ProgressReport

    var body: some View {
        let cur = report.currentStats
        let prev = report.previousStats
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                StatTile(label: "Volume", value: Format.volume(cur.volume), unit: "kg",
                         percentChange: percentChange(cur.volume, prev.volume))
                StatTile(label: "Training days", value: "\(cur.trainingDays)",
                         percentChange: percentChange(Double(cur.trainingDays), Double(prev.trainingDays)))
            }
            HStack(spacing: 12) {
                StatTile(label: "Sets done", value: "\(cur.sets)",
                         percentChange: percentChange(Double(cur.sets), Double(prev.sets)))
                StatTile(label: "Reps", value: "\(cur.reps)",
                         percentChange: percentChange(Double(cur.reps), Double(prev.reps)))
            }
        }
    }
}

/// Volume per period as bars, oldest on the left. The viewed period is highlighted;
/// tapping a bar jumps to that period.
struct VolumeHistoryChart: View {
    let points: [PeriodPoint]
    let selectedStart: LocalDate
    let label: (PeriodPoint) -> String
    let onSelect: (PeriodPoint) -> Void

    var body: some View {
        let maxVolume = max(points.map(\.volume).max() ?? 0, 0)
        let scale = maxVolume > 0 ? maxVolume : 1
        let labels = points.map(label)

        VStack(alignment: .leading, spacing: 16) {
            Text("Volume trend")
                .font(AppFont.labelLarge)
                .foregroundStyle(Palette.textSecondary)

            Chart {
                ForEach(Array(points.enumerated()), id: \.offset) { index, point in
                    let isSelected = point.range.start == selectedStart
                    BarMark(
                        x: .value("Period", labels[index]),
                        // Keep empty periods visible as a sliver
                        y: .value("Volume", max(point.volume, scale * 0.02))
                    )
                    .foregroundStyle(isSelected ? Palette.lime : Palette.surfaceHighest)
                    .cornerRadius(6)
                    .annotation(position: .top, spacing: 4) {
                        if isSelected {
                            Text(Format.compact(point.volume))
                                .font(AppFont.labelSmall)
                                .foregroundStyle(Palette.lime)
                        }
                    }
                    .accessibilityLabel(labels[index])
                    .accessibilityValue("\(Format.volume(point.volume)) kg")
                }
            }
            .chartYScale(domain: 0...(scale * 1.18))
            .chartYAxis(.hidden)
            .chartXAxis {
                AxisMarks { value in
                    AxisValueLabel {
                        if let text = value.as(String.self) {
                            let isSelected = labels.firstIndex(of: text).map { points[$0].range.start == selectedStart } ?? false
                            Text(text)
                                .font(AppFont.labelSmall)
                                .foregroundStyle(isSelected ? Palette.textPrimary : Palette.textSecondary)
                        }
                    }
                }
            }
            .chartOverlay { proxy in
                GeometryReader { geometry in
                    Rectangle()
                        .fill(Color.clear)
                        .contentShape(Rectangle())
                        .onTapGesture { location in
                            guard let plotFrame = proxy.plotFrame else { return }
                            let x = location.x - geometry[plotFrame].origin.x
                            if let tapped: String = proxy.value(atX: x), let index = labels.firstIndex(of: tapped) {
                                onSelect(points[index])
                            }
                        }
                }
            }
            .frame(height: 150)
            .animation(.easeInOut(duration: 0.3), value: points)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }
}

/// One exercise's e1RM (or best-set reps when unweighted) vs the previous period.
struct ExerciseProgressRow: View {
    let progress: ExerciseProgress
    let period: ProgressPeriod

    var body: some View {
        let current = progress.current
        let previous = progress.previous
        let unit = period.unitName

        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 0) {
                    Text(progress.name)
                        .font(AppFont.titleMedium)
                        .foregroundStyle(Palette.textPrimary)
                        .lineLimit(1)
                    Text(progress.comparesOneRepMax ? "e1RM \(unit)-to-\(unit)" : "Best set reps \(unit)-to-\(unit)")
                        .font(AppFont.labelSmall)
                        .foregroundStyle(Palette.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                TrendBadge(trend: progress.trend, changePercent: progress.changePercent)
            }

            HStack(alignment: .top, spacing: 0) {
                if progress.comparesOneRepMax {
                    ExerciseMetric(
                        label: "e1RM",
                        value: Format.oneRepMax(current.bestOneRepMax),
                        delta: previous.map { current.bestOneRepMax - $0.bestOneRepMax },
                        deltaText: previous.map { "\(Format.signedDelta(current.bestOneRepMax - $0.bestOneRepMax)) kg" }
                    )
                    ExerciseMetric(
                        label: "Prev. \(unit)",
                        value: previous.map { Format.oneRepMax($0.bestOneRepMax) } ?? "—",
                        delta: nil,
                        deltaText: nil
                    )
                } else {
                    ExerciseMetric(
                        label: "Best set",
                        value: "\(current.bestReps) reps",
                        delta: previous.map { Double(current.bestReps - $0.bestReps) },
                        deltaText: previous.map { Format.signedDelta(Double(current.bestReps - $0.bestReps)) }
                    )
                    ExerciseMetric(
                        label: "Prev. \(unit)",
                        value: previous.map { "\($0.bestReps) reps" } ?? "—",
                        delta: nil,
                        deltaText: nil
                    )
                }
                let volumeChange = previous.flatMap { percentChange(current.volume, $0.volume) }
                ExerciseMetric(
                    label: "Volume · \(current.sets) sets",
                    value: "\(Format.volume(current.volume)) kg",
                    delta: volumeChange,
                    deltaText: Format.percentChange(volumeChange)
                )
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .card(radius: Radius.medium)
    }
}

private struct ExerciseMetric: View {
    let label: String
    let value: String
    let delta: Double?
    let deltaText: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(label)
                .font(AppFont.labelSmall)
                .foregroundStyle(Palette.textSecondary)
                .lineLimit(1)
            Text(value)
                .font(.system(size: 16, weight: .semibold).monospacedDigit())
                .foregroundStyle(Palette.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            if let deltaText {
                Text(deltaText)
                    .font(.system(size: 11, weight: .semibold).monospacedDigit())
                    .foregroundStyle(deltaColor(delta))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

/// Trend arrow with the period-over-period change, e.g. "↗ +10%"; "New" without a baseline.
struct TrendBadge: View {
    let trend: ProgressTrend
    let changePercent: Double?

    var body: some View {
        let text = trend == .new ? "New" : (Format.percentChange(changePercent) ?? "—")
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .bold))
            Text(text)
                .font(.system(size: 15, weight: .bold).monospacedDigit())
        }
        .foregroundStyle(color)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Palette.surfaceHigh, in: RoundedRectangle(cornerRadius: Radius.extraSmall, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(description(text))
    }

    private var icon: String {
        switch trend {
        case .up: return "arrow.up.right"
        case .same: return "arrow.right"
        case .down: return "arrow.down.right"
        case .new: return "sparkles"
        }
    }

    private var color: Color {
        switch trend {
        case .up: return Palette.lime
        case .down: return Palette.coral
        case .same, .new: return Palette.textSecondary
        }
    }

    private func description(_ text: String) -> String {
        switch trend {
        case .up: return "Progressed \(text)"
        case .same: return "Held"
        case .down: return "Regressed \(text)"
        case .new: return "New this period"
        }
    }
}

/// "4 progressed  1 held  2 regressed  3 new"
struct ExerciseTally: View {
    let report: ProgressReport

    var body: some View {
        let counts = Dictionary(grouping: report.exercises, by: \.trend).mapValues(\.count)
        HStack(spacing: 12) {
            tally(counts[.up] ?? 0, "progressed", Palette.lime)
            tally(counts[.same] ?? 0, "held", Palette.textSecondary)
            tally(counts[.down] ?? 0, "regressed", Palette.coral)
            tally(counts[.new] ?? 0, "new", Palette.textSecondary)
        }
        .padding(.horizontal, 4)
        .lineLimit(1)
        .minimumScaleFactor(0.8)
    }

    private func tally(_ count: Int, _ label: String, _ color: Color) -> some View {
        Text("\(count) \(label)")
            .font(AppFont.labelLarge)
            .foregroundStyle(color)
    }
}

/// Shown when the period has no completed sets.
struct EmptyPeriodView: View {
    let period: ProgressPeriod

    var body: some View {
        VStack(spacing: 0) {
            EmptyStateIcon(systemImage: "chart.line.uptrend.xyaxis", size: 64)
            Text("No completed sets this \(period.unitName)")
                .font(AppFont.titleMedium)
                .foregroundStyle(Palette.textPrimary)
                .multilineTextAlignment(.center)
                .padding(.top, 16)
            Text("Tick sets off as you finish them — only completed sets count towards progress.")
                .font(AppFont.bodyMedium)
                .foregroundStyle(Palette.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.top, 6)
        }
        .frame(maxWidth: .infinity)
        .padding(32)
    }
}
