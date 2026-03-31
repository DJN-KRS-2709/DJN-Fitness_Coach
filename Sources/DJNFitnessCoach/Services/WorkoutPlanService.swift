import Foundation
import Combine

final class WorkoutPlanService: ObservableObject {
    static let shared = WorkoutPlanService()

    @Published private(set) var startDate: Date?

    private let startKey = "djn_plan_start_date"

    private init() {
        startDate = UserDefaults.standard.object(forKey: startKey) as? Date
    }

    func startPlan(from date: Date = Date()) {
        let day = Calendar.current.startOfDay(for: date)
        UserDefaults.standard.set(day, forKey: startKey)
        startDate = day
    }

    func resetPlan() {
        UserDefaults.standard.removeObject(forKey: startKey)
        startDate = nil
    }

    /// 1-based week number within the plan, or nil if plan hasn't started or has ended.
    var currentWeekNumber: Int? {
        guard let start = startDate else { return nil }
        let today = Calendar.current.startOfDay(for: Date())
        let days = Calendar.current.dateComponents([.day], from: start, to: today).day ?? 0
        let week = (days / 7) + 1
        return week <= WorkoutPlan.totalWeeks ? week : nil
    }

    var currentPhase: Int {
        guard let week = currentWeekNumber else { return 1 }
        return week <= 4 ? 1 : 2
    }

    var isActive: Bool { currentWeekNumber != nil }

    var hasStarted: Bool { startDate != nil }

    var phaseName: String { WorkoutPlan.phaseName[currentPhase] ?? "Foundation" }
    var phaseGoal: String { WorkoutPlan.phaseGoal[currentPhase] ?? "" }

    /// Friendly label: "Week 3, Phase 1 — Foundation"
    var weekLabel: String {
        guard let week = currentWeekNumber else {
            return hasStarted ? "Plan Complete" : "Not Started"
        }
        return "Week \(week) of \(WorkoutPlan.totalWeeks) · Phase \(currentPhase): \(phaseName)"
    }

    /// Progress 0.0 – 1.0
    var weekProgress: Double {
        guard let week = currentWeekNumber else { return hasStarted ? 1.0 : 0.0 }
        return Double(week) / Double(WorkoutPlan.totalWeeks)
    }

    /// Generates a pre-populated set list for the current phase.
    func templateSets() -> [WorkoutSetEntry] {
        let phase = currentPhase
        let ws = LastWeightsStore.shared
        var entries: [WorkoutSetEntry] = []
        for exercise in WorkoutPlan.exercises {
            let reps   = phase == 1 ? exercise.repsPhase1   : exercise.repsPhase2
            let fail   = phase == 1 ? exercise.failurePhase1 : exercise.failurePhase2
            let rpe    = phase == 1 ? 8 : 9
            for i in 0..<exercise.setCount {
                let setNumber = i + 1
                let isLast    = i == exercise.setCount - 1
                let lastWeight = ws.weight(for: exercise.exerciseName, setNumber: setNumber)
                entries.append(WorkoutSetEntry(
                    muscleGroup: exercise.muscleGroup,
                    exerciseName: exercise.exerciseName,
                    setNumber: setNumber,
                    reps: reps,
                    weight: lastWeight,
                    toFailure: isLast && fail,
                    rpe: rpe
                ))
            }
        }
        return entries
    }
}
