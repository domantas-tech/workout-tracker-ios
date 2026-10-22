import XCTest
@testable import RepTrack

/// Database behaviour (the Android DAO transactions + repository rules), on an in-memory store.
@MainActor
final class WorkoutRepositoryTests: XCTestCase {

    private var store: DataStore!
    private var repo: WorkoutRepository { store.workouts }

    override func setUp() async throws {
        try await super.setUp()
        store = try DataStore(inMemory: true)
    }

    override func tearDown() async throws {
        store = nil
        try await super.tearDown()
    }

    func testCreateWorkout_addsNumberedSetsNotCompleted() throws {
        let id = repo.createWorkout(name: "  Bench Press ", date: "2026-10-21", setsCount: 3, defaultReps: 8, defaultWeight: 60)
        let day = repo.workoutsWithSets(forDate: "2026-10-21")
        XCTAssertEqual(day.count, 1)
        let workout = try XCTUnwrap(day.first)
        XCTAssertEqual(workout.id, id)
        XCTAssertEqual(workout.workout.name, "Bench Press")
        XCTAssertEqual(workout.orderedSets.map(\.setNumber), [1, 2, 3])
        XCTAssertTrue(workout.sets.allSatisfy { $0.reps == 8 && $0.weight == 60 && !$0.isCompleted })
    }

    func testCreateWorkout_clampsInputs() throws {
        repo.createWorkout(name: "Curl", date: "2026-10-21", setsCount: 0, defaultReps: 0, defaultWeight: -5)
        let workout = try XCTUnwrap(repo.workoutsWithSets(forDate: "2026-10-21").first)
        XCTAssertEqual(workout.sets.count, 1)
        XCTAssertEqual(workout.sets.first?.reps, 1)
        XCTAssertEqual(workout.sets.first?.weight, 0)
    }

    func testWorkoutsForDate_keepCreationOrder_andRangeQuery() {
        repo.createWorkout(name: "A", date: "2026-10-21", setsCount: 1, defaultReps: 5)
        repo.createWorkout(name: "B", date: "2026-10-21", setsCount: 1, defaultReps: 5)
        repo.createWorkout(name: "C", date: "2026-10-19", setsCount: 1, defaultReps: 5)
        repo.createWorkout(name: "D", date: "2026-11-02", setsCount: 1, defaultReps: 5)
        XCTAssertEqual(repo.workoutsWithSets(forDate: "2026-10-21").map(\.workout.name), ["A", "B"])
        XCTAssertEqual(repo.workoutsWithSets(from: "2026-10-19", through: "2026-10-31").map(\.workout.name), ["C", "A", "B"])
        XCTAssertEqual(repo.datesWithWorkouts(), ["2026-10-21", "2026-10-19", "2026-11-02"])
        XCTAssertEqual(Set(repo.recentWorkoutNames()), ["A", "B", "C", "D"])
    }

    func testAddSet_copiesLastSet() throws {
        let id = repo.createWorkout(name: "Squat", date: "2026-10-21", setsCount: 2, defaultReps: 5, defaultWeight: 100)
        let sets = repo.sets(forWorkout: id)
        repo.updateSet(sets[1].id, newReps: 3, newWeight: 120)
        repo.addSetToWorkout(id)
        let last = try XCTUnwrap(repo.sets(forWorkout: id).last)
        XCTAssertEqual(last.setNumber, 3)
        XCTAssertEqual(last.reps, 3)
        XCTAssertEqual(last.weight, 120)
        XCTAssertFalse(last.isCompleted)
    }

    func testAddSet_toEmptyWorkoutUsesDefaults() throws {
        let id = repo.createWorkout(name: "Dips", date: "2026-10-21", setsCount: 1, defaultReps: 5)
        repo.deleteSet(try XCTUnwrap(repo.sets(forWorkout: id).first).id)
        repo.addSetToWorkout(id)
        let set = try XCTUnwrap(repo.sets(forWorkout: id).first)
        XCTAssertEqual(set.setNumber, 1)
        XCTAssertEqual(set.reps, 10)
        XCTAssertEqual(set.weight, 0)
    }

