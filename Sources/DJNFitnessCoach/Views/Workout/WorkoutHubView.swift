import SwiftUI
import SwiftData

struct WorkoutHubView: View {
    @Environment(\.modelContext) private var modelContext
    @ObservedObject private var planService = WorkoutPlanService.shared
    @State private var showingWorkoutLog = false
    @State private var showingCardioLog = false
    @State private var planSets: [WorkoutSetEntry] = []
    @State private var recentSessions: [DailyLog] = []
    @State private var showingPlanExercises = false

    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.background.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 20) {
                        trainingPlanCard
                        cardioButton
                        recentSessionsList
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 24)
                }
            }
            .navigationTitle("Workout")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(AppColors.background, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .sheet(isPresented: $showingWorkoutLog) {
                WorkoutLogView(planSets: planSets)
            }
            .sheet(isPresented: $showingCardioLog) {
                CardioLogView()
            }
            .sheet(isPresented: $showingPlanExercises) {
                PlanExerciseListView()
            }
        }
        .onAppear { loadRecent() }
    }

    // MARK: - Training Plan Card

    private var trainingPlanCard: some View {
        AppCard {
            VStack(alignment: .leading, spacing: 14) {

                // Header row
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("8-Week Recomposition Plan")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(AppColors.textPrimary)
                        if planService.isActive {
                            Text(planService.weekLabel)
                                .font(.system(size: 12))
                                .foregroundColor(AppColors.purple)
                        } else if planService.hasStarted {
                            Text("Plan complete — ready to evaluate")
                                .font(.system(size: 12))
                                .foregroundColor(AppColors.green)
                        } else {
                            Text("Mar 30 – May 25, 2026")
                                .font(.system(size: 12))
                                .foregroundColor(AppColors.textSecondary)
                        }
                    }
                    Spacer()
                    if planService.isActive {
                        Text("Phase \(planService.currentPhase)")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.black)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(planService.currentPhase == 1 ? AppColors.blue : AppColors.purple)
                            .clipShape(Capsule())
                    }
                }

                // Week progress bar
                if planService.hasStarted {
                    VStack(alignment: .leading, spacing: 5) {
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(AppColors.cardBorder.opacity(0.4))
                                    .frame(height: 6)
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(AppColors.purple)
                                    .frame(width: geo.size.width * planService.weekProgress, height: 6)
                            }
                        }
                        .frame(height: 6)
                        HStack {
                            Text("Week 1")
                            Spacer()
                            Text("Week 8")
                        }
                        .font(.system(size: 9))
                        .foregroundColor(AppColors.textSecondary)
                    }
                }

                // Goal description
                if planService.isActive {
                    Text(planService.phaseGoal)
                        .font(.system(size: 12))
                        .foregroundColor(AppColors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                // Focus targets summary
                HStack(spacing: 8) {
                    focusBadge("Upper Chest", icon: "arrow.up")
                    focusBadge("Rear Delts", icon: "arrow.backward")
                    focusBadge("Lat Sweep", icon: "arrow.left.and.right")
                    focusBadge("Tricep LH", icon: "arm.with.claw")
                }

                Divider().background(AppColors.cardBorder)

                // Action buttons
                HStack(spacing: 10) {
                    Button {
                        planSets = planService.templateSets()
                        showingWorkoutLog = true
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "dumbbell.fill")
                                .font(.system(size: 13, weight: .semibold))
                            Text(planService.isActive ? "Start Session" : "Start Free Session")
                                .font(.system(size: 14, weight: .bold))
                        }
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(AppColors.blue)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    if !planService.hasStarted {
                        Button {
                            planService.startPlan()
                        } label: {
                            Text("Start Plan")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.black)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(AppColors.purple)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    } else {
                        Button { showingPlanExercises = true } label: {
                            Text("View Plan")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(AppColors.textSecondary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(AppColors.cardBorder.opacity(0.3))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                }
            }
        }
    }

    private func focusBadge(_ label: String, icon: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 9))
            Text(label)
                .font(.system(size: 10, weight: .semibold))
        }
        .foregroundColor(AppColors.purple)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(AppColors.purple.opacity(0.12))
        .clipShape(Capsule())
    }

    // MARK: - Cardio Button

    private var cardioButton: some View {
        Button { showingCardioLog = true } label: {
            HStack(spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(AppColors.orange.opacity(0.15))
                        .frame(width: 52, height: 52)
                    Image(systemName: "figure.run")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(AppColors.orange)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text("Cardio Session")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(AppColors.textPrimary)
                    Text("VO2 Max · Norwegian 4×4 · Zone 2")
                        .font(.system(size: 12))
                        .foregroundColor(AppColors.textSecondary)
                }
                Spacer()
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 22))
                    .foregroundColor(AppColors.orange)
            }
            .padding(16)
            .background(AppColors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(AppColors.cardBorder, lineWidth: 0.5))
        }
    }

    // MARK: - Recent Sessions

    private var recentSessionsList: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Recent Sessions")
            if recentSessions.isEmpty {
                Text("No sessions logged yet")
                    .font(.system(size: 14))
                    .foregroundColor(AppColors.textSecondary)
                    .padding(.vertical, 8)
            } else {
                ForEach(recentSessions, id: \.date) { log in
                    sessionRow(log)
                }
            }
        }
    }

    private func sessionRow(_ log: DailyLog) -> some View {
        AppCard(padding: 14) {
            HStack(spacing: 12) {
                if let workout = log.workout, workout.completed {
                    sessionIcon(type: .lifting)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Full Body Lifting")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(AppColors.textPrimary)
                        HStack(spacing: 8) {
                            Text("\(workout.totalSets) sets")
                            Text("·")
                            Text("\(workout.durationMinutes) min")
                            Text("·")
                            Text("RPE \(workout.perceivedExertion)")
                        }
                        .font(.system(size: 12))
                        .foregroundColor(AppColors.textSecondary)
                    }
                } else if let cardio = log.cardio, cardio.completed {
                    sessionIcon(type: cardio.type)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(cardio.type.rawValue)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(AppColors.textPrimary)
                        HStack(spacing: 8) {
                            Text("\(cardio.durationMinutes) min")
                            if let hr = cardio.avgHeartRate {
                                Text("·")
                                Text("~\(hr) bpm avg")
                            }
                            if let dist = cardio.distanceKm {
                                Text("·")
                                Text(String(format: "%.1f km", dist))
                            }
                        }
                        .font(.system(size: 12))
                        .foregroundColor(AppColors.textSecondary)
                    }
                }
                Spacer()
                Text(relativeDate(log.date))
                    .font(.system(size: 11))
                    .foregroundColor(AppColors.textSecondary)
            }
        }
    }

    private func sessionIcon(type: SessionType) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10)
                .fill(AppColors.forSessionType(type).opacity(0.15))
                .frame(width: 40, height: 40)
            Image(systemName: type.icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(AppColors.forSessionType(type))
        }
    }

    private func relativeDate(_ date: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(date) { return "Today" }
        if cal.isDateInYesterday(date) { return "Yesterday" }
        let formatter = DateFormatter()
        formatter.dateFormat = "E d MMM"
        return formatter.string(from: date)
    }

    private func loadRecent() {
        let ds = DataService(modelContext: modelContext)
        recentSessions = ds.fetchRecentLogs(days: 14).filter {
            $0.workout?.completed == true || $0.cardio?.completed == true
        }
    }
}

