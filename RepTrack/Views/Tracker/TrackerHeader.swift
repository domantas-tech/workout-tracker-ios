import SwiftUI

/// Title ("Today" or a date), action icons and the swipeable week strip.
struct TrackerHeader<Actions: View>: View {
    let selectedDate: LocalDate
    let today: LocalDate
    let datesWithWorkouts: Set<String>
    let firstDayOfWeek: Weekday
    let onDateSelected: (LocalDate) -> Void
    let onTodayTapped: () -> Void
    @ViewBuilder let actions: Actions

    @State private var showDatePicker = false

    var body: some View {
        let header = DateLabels.header(selected: selectedDate, today: today)

        VStack(spacing: 16) {
            HStack(spacing: 0) {
                Button { showDatePicker = true } label: {
                    VStack(alignment: .leading, spacing: 0) {
                        Text(header.title)
                            .font(AppFont.headlineLarge)
                            .foregroundStyle(Palette.textPrimary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                        Text(header.subtitle)
                            .font(AppFont.bodyMedium)
                            .foregroundStyle(Palette.textSecondary)
                            .lineLimit(1)
                    }
                    .padding(.vertical, 4)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityHint("Pick a date")

                if selectedDate != today {
                    Button("Today", action: onTodayTapped)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Palette.lime)
                        .padding(.horizontal, 6)
                        .transition(.opacity)
                }

                actions

                HeaderIconButton(systemImage: "calendar", label: "Open calendar") { showDatePicker = true }
            }
            .padding(.leading, 20)
            .padding(.trailing, 8)
            .animation(.easeInOut(duration: 0.2), value: selectedDate == today)

            WeekStrip(
                selectedDate: selectedDate,
                today: today,
                datesWithWorkouts: datesWithWorkouts,
                firstDayOfWeek: firstDayOfWeek,
                onDateSelected: onDateSelected
            )
        }
        .padding(.top, 8)
        .padding(.bottom, 12)
        .background(Palette.background)
        .sheet(isPresented: $showDatePicker) {
            DatePickerSheet(initialDate: selectedDate, onSelect: onDateSelected)
        }
    }
}

/// Horizontally paging weeks; effectively infinite in both directions around the current week.
struct WeekStrip: View {
    let selectedDate: LocalDate
    let today: LocalDate
    let datesWithWorkouts: Set<String>
    let firstDayOfWeek: Weekday
    let onDateSelected: (LocalDate) -> Void

    private static let pages = -10_000...10_000

    @State private var page: Int?

    private var currentWeekStart: LocalDate { today.startOfWeek(firstDayOfWeek) }

    private func weekStart(forPage page: Int) -> LocalDate { currentWeekStart.plusWeeks(page) }

    private func pageIndex(for date: LocalDate) -> Int {
        LocalDate.daysBetween(currentWeekStart, date.startOfWeek(firstDayOfWeek)) / 7
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: 0) {
                ForEach(Self.pages, id: \.self) { page in
                    weekRow(start: weekStart(forPage: page))
                        .containerRelativeFrame(.horizontal)
                }
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.paging)
        .scrollPosition(id: $page)
        .frame(height: 80)
        .onAppear { page = pageIndex(for: selectedDate) }
        // Keep the visible week in sync with the selected date (taps, date picker, "Today")
        .onChange(of: selectedDate) { _, newDate in
            let target = pageIndex(for: newDate)
            guard page != target else { return }
            if let current = page, abs(current - target) <= 2 {
                withAnimation(.easeInOut(duration: 0.3)) { page = target }
            } else {
                page = target
            }
        }
        // Swiping to another week moves the selection to the same weekday in that week
        .onChange(of: page) { _, newPage in
            guard let newPage else { return }
            let start = weekStart(forPage: newPage)
            let selectedWeekStart = selectedDate.startOfWeek(firstDayOfWeek)
            if start != selectedWeekStart {
                onDateSelected(start.plusDays(LocalDate.daysBetween(selectedWeekStart, selectedDate)))
            }
        }
    }

    private func weekRow(start: LocalDate) -> some View {
        HStack(spacing: 0) {
            ForEach(0..<7, id: \.self) { offset in
                let date = start.plusDays(offset)
                DayCell(
                    date: date,
                    isSelected: date == selectedDate,
                    isToday: date == today,
                    hasWorkout: datesWithWorkouts.contains(date.isoString)
                ) { onDateSelected(date) }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 12)
    }
}

private struct DayCell: View {
    let date: LocalDate
    let isSelected: Bool
    let isToday: Bool
    let hasWorkout: Bool
    let onTap: () -> Void

    var body: some View {
        VStack(spacing: 6) {
            Text(date.formatted("ccccc"))
                .font(AppFont.labelMedium)
                .foregroundStyle(Palette.textSecondary)
            Button(action: onTap) {
                Text("\(date.day)")
                    .font(.system(size: 15, weight: isSelected || isToday ? .bold : .medium).monospacedDigit())
                    .foregroundStyle(isSelected ? Palette.onLime : (isToday ? Palette.lime : Palette.textPrimary))
                    .frame(width: 42, height: 42)
                    .background(isSelected ? Palette.lime : Color.clear, in: Circle())
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .animation(.easeInOut(duration: 0.2), value: isSelected)
            Circle()
                .fill(hasWorkout ? Palette.lime : Color.clear)
                .frame(width: 4, height: 4)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(date.formatted("EEEE d MMMM") + (hasWorkout ? ", has workouts" : ""))
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
        .accessibilityAction { onTap() }
    }
}

/// Calendar to jump to any date.
struct DatePickerSheet: View {
    let onSelect: (LocalDate) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var date: Date

    init(initialDate: LocalDate, onSelect: @escaping (LocalDate) -> Void) {
        self.onSelect = onSelect
        _date = State(initialValue: initialDate.date())
    }

    var body: some View {
        NavigationStack {
            VStack {
                DatePicker("Date", selection: $date, displayedComponents: .date)
                    .datePickerStyle(.graphical)
                    .labelsHidden()
                    .padding(.horizontal, 12)
                Spacer(minLength: 0)
            }
            .navigationTitle("Pick a date")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Palette.textSecondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Select") {
                        onSelect(LocalDate(date: date))
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.height(500), .large])
        .presentationBackground(Palette.surfaceHigh)
    }
}