    func testUpdates_clampAtZero() throws {
        let id = repo.createWorkout(name: "Row", date: "2026-10-21", setsCount: 1, defaultReps: 5, defaultWeight: 40)
        let setId = try XCTUnwrap(repo.sets(forWorkout: id).first).id
        repo.updateSetReps(setId, newReps: -3)
        repo.updateSetWeight(setId, newWeight: -1)
        var set = try XCTUnwrap(repo.sets(forWorkout: id).first)
        XCTAssertEqual(set.reps, 0)
        XCTAssertEqual(set.weight, 0)
        repo.toggleSetCompleted(setId, completed: true)
        set = try XCTUnwrap(repo.sets(forWorkout: id).first)
        XCTAssertTrue(set.isCompleted)
    }

    func testDeleteSet_renumbersAndRestoreSetPutsItBack() throws {
        let id = repo.createWorkout(name: "Press", date: "2026-10-21", setsCount: 4, defaultReps: 5)
        var sets = repo.sets(forWorkout: id)
        repo.updateSetReps(sets[1].id, newReps: 7)
        sets = repo.sets(forWorkout: id)
        let deleted = sets[1]

        repo.deleteSet(deleted.id)
        let afterDelete = repo.sets(forWorkout: id)
        XCTAssertEqual(afterDelete.map(\.setNumber), [1, 2, 3])
        XCTAssertFalse(afterDelete.contains { $0.id == deleted.id })

        repo.restoreSet(deleted)
        let restored = repo.sets(forWorkout: id)
        XCTAssertEqual(restored.map(\.setNumber), [1, 2, 3, 4])
        XCTAssertEqual(restored[1].id, deleted.id)
        XCTAssertEqual(restored[1].reps, 7)
        XCTAssertEqual(restored.map(\.id), sets.map(\.id))
    }

    func testRestoreSet_isIgnoredWhenWorkoutIsGone() throws {
        let id = repo.createWorkout(name: "Press", date: "2026-10-21", setsCount: 2, defaultReps: 5)
        let set = try XCTUnwrap(repo.sets(forWorkout: id).first)
        repo.deleteSet(set.id)
        repo.deleteWorkout(id)
        repo.restoreSet(set)
        XCTAssertTrue(repo.sets(forWorkout: id).isEmpty)
    }

    func testDeleteWorkout_cascadesAndRestoreBringsBackSameIds() throws {
        let first = repo.createWorkout(name: "First", date: "2026-10-21", setsCount: 1, defaultReps: 5)
        let id = repo.createWorkout(name: "Second", date: "2026-10-21", setsCount: 3, defaultReps: 5)
        let snapshot = try XCTUnwrap(repo.workoutsWithSets(forDate: "2026-10-21").last)

        repo.deleteWorkout(id)
        XCTAssertEqual(repo.workoutsWithSets(forDate: "2026-10-21").map(\.id), [first])
        XCTAssertTrue(repo.sets(forWorkout: id).isEmpty)

        // A new workout never reuses the deleted id, so undo can't clash with it
        let newer = repo.createWorkout(name: "Third", date: "2026-10-21", setsCount: 1, defaultReps: 5)
        XCTAssertGreaterThan(newer, id)

        repo.restoreWorkout(snapshot)
        let day = repo.workoutsWithSets(forDate: "2026-10-21")
        XCTAssertEqual(day.map(\.id), [first, id, newer])
        XCTAssertEqual(day[1].sets.map(\.id).sorted(), snapshot.sets.map(\.id).sorted())
    }

    func testCopyWorkoutToDate_copiesSetsUnticked() throws {
        let id = repo.createWorkout(name: "Deadlift", date: "2026-10-14", setsCount: 2, defaultReps: 5, defaultWeight: 140)
        for set in repo.sets(forWorkout: id) { repo.toggleSetCompleted(set.id, completed: true) }
        let copyId = try XCTUnwrap(repo.copyWorkoutToDate(id, targetDate: "2026-10-21"))
        let copy = try XCTUnwrap(repo.workoutsWithSets(forDate: "2026-10-21").first)
        XCTAssertEqual(copy.id, copyId)
        XCTAssertEqual(copy.workout.name, "Deadlift")
        XCTAssertEqual(copy.orderedSets.map(\.reps), [5, 5])
        XCTAssertEqual(copy.orderedSets.map(\.weight), [140, 140])
        XCTAssertTrue(copy.sets.allSatisfy { !$0.isCompleted })
        // The original is untouched
        XCTAssertTrue(repo.sets(forWorkout: id).allSatisfy(\.isCompleted))
    }

