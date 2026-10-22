import SwiftUI

@main
struct RepTrackApp: App {
    @State private var workoutViewModel: WorkoutViewModel
    @State private var progressViewModel: ProgressViewModel

    init() {
        Appearance.configure()
        let store = DataStore.makeDefault()
        _workoutViewModel = State(initialValue: WorkoutViewModel(store: store))
        _progressViewModel = State(initialValue: ProgressViewModel(store: store))
    }

    var body: some Scene {
        WindowGroup {
            RootView(workoutViewModel: workoutViewModel, progressViewModel: progressViewModel)
                .preferredColorScheme(.dark)
                .tint(Palette.lime)
        }
    }
}

/// Two screens: the tracker, and the progress report pushed on top of it.
struct RootView: View {
    let workoutViewModel: WorkoutViewModel
    let progressViewModel: ProgressViewModel

    @State private var showProgress = false

    var body: some View {
        NavigationStack {
            WorkoutTrackerScreen(viewModel: workoutViewModel) { showProgress = true }
                .toolbar(.hidden, for: .navigationBar)
                .navigationDestination(isPresented: $showProgress) {
                    ProgressScreen(viewModel: progressViewModel)
                }
        }
        .background(Palette.background.ignoresSafeArea())
    }
}