// MARK: - Plan Exercise List View

struct PlanExerciseListView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var svc = WorkoutPlanService.shared

    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.background.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 0) {
                        // Phase context
                        VStack(alignment: .leading, spacing: 6) {
                            Text(svc.weekLabel)
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(AppColors.purple)
                            Text(svc.phaseGoal)
                                .font(.system(size: 13))
                                .foregroundColor(AppColors.textSecondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(16)
                        .background(AppColors.purple.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                        .padding(.bottom, 16)

                        // Exercise list grouped by muscle
                        ForEach(MuscleGroup.allCases, id: \.self) { muscle in
                            let exercises = WorkoutPlan.exercises.filter { $0.muscleGroup == muscle }
                            if !exercises.isEmpty {
                                exerciseGroup(muscle: muscle, exercises: exercises)
                            }
                        }
                    }
                    .padding(.bottom, 32)
                }
            }
            .navigationTitle("8-Week Plan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(AppColors.background, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .foregroundColor(AppColors.blue)
                }
            }
        }
    }

    private func exerciseGroup(muscle: MuscleGroup, exercises: [PlannedExercise]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Muscle group header
            HStack(spacing: 8) {
                Image(systemName: muscle.icon)
                    .font(.system(size: 12))
                    .foregroundColor(AppColors.blue)
                Text(muscle.rawValue.uppercased())
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(AppColors.blue)
                    .tracking(0.8)
                Text("·")
                    .foregroundColor(AppColors.textSecondary)
                Text("\(exercises.reduce(0) { $0 + $1.setCount }) sets")
                    .font(.system(size: 11))
                    .foregroundColor(AppColors.textSecondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppColors.cardBackground)

            ForEach(exercises, id: \.exerciseName) { ex in
                exerciseRow(ex)
                Divider().background(AppColors.cardBorder).padding(.leading, 16)
            }
        }
        .padding(.bottom, 8)
    }

    private func exerciseRow(_ ex: PlannedExercise) -> some View {
        let phase = svc.currentPhase
        let reps = phase == 1 ? ex.repsPhase1 : ex.repsPhase2
        let fail = phase == 1 ? ex.failurePhase1 : ex.failurePhase2

        return VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(ex.exerciseName)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(AppColors.textPrimary)
                    HStack(spacing: 8) {
                        Text("\(ex.setCount) × \(reps) reps")
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundColor(AppColors.blue)
                        if fail {
                            Text("last set to failure")
                                .font(.system(size: 11))
                                .foregroundColor(AppColors.red)
                        }
                    }
                }
                Spacer()
                // Phase 1 vs 2 rep comparison
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Ph1: \(ex.repsPhase1)r")
                        .font(.system(size: 10))
                        .foregroundColor(phase == 1 ? AppColors.blue : AppColors.textSecondary)
                    Text("Ph2: \(ex.repsPhase2)r")
                        .font(.system(size: 10))
                        .foregroundColor(phase == 2 ? AppColors.purple : AppColors.textSecondary)
                }
            }
            Text(ex.coachNote)
                .font(.system(size: 11))
                .foregroundColor(AppColors.textSecondary)
                .italic()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(AppColors.background)
    }
}