    func testRename_trims() throws {
        let id = repo.createWorkout(name: "Bench", date: "2026-10-21", setsCount: 1, defaultReps: 5)
        repo.updateWorkoutName(id, newName: "  Incline Bench ")
        XCTAssertEqual(repo.workout(id: id)?.name, "Incline Bench")
    }

    func testChangesNotifyObservers() {
        var notifications = 0
        store.observe { notifications += 1 }
        repo.createWorkout(name: "Bench", date: "2026-10-21", setsCount: 1, defaultReps: 5)
        XCTAssertEqual(notifications, 1)
    }
}

@MainActor
final class ProfileAndSavedExerciseRepositoryTests: XCTestCase {

    private var store: DataStore!

    override func setUp() async throws {
        try await super.setUp()
        store = try DataStore(inMemory: true)
    }

    override func tearDown() async throws {
        store = nil
        try await super.tearDown()
    }

    func testProfile_emptyUntilSaved_thenSanitized() {
        XCTAssertTrue(store.userProfile.profile().isEmpty)
        store.userProfile.updateProfile(weightKg: 82.5, heightCm: 999, gender: .male)
        XCTAssertEqual(store.userProfile.profile(), UserProfile(weightKg: 82.5, heightCm: 300, gender: .male))
        store.userProfile.updateProfile(weightKg: 0, heightCm: nil, gender: nil)
        XCTAssertTrue(store.userProfile.profile().isEmpty)
        XCTAssertNil(store.userProfile.bodyWeightKg())
    }

    func testSavedExercises_addSanitizesSkipsDuplicatesAndRemoves() throws {
        let saved = store.savedExercises
        saved.add("  Bench   Press ")
        saved.add("bench press")
        saved.add("   ")
        saved.add("Pull-ups")
        XCTAssertEqual(saved.exercises().map(\.name), ["Bench Press", "Pull-ups"])
        saved.remove(id: try XCTUnwrap(saved.exercises().first).id)
        XCTAssertEqual(saved.exercises().map(\.name), ["Pull-ups"])
    }
}

@MainActor
final class ViewModelTests: XCTestCase {

    func testAddWorkout_prefillsBodyWeightExercises() throws {
        let store = try DataStore(inMemory: true)
        let viewModel = WorkoutViewModel(store: store, restTimer: RestTimer(runsLoop: false), today: LocalDate(2026, 10, 21))
        viewModel.updateProfile(weightKg: 80, heightCm: nil, gender: nil)
        viewModel.addWorkout(name: "Pull-ups", setsCount: 2, defaultReps: 8)
        viewModel.addWorkout(name: "   ")

        XCTAssertEqual(viewModel.workouts.count, 1)
        let pullUps = try XCTUnwrap(viewModel.workouts.first)
        XCTAssertEqual(pullUps.sets.first?.weight ?? 0, 76, accuracy: 0.001)
        XCTAssertEqual(viewModel.totalSetsToday, 2)
        XCTAssertEqual(viewModel.totalRepsToday, 16)
        XCTAssertEqual(viewModel.datesWithWorkouts, ["2026-10-21"])
    }

    func testTickingASetStartsTheRestTimerWhenAutoStartIsOn() throws {
        let store = try DataStore(inMemory: true)
        let timer = RestTimer(runsLoop: false)
        let viewModel = WorkoutViewModel(store: store, restTimer: timer, today: LocalDate(2026, 10, 21))
        viewModel.addWorkout(name: "Squat", setsCount: 2, defaultReps: 5)
        let sets = try XCTUnwrap(viewModel.workouts.first).orderedSets

        viewModel.toggleSetCompleted(sets[0].id, isCompleted: true)
        XCTAssertTrue(timer.isRunning)
        XCTAssertEqual(timer.secondsRemaining, 90)
        XCTAssertEqual(viewModel.completedSetsToday, 1)

        timer.stop()
        timer.autoStartRest = false
        viewModel.toggleSetCompleted(sets[1].id, isCompleted: true)
        XCTAssertFalse(timer.isRunning)
    }

