import SwiftUI
import SwiftData

struct WorkoutLogView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var session: WorkoutSession?
    @State private var durationMinutes: Int = 60
    @State private var rpe: Int = 8
    @State private var notes: String = ""
    @State private var sets: [SetEntry] = []
    @State private var showingAddSet = false
    @State private var selectedMuscle: MuscleGroup = .chest
    @State private var isSaved = false

    struct SetEntry: Identifiable {
        let id = UUID()
        var muscleGroup: MuscleGroup
        var exerciseName: String
        var setNumber: Int
        var reps: Int
        var weight: Double
        var toFailure: Bool
        var rpe: Int
    }

    private var groupedSets: [(MuscleGroup, [SetEntry])] {
        MuscleGroup.allCases.compactMap { muscle in
            let s = sets.filter { $0.muscleGroup == muscle }
            return s.isEmpty ? nil : (muscle, s)
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.background.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 20) {
                        sessionMetaCard
                        volumeTemplateCard
                        if !sets.isEmpty {
                            loggedSetsCard
                        }
                        addSetSection
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 100)
                }
            }
            .navigationTitle("Log Lifting Session")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(AppColors.background, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(AppColors.textSecondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveSession() }
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(AppColors.blue)
                }
            }
        }
    }

    // MARK: - Session Meta

    private var sessionMetaCard: some View {
        AppCard {
            VStack(spacing: 14) {
                SectionHeader(title: "Session Info")
                HStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Duration")
                            .font(.system(size: 12))
                            .foregroundColor(AppColors.textSecondary)
                        HStack {
                            Button { if durationMinutes > 15 { durationMinutes -= 5 } } label: {
                                Image(systemName: "minus.circle.fill").foregroundColor(AppColors.textSecondary)
                            }
                            Text("\(durationMinutes) min")
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                                .foregroundColor(AppColors.textPrimary)
                                .frame(width: 70, alignment: .center)
                            Button { durationMinutes += 5 } label: {
                                Image(systemName: "plus.circle.fill").foregroundColor(AppColors.blue)
                            }
                        }
                    }
                    Spacer()
                    VStack(alignment: .leading, spacing: 6) {
                        Text("RPE")
                            .font(.system(size: 12))
                            .foregroundColor(AppColors.textSecondary)
                        HStack {
                            Button { if rpe > 1 { rpe -= 1 } } label: {
                                Image(systemName: "minus.circle.fill").foregroundColor(AppColors.textSecondary)
                            }
                            Text("\(rpe)/10")
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                                .foregroundColor(rpeColor)
                                .frame(width: 50, alignment: .center)
                            Button { if rpe < 10 { rpe += 1 } } label: {
                                Image(systemName: "plus.circle.fill").foregroundColor(AppColors.blue)
                            }
                        }
                    }
                }

                TextField("Notes (optional)", text: $notes, axis: .vertical)
                    .font(.system(size: 14))
                    .foregroundColor(AppColors.textPrimary)
                    .lineLimit(2...4)
            }
        }
    }

    private var rpeColor: Color {
        switch rpe {
        case 1...5: return AppColors.green
        case 6...7: return AppColors.yellow
        case 8...9: return AppColors.orange
        default: return AppColors.red
        }
    }

    // MARK: - Volume Template

    private var volumeTemplateCard: some View {
        AppCard {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(title: "Target Volume", subtitle: "Your default per session")
                HStack(spacing: 0) {
                    ForEach(MuscleGroup.allCases.filter { $0.defaultSets > 0 }, id: \.self) { muscle in
                        VStack(spacing: 4) {
                            Text("\(muscle.defaultSets)")
                                .font(.system(size: 18, weight: .bold, design: .rounded))
                                .foregroundColor(setCountColor(logged: sets.filter { $0.muscleGroup == muscle }.count, target: muscle.defaultSets))
                            Text(muscle.rawValue.prefix(3).uppercased())
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundColor(AppColors.textSecondary)
                                .tracking(0.5)
                            let logged = sets.filter { $0.muscleGroup == muscle }.count
                            if logged > 0 {
                                Text("\(logged) done")
                                    .font(.system(size: 8))
                                    .foregroundColor(AppColors.green)
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }
        }
    }

    private func setCountColor(logged: Int, target: Int) -> Color {
        if logged == 0 { return AppColors.textSecondary }
        if logged >= target { return AppColors.green }
        return AppColors.orange
    }

    // MARK: - Logged Sets

    private var loggedSetsCard: some View {
        AppCard(padding: 0) {
            VStack(alignment: .leading, spacing: 0) {
                SectionHeader(title: "Logged Sets")
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 10)

                ForEach(groupedSets, id: \.0) { muscle, entries in
                    VStack(alignment: .leading, spacing: 0) {
                        HStack {
                            Image(systemName: muscle.icon)
                                .font(.system(size: 12))
                                .foregroundColor(AppColors.blue)
                            Text(muscle.rawValue)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(AppColors.blue)
                                .textCase(.uppercase)
                                .tracking(0.6)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 6)
                        .background(AppColors.blue.opacity(0.08))

                        ForEach(entries) { entry in
                            HStack {
                                Text("Set \(entry.setNumber)")
                                    .font(.system(size: 12))
                                    .foregroundColor(AppColors.textSecondary)
                                    .frame(width: 40)
                                Text(entry.exerciseName)
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(AppColors.textPrimary)
                                    .lineLimit(1)
                                Spacer()
                                if entry.weight > 0 {
                                    Text("\(String(format: "%.1f", entry.weight)) kg × \(entry.reps)")
                                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                                        .foregroundColor(AppColors.textPrimary)
                                } else {
                                    Text("\(entry.reps) reps")
                                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                                        .foregroundColor(AppColors.textPrimary)
                                }
                                if entry.toFailure {
                                    Text("F")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundColor(.black)
                                        .frame(width: 18, height: 18)
                                        .background(AppColors.red)
                                        .clipShape(Circle())
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            Divider().background(AppColors.cardBorder).padding(.leading, 16)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Add Set

    private var addSetSection: some View {
        AddSetCard(sets: $sets)
    }

    // MARK: - Save

    private func saveSession() {
        let ds = DataService(modelContext: modelContext)
        let todayLog = ds.fetchOrCreateTodayLog()
        let session = ds.createWorkoutSession(for: todayLog)
        session.durationMinutes = durationMinutes
        session.perceivedExertion = rpe
        session.notes = notes
        session.completed = true

        for entry in sets {
            let set = LiftingSet(
                muscleGroup: entry.muscleGroup,
                exerciseName: entry.exerciseName,
                setNumber: entry.setNumber,
                reps: entry.reps,
                weight: entry.weight,
                toFailure: entry.toFailure,
                rpe: entry.rpe
            )
            ds.addLiftingSet(set, to: session)
        }
        todayLog.sessionType = .lifting
        ds.save()
        dismiss()
    }
}

// MARK: - Add Set Card

struct AddSetCard: View {
    @Binding var sets: [WorkoutLogView.SetEntry]
    @State private var muscle: MuscleGroup = .chest
    @State private var exercise: String = ""
    @State private var reps: Int = 10
    @State private var weight: Double = 0
    @State private var toFailure: Bool = false
    @State private var rpe: Int = 8

    private let defaultExercises: [MuscleGroup: [String]] = [
        .chest: ["Bench Press", "Incline Bench", "Cable Fly", "Dumbbell Press", "Push-Up"],
        .back: ["Pull-Up", "Barbell Row", "Cable Row", "Lat Pulldown", "Face Pull"],
        .shoulders: ["Overhead Press", "Lateral Raise", "Cable Lateral", "Rear Delt Fly"],
        .arms: ["Barbell Curl", "Tricep Pushdown", "Hammer Curl", "Skull Crusher", "Dip"],
        .legs: ["Squat", "Romanian Deadlift", "Leg Press", "Leg Curl", "Calf Raise"],
        .core: ["Plank", "Ab Wheel", "Hanging Leg Raise", "Cable Crunch"]
    ]

    private var setNumberForCurrentGroup: Int {
        sets.filter { $0.muscleGroup == muscle }.count + 1
    }

    var body: some View {
        AppCard {
            VStack(alignment: .leading, spacing: 14) {
                SectionHeader(title: "Add Set")

                // Muscle picker
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(MuscleGroup.allCases, id: \.self) { m in
                            Button {
                                muscle = m
                                exercise = ""
                            } label: {
                                Text(m.rawValue)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(muscle == m ? .black : AppColors.textSecondary)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(muscle == m ? AppColors.blue : AppColors.cardBorder.opacity(0.3))
                                    .clipShape(Capsule())
                            }
                        }
                    }
                }

                // Exercise suggestions
                if exercise.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(defaultExercises[muscle] ?? [], id: \.self) { ex in
                                Button { exercise = ex } label: {
                                    Text(ex)
                                        .font(.system(size: 12))
                                        .foregroundColor(AppColors.textSecondary)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 5)
                                        .background(AppColors.cardBorder.opacity(0.2))
                                        .clipShape(Capsule())
                                }
                            }
                        }
                    }
                }

                TextField("Exercise name", text: $exercise)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(AppColors.textPrimary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(AppColors.cardBorder.opacity(0.2))
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                HStack(spacing: 16) {
                    // Reps
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Reps")
                            .font(.system(size: 11))
                            .foregroundColor(AppColors.textSecondary)
                        HStack(spacing: 8) {
                            Button { if reps > 1 { reps -= 1 } } label: {
                                Image(systemName: "minus.circle.fill").foregroundColor(AppColors.textSecondary)
                            }
                            Text("\(reps)")
                                .font(.system(size: 18, weight: .bold, design: .rounded))
                                .foregroundColor(AppColors.textPrimary)
                                .frame(width: 36, alignment: .center)
                            Button { reps += 1 } label: {
                                Image(systemName: "plus.circle.fill").foregroundColor(AppColors.blue)
                            }
                        }
                    }

                    // Weight
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Weight (kg)")
                            .font(.system(size: 11))
                            .foregroundColor(AppColors.textSecondary)
                        HStack(spacing: 8) {
                            Button { if weight >= 2.5 { weight -= 2.5 } } label: {
                                Image(systemName: "minus.circle.fill").foregroundColor(AppColors.textSecondary)
                            }
                            Text(weight == 0 ? "BW" : String(format: "%.1f", weight))
                                .font(.system(size: 18, weight: .bold, design: .rounded))
                                .foregroundColor(AppColors.textPrimary)
                                .frame(width: 52, alignment: .center)
                            Button { weight += 2.5 } label: {
                                Image(systemName: "plus.circle.fill").foregroundColor(AppColors.blue)
                            }
                        }
                    }

                    Spacer()

                    // To Failure toggle
                    VStack(alignment: .center, spacing: 4) {
                        Text("Failure")
                            .font(.system(size: 11))
                            .foregroundColor(AppColors.textSecondary)
                        Toggle("", isOn: $toFailure)
                            .labelsHidden()
                            .tint(AppColors.red)
                    }
                }

                Button {
                    guard !exercise.isEmpty else { return }
                    let entry = WorkoutLogView.SetEntry(
                        muscleGroup: muscle,
                        exerciseName: exercise,
                        setNumber: setNumberForCurrentGroup,
                        reps: reps,
                        weight: weight,
                        toFailure: toFailure,
                        rpe: rpe
                    )
                    sets.append(entry)
                    // Reset for next set
                    reps = 10
                    toFailure = false
                } label: {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("Add Set")
                    }
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(exercise.isEmpty ? AppColors.textSecondary.opacity(0.3) : AppColors.blue)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(exercise.isEmpty)
            }
        }
    }
}
