import SwiftUI

/// Exercises shown on the overview; the rest are behind "See all".
private let topExerciseCount = 6

/// Weekly / monthly report: overload summary, stats, volume trend and the top exercises.
struct ProgressScreen: View {
    let viewModel: ProgressViewModel

    @State private var showAllExercises = false
    @State private var toast: ToastMessage?

    var body: some View {
        let today = viewModel.today

        ScrollView {
            LazyVStack(spacing: 12) {
                PeriodSelector(period: viewModel.period) { viewModel.selectPeriod($0) }

                if let report = viewModel.report {
                    PeriodNavigator(
                        report: report,
                        today: today,
                        onPrevious: { viewModel.goToPreviousPeriod() },
                        onNext: { viewModel.goToNextPeriod() },
                        onCurrent: { viewModel.goToCurrentPeriod() }
                    )

                    if report.currentStats.sets == 0 {
                        EmptyPeriodView(period: report.period)
                        historyChart(report)
                    } else {
                        OverloadSummaryCard(
                            report: report,
                            previousLabel: DateLabels.relativeName(report.period, report.previous, today: today)
                        )
                        StatsGrid(report: report)
                        historyChart(report)

                        HStack {
                            Text(report.exercises.count > topExerciseCount ? "Top \(topExerciseCount) exercises" : "Exercises")
                                .font(AppFont.titleMedium)
                                .foregroundStyle(Palette.textPrimary)
                            Spacer()
                            Button("See all (\(report.exercises.count))") { showAllExercises = true }
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(Palette.lime)
                        }
                        .padding(.top, 8)
                        .padding(.leading, 4)

                        ForEach(report.exercises.prefix(topExerciseCount), id: \.name) { exercise in
                            ExerciseProgressRow(progress: exercise, period: report.period)
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 4)
            .padding(.bottom, 32)
            .animation(.easeInOut(duration: 0.25), value: viewModel.report)
        }
        .background(Palette.background.ignoresSafeArea())
        .navigationTitle("Progress")
        .navigationBarTitleDisplayMode(.large)
        .toolbarBackground(Palette.background, for: .navigationBar)
        .reportExport(report: viewModel.report, toast: $toast)
        .toast($toast)
        .navigationDestination(isPresented: $showAllExercises) {
            AllExercisesScreen(viewModel: viewModel)
        }
    }

    private func historyChart(_ report: ProgressReport) -> some View {
        VolumeHistoryChart(
            points: report.history,
            selectedStart: report.current.start,
            label: { DateLabels.shortLabel(report.period, $0.range) },
            onSelect: { viewModel.goToPeriodContaining($0.range.start) }
        )
    }
}

/// Every exercise done in the period, sortable, so regressions are easy to spot.
struct AllExercisesScreen: View {
    let viewModel: ProgressViewModel

    @State private var sort: ExerciseSort = .mostTrained
    @State private var toast: ToastMessage?

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                PeriodSelector(period: viewModel.period) { viewModel.selectPeriod($0) }

                if let report = viewModel.report {
                    PeriodNavigator(
                        report: report,
                        today: viewModel.today,
                        onPrevious: { viewModel.goToPreviousPeriod() },
                        onNext: { viewModel.goToNextPeriod() },
                        onCurrent: { viewModel.goToCurrentPeriod() }
                    )

                    if report.exercises.isEmpty {
                        EmptyPeriodView(period: report.period)
                    } else {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(ExerciseSort.allCases, id: \.self) { option in
                                    Chip(label: option.label, systemImage: sort == option ? "checkmark" : nil, isSelected: sort == option) {
                                        sort = option
                                    }
                                }
                            }
                        }

                        ExerciseTally(report: report)

                        ForEach(sort.sorted(report.exercises), id: \.name) { exercise in
                            ExerciseProgressRow(progress: exercise, period: report.period)
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 4)
            .padding(.bottom, 32)
            .animation(.easeInOut(duration: 0.25), value: sort)
        }
        .background(Palette.background.ignoresSafeArea())
        .navigationTitle("All exercises")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Palette.background, for: .navigationBar)
        .reportExport(report: viewModel.report, toast: $toast)
        .toast($toast)
    }
}

/// Toolbar button that saves the report being viewed as an .xlsx file via the system "Save to Files"
/// dialog, then reports the outcome. Disabled while there are no completed sets to export.
private struct ReportExportModifier: ViewModifier {
    let report: ProgressReport?
    @Binding var toast: ToastMessage?

    @State private var document: XlsxDocument?
    @State private var fileName = ""
    @State private var isExporting = false

    private var canExport: Bool { !(report?.exercises.isEmpty ?? true) }

    func body(content: Content) -> some View {
        content
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: export) {
                        Image(systemName: "square.and.arrow.down")
                            .foregroundStyle(canExport ? Palette.textSecondary : Palette.surfaceHighest)
                    }
                    .disabled(!canExport)
                    .accessibilityLabel("Export to Excel")
                }
            }
            .fileExporter(
                isPresented: $isExporting,
                document: document,
                contentType: XlsxDocument.contentType,
                defaultFilename: fileName,
                onCompletion: { result in
                    switch result {
                    case .success:
                        toast = ToastMessage(text: "Report exported")
                    case let .failure(error):
                        // Backing out of the save dialog is not an error
                        if (error as? CocoaError)?.code == .userCancelled { return }
                        toast = ToastMessage(text: "Couldn't export the report")
                    }
                }
            )
    }

    private func export() {
        guard let report, canExport else { return }
        do {
            document = XlsxDocument(data: try ProgressReportExport.write(report))
            fileName = String(ProgressReportExport.fileName(report).dropLast(".xlsx".count))
            isExporting = true
        } catch {
            toast = ToastMessage(text: "Couldn't export the report")
        }
    }
}

private extension View {
    func reportExport(report: ProgressReport?, toast: Binding<ToastMessage?>) -> some View {
        modifier(ReportExportModifier(report: report, toast: toast))
    }
}
