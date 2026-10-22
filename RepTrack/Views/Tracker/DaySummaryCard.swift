import SwiftUI

/// Volume, sets done and reps for the selected day, with a completion bar.
struct DaySummaryCard: View {
    let totalVolume: Double
    let totalReps: Int
    let completedSets: Int
    let totalSets: Int

    private var progress: Double { totalSets == 0 ? 0 : Double(completedSets) / Double(totalSets) }
    private var allDone: Bool { totalSets > 0 && completedSets == totalSets }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 0) {
                MetricItem(value: Format.volume(totalVolume), unit: "kg", label: "Volume")
                MetricItem(value: "\(completedSets)", unit: "/ \(totalSets)", label: "Sets done")
                MetricItem(value: "\(totalReps)", unit: nil, label: "Reps")
            }

            ProgressBar(progress: progress)
                .padding(.top, 18)
                .animation(.easeInOut(duration: 0.3), value: progress)

            Text(caption)
                .font(AppFont.bodySmall)
                .foregroundStyle(allDone ? Palette.lime : Palette.textSecondary)
                .padding(.top, 10)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }

    private var caption: String {
        if totalSets == 0 { return "No sets planned yet" }
        if allDone { return "All sets done — nice work" }
        return "\(totalSets - completedSets) sets to go"
    }
}

private struct MetricItem: View {
    let value: String
    let unit: String?
    let label: String

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .lastTextBaseline, spacing: 4) {
                Text(value)
                    .font(AppFont.headlineMedium)
                    .foregroundStyle(Palette.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                if let unit {
                    Text(unit)
                        .font(AppFont.bodyMedium)
                        .foregroundStyle(Palette.textSecondary)
                        .lineLimit(1)
                }
            }
            Text(label)
                .font(AppFont.labelMedium)
                .foregroundStyle(Palette.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

/// Shown when the selected day has no exercises.
struct EmptyDayView: View {
    let isToday: Bool

    var body: some View {
        VStack(spacing: 0) {
            EmptyStateIcon(systemImage: "dumbbell")
            Text(isToday ? "Ready when you are" : "Rest day")
                .font(AppFont.titleMedium)
                .foregroundStyle(Palette.textPrimary)
                .padding(.top, 20)
            Text("Add an exercise to start logging sets.\nTick each set off as you finish it.")
                .font(AppFont.bodyMedium)
                .foregroundStyle(Palette.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.top, 6)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 72)
        .padding(.horizontal, 32)
    }
}