    func testSelectingADateLoadsItsWorkouts() throws {
        let store = try DataStore(inMemory: true)
        let viewModel = WorkoutViewModel(store: store, restTimer: RestTimer(runsLoop: false), today: LocalDate(2026, 10, 21))
        viewModel.addWorkout(name: "Squat")
        viewModel.goToPreviousDay()
        XCTAssertEqual(viewModel.selectedDate, LocalDate(2026, 10, 20))
        XCTAssertTrue(viewModel.workouts.isEmpty)
        viewModel.copyWorkoutToDate(try XCTUnwrap(store.workouts.workoutsWithSets(forDate: "2026-10-21").first).id,
                                    targetDate: LocalDate(2026, 10, 20))
        XCTAssertEqual(viewModel.workouts.map(\.workout.name), ["Squat"])
    }

    func testProgressViewModel_navigatesPeriodsAndRebuildsOnChanges() throws {
        let store = try DataStore(inMemory: true)
        let today = LocalDate(2026, 10, 21)
        let viewModel = ProgressViewModel(store: store, firstDayOfWeek: .monday, today: { today })
        XCTAssertEqual(viewModel.report?.current.start, LocalDate(2026, 10, 19))
        XCTAssertFalse(viewModel.canGoForward)

        let id = store.workouts.createWorkout(name: "Squat", date: "2026-10-20", setsCount: 1, defaultReps: 5, defaultWeight: 100)
        store.workouts.toggleSetCompleted(try XCTUnwrap(store.workouts.sets(forWorkout: id).first).id, completed: true)
        XCTAssertEqual(viewModel.report?.currentStats.sets, 1)

        viewModel.goToPreviousPeriod()
        XCTAssertEqual(viewModel.report?.current.start, LocalDate(2026, 10, 12))
        XCTAssertTrue(viewModel.canGoForward)
        viewModel.goToNextPeriod()
        viewModel.goToNextPeriod()
        XCTAssertEqual(viewModel.report?.current.start, LocalDate(2026, 10, 19))

        viewModel.selectPeriod(.month)
        XCTAssertEqual(viewModel.report?.current.start, LocalDate(2026, 10, 1))
        viewModel.goToPeriodContaining(LocalDate(2027, 1, 1))
        XCTAssertEqual(viewModel.anchor, today)
    }
}

@MainActor
final class RestTimerTests: XCTestCase {

    private var clock = Date(timeIntervalSince1970: 1_000_000)

    private func makeTimer() -> RestTimer {
        RestTimer(now: { [unowned self] in self.clock }, runsLoop: false)
    }

    func testStart_setsDurationAndCountsDown() {
        let timer = makeTimer()
        timer.start(60)
        XCTAssertTrue(timer.isRunning)
        XCTAssertEqual(timer.secondsRemaining, 60)
        XCTAssertEqual(timer.totalSeconds, 60)
        XCTAssertEqual(timer.restDurationSeconds, 60)

        clock += 1
        timer.tick()
        XCTAssertEqual(timer.secondsRemaining, 59)

        clock += 59
        timer.tick()
        XCTAssertEqual(timer.secondsRemaining, 0)
        XCTAssertFalse(timer.isRunning)
    }

    func testAdjust_extendsTotalAndStopsAtZero() {
        let timer = makeTimer()
        timer.start(30)
        timer.adjust(by: 15)
        XCTAssertEqual(timer.secondsRemaining, 45)
        XCTAssertEqual(timer.totalSeconds, 45)
        timer.adjust(by: -15)
        XCTAssertEqual(timer.secondsRemaining, 30)
        XCTAssertEqual(timer.totalSeconds, 45)

        clock += 10
        timer.tick()
        XCTAssertEqual(timer.secondsRemaining, 20)

        timer.adjust(by: -30)
        XCTAssertFalse(timer.isRunning)
        XCTAssertEqual(timer.secondsRemaining, 0)
    }

    func testAdjustAndStop_doNothingWhenIdle() {
        let timer = makeTimer()
        timer.adjust(by: 15)
        XCTAssertFalse(timer.isRunning)
        XCTAssertEqual(timer.secondsRemaining, 0)
        XCTAssertEqual(timer.restDurationSeconds, RestTimer.defaultRestSeconds)
        XCTAssertTrue(timer.autoStartRest)

        timer.start(90)
        timer.stop()
        XCTAssertFalse(timer.isRunning)
        XCTAssertEqual(timer.secondsRemaining, 0)
    }
}
