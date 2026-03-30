import SwiftUI
import SwiftData

// Weight options in 2.5 kg increments (0 = bodyweight)
private let kWeightOptions: [Double] = [0] + (1...200).map { Double($0) }

struct WorkoutLogView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    /// If provided, the log opens with these sets pre-loaded from the training plan.
    var planSets: [WorkoutSetEntry] = []

    @State private var durationMinutes: Int = 60
    @State private var rpe: Int = 8
    @State private var notes: String = ""
    @State private var sets: [WorkoutSetEntry] = []
    @State private var historyTarget: ExerciseHistoryTarget?

    // Groups by exercise name, preserving the original order
    private var groupedByExercise: [(exerciseName: String, muscle: MuscleGroup, indices: [Int])] {
        var result: [(exerciseName: String, muscle: MuscleGroup, indices: [Int])] = []
        var positionOf: [String: Int] = [:]
        for (idx, set) in sets.enumerated() {
            if let pos = positionOf[set.exerciseName] {
                result[pos].indices.append(idx)
            } else {
                positionOf[set.exerciseName] = result.count
                result.append((set.exerciseName, set.muscleGroup, [idx]))
            }
        }
        return result
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.background.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 16) {
                        if !planSets.isEmpty { planContextBanner }
                        sessionMetaCard
                        volumeProgressCard
                        if !sets.isEmpty { editableSetsCard }
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
            .sheet(item: $historyTarget) { target in
                ExerciseHistoryView(target: target)
            }
        }
        .onAppear {
            if sets.isEmpty && !planSets.isEmpty { sets = planSets }
        }
    }

    // MARK: - Plan Context Banner

    private var planContextBanner: some View {
        let svc = WorkoutPlanService.shared
        return HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(AppColors.purple.opacity(0.15))
                    .frame(width: 40, height: 40)
                Image(systemName: "chart.bar.fill")
                    .font(.system(size: 16))
                    .foregroundColor(AppColors.purple)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(svc.weekLabel)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(AppColors.purple)
                Text(svc.phaseGoal)
                    .font(.system(size: 11))
                    .foregroundColor(AppColors.textSecondary)
                    .lineLimit(2)
            }
            Spacer()
        }
        .padding(14)
        .background(AppColors.purple.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(AppColors.purple.opacity(0.25), lineWidth: 0.5))
    }

    // MARK: - Session Meta

    private var sessionMetaCard: some View {
        AppCard {
            VStack(spacing: 14) {
                SectionHeader(title: "Session Info")
                HStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Duration").font(.system(size: 12)).foregroundColor(AppColors.textSecondary)
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
                        Text("RPE").font(.system(size: 12)).foregroundColor(AppColors.textSecondary)
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
        default:    return AppColors.red
        }
    }

    // MARK: - Volume Progress Card

    private var volumeProgressCard: some View {
        AppCard {
            VStack(alignment: .leading, spacing: 10) {
                SectionHeader(title: "Sets Logged", subtitle: "vs plan target")
                HStack(spacing: 0) {
                    ForEach(MuscleGroup.allCases.filter { $0.defaultSets > 0 }, id: \.self) { muscle in
                        let logged = sets.filter { $0.muscleGroup == muscle }.count
                        let target = muscle.defaultSets
                        VStack(spacing: 3) {
                            Text("\(logged)/\(target)")
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                                .foregroundColor(setCountColor(logged: logged, target: target))
                            Text(muscle.rawValue.prefix(3).uppercased())
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundColor(AppColors.textSecondary)
                                .tracking(0.5)
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

    // MARK: - Editable Sets Card

    private var editableSetsCard: some View {
        AppCard(padding: 0) {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    SectionHeader(title: "Sets")
                    Spacer()
                    Text("\(sets.count) total")
                        .font(.system(size: 12))
                        .foregroundColor(AppColors.textSecondary)
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 12)

                ForEach(groupedByExercise, id: \.exerciseName) { group in
                    exerciseGroup(group)
                }
            }
        }
    }

    private func exerciseGroup(_ group: (exerciseName: String, muscle: MuscleGroup, indices: [Int])) -> some View {
        let color = muscleColor(group.muscle)
        return VStack(alignment: .leading, spacing: 0) {
            // Exercise header (tap to view history)
            Button {
                historyTarget = ExerciseHistoryTarget(
                    exerciseName: group.exerciseName,
                    muscle: group.muscle
                )
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: group.muscle.icon)
                        .font(.system(size: 11))
                        .foregroundColor(color)
                    Text(group.exerciseName)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(AppColors.textPrimary)
                    Spacer()
                    Text(group.muscle.rawValue.uppercased())
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(color)
                        .tracking(0.5)
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.system(size: 11))
                        .foregroundColor(color.opacity(0.6))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(color.opacity(0.08))
            }
            .buttonStyle(.plain)

            // Set rows
            ForEach(Array(group.indices.enumerated()), id: \.offset) { localIdx, globalIdx in
                if globalIdx < sets.count {
                    editableSetRow(
                        setNumber: localIdx + 1,
                        binding: $sets[globalIdx],
                        globalIdx: globalIdx
                    )
                    if localIdx < group.indices.count - 1 {
                        Divider().background(AppColors.cardBorder).padding(.leading, 16)
                    }
                }
            }

            Divider().background(AppColors.cardBorder.opacity(0.5))
        }
    }

    private func editableSetRow(setNumber: Int, binding: Binding<WorkoutSetEntry>, globalIdx: Int) -> some View {
        HStack(spacing: 0) {
            // Set number badge
            Text("S\(setNumber)")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(AppColors.textSecondary)
                .frame(width: 28)

            Divider().frame(height: 36).background(AppColors.cardBorder).padding(.horizontal, 6)

            // Weight wheel
            VStack(spacing: 0) {
                Picker("", selection: binding.weight) {
                    ForEach(kWeightOptions, id: \.self) { w in
                        Text(w == 0 ? "BW" : String(format: "%.1f", w))
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .tag(w)
                    }
                }
                .pickerStyle(.wheel)
                .frame(width: 76, height: 72)
                .clipped()
                Text("kg")
                    .font(.system(size: 9))
                    .foregroundColor(AppColors.textSecondary)
            }

            Text("×")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(AppColors.textSecondary)
                .padding(.horizontal, 8)

            // Rep stepper
            HStack(spacing: 6) {
                Button {
                    if binding.wrappedValue.reps > 1 { binding.reps.wrappedValue -= 1 }
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.system(size: 18))
                        .foregroundColor(AppColors.textSecondary)
                }

                VStack(spacing: 1) {
                    Text("\(binding.wrappedValue.reps)")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(AppColors.textPrimary)
                        .frame(minWidth: 28)
                    Text("reps")
                        .font(.system(size: 9))
                        .foregroundColor(AppColors.textSecondary)
                }

                Button {
                    binding.reps.wrappedValue += 1
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 18))
                        .foregroundColor(AppColors.blue)
                }
            }

            Spacer()

            // Failure badge (tap to toggle)
            Button {
                binding.toFailure.wrappedValue.toggle()
            } label: {
                Text("F")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(binding.wrappedValue.toFailure ? .black : AppColors.textSecondary)
                    .frame(width: 24, height: 24)
                    .background(binding.wrappedValue.toFailure ? AppColors.red : AppColors.cardBorder.opacity(0.4))
                    .clipShape(Circle())
            }
            .padding(.trailing, 8)

            // Delete
            Button {
                let idx: Int = globalIdx
                withAnimation { sets.remove(at: idx) }
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 13))
                    .foregroundColor(AppColors.textSecondary.opacity(0.5))
            }
            .padding(.trailing, 14)
        }
        .padding(.vertical, 10)
        .padding(.leading, 6)
        .contentShape(Rectangle())
    }

    private func muscleColor(_ muscle: MuscleGroup) -> Color {
        switch muscle {
        case .chest:     return AppColors.blue
        case .back:      return AppColors.teal
        case .shoulders: return AppColors.orange
        case .arms:      return AppColors.purple
        case .legs:      return AppColors.green
        case .core:      return AppColors.yellow
        }
    }

    // MARK: - Add Set

    private var addSetSection: some View { AddSetCard(sets: $sets) }

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
    @Binding var sets: [WorkoutSetEntry]
    @State private var muscle: MuscleGroup = .chest
    @State private var exercise: String = ""
    @State private var reps: Int = 10
    @State private var weight: Double = 0
    @State private var toFailure: Bool = false
    @State private var rpe: Int = 8

    private let defaultExercises: [MuscleGroup: [String]] = [
        .chest:     ["Incline Barbell Press", "Low-to-High Cable Fly", "Flat DB Press", "Bench Press", "Cable Fly", "Push-Up"],
        .back:      ["Weighted Pull-Up", "Cable Pullover", "Cable Row (Close Grip)", "Lat Pulldown", "Barbell Row", "Face Pull"],
        .shoulders: ["DB Overhead Press", "DB Lateral Raise", "Rear Delt Cable Fly", "Cable Lateral", "Arnold Press"],
        .arms:      ["Barbell Curl", "Overhead Tricep Extension", "Tricep Rope Pushdown", "Hammer Curl", "Skull Crusher", "Dip"],
        .legs:      ["Romanian Deadlift", "Leg Press", "Squat", "Leg Curl", "Calf Raise"],
        .core:      ["Plank", "Ab Wheel", "Hanging Leg Raise", "Cable Crunch"]
    ]

    private var setNumberForCurrentGroup: Int {
        sets.filter { $0.muscleGroup == muscle }.count + 1
    }

    var body: some View {
        AppCard {
            VStack(alignment: .leading, spacing: 14) {
                SectionHeader(title: "Add Set")

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
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Reps").font(.system(size: 11)).foregroundColor(AppColors.textSecondary)
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

                    VStack(alignment: .leading, spacing: 0) {
                        Text("Weight (kg)").font(.system(size: 11)).foregroundColor(AppColors.textSecondary)
                        Picker("", selection: $weight) {
                            ForEach(kWeightOptions, id: \.self) { w in
                                Text(w == 0 ? "BW" : String(format: "%.1f", w))
                                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                                    .tag(w)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(width: 100, height: 100)
                        .clipped()
                    }

                    Spacer()

                    VStack(alignment: .center, spacing: 4) {
                        Text("Failure").font(.system(size: 11)).foregroundColor(AppColors.textSecondary)
                        Toggle("", isOn: $toFailure).labelsHidden().tint(AppColors.red)
                    }
                }

                Button {
                    guard !exercise.isEmpty else { return }
                    sets.append(WorkoutSetEntry(
                        muscleGroup: muscle,
                        exerciseName: exercise,
                        setNumber: setNumberForCurrentGroup,
                        reps: reps,
                        weight: weight,
                        toFailure: toFailure,
                        rpe: rpe
                    ))
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
