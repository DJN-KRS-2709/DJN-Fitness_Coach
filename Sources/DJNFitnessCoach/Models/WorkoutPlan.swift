import Foundation

// MARK: - Workout Set Entry (top-level, shared between plan & log view)

struct WorkoutSetEntry: Identifiable {
    let id = UUID()
    var muscleGroup: MuscleGroup
    var exerciseName: String
    var setNumber: Int
    var reps: Int
    var weight: Double   // kg; 0 = bodyweight
    var toFailure: Bool
    var rpe: Int
}

// MARK: - Planned Exercise Definition

struct PlannedExercise {
    let muscleGroup: MuscleGroup
    let exerciseName: String
    let setCount: Int
    let repsPhase1: Int       // Weeks 1-4
    let repsPhase2: Int       // Weeks 5-8
    let failurePhase1: Bool   // last set to failure in Phase 1
    let failurePhase2: Bool   // last set to failure in Phase 2
    let coachNote: String
}

// MARK: - 8-Week Plan

enum WorkoutPlan {

    static let totalWeeks = 8

    static let phaseName: [Int: String] = [
        1: "Foundation",
        2: "Intensification"
    ]

    static let phaseGoal: [Int: String] = [
        1: "Build mind-muscle on weak areas · 10–15 reps · controlled eccentric",
        2: "Progressive overload · 6–10 reps · failure on main compounds"
    ]

    // Ordered as performed in session
    static let exercises: [PlannedExercise] = [

        // ─── CHEST (5 sets) — upper chest priority ───────────────────────
        PlannedExercise(
            muscleGroup: .chest,
            exerciseName: "Incline Barbell Press",
            setCount: 3,
            repsPhase1: 12, repsPhase2: 8,
            failurePhase1: true, failurePhase2: true,
            coachNote: "30–45° incline · slow negative · upper-chest priority · add 2.5 kg when you hit top rep range"
        ),
        PlannedExercise(
            muscleGroup: .chest,
            exerciseName: "Low-to-High Cable Fly",
            setCount: 1,
            repsPhase1: 15, repsPhase2: 12,
            failurePhase1: false, failurePhase2: true,
            coachNote: "High anchor · maximum stretch at bottom · squeeze hard at top"
        ),
        PlannedExercise(
            muscleGroup: .chest,
            exerciseName: "Flat DB Press",
            setCount: 1,
            repsPhase1: 12, repsPhase2: 8,
            failurePhase1: false, failurePhase2: true,
            coachNote: "Mid-chest complement · full ROM with DBs"
        ),

        // ─── BACK (4 sets) — lat sweep focus ─────────────────────────────
        PlannedExercise(
            muscleGroup: .back,
            exerciseName: "Weighted Pull-Up",
            setCount: 2,
            repsPhase1: 8, repsPhase2: 6,
            failurePhase1: false, failurePhase2: true,
            coachNote: "Dead hang start · lat-initiated pull · slight backward lean at top"
        ),
        PlannedExercise(
            muscleGroup: .back,
            exerciseName: "Cable Pullover",
            setCount: 1,
            repsPhase1: 15, repsPhase2: 12,
            failurePhase1: false, failurePhase2: true,
            coachNote: "Arms straight · load the lower lat sweep · maximise stretch"
        ),
        PlannedExercise(
            muscleGroup: .back,
            exerciseName: "Cable Row (Close Grip)",
            setCount: 1,
            repsPhase1: 10, repsPhase2: 8,
            failurePhase1: true, failurePhase2: true,
            coachNote: "Back thickness · full stretch at extension · don't round"
        ),

        // ─── SHOULDERS (4 sets) — rear delt priority ─────────────────────
        PlannedExercise(
            muscleGroup: .shoulders,
            exerciseName: "DB Overhead Press",
            setCount: 1,
            repsPhase1: 12, repsPhase2: 8,
            failurePhase1: false, failurePhase2: true,
            coachNote: "Full ROM · don't flare elbows"
        ),
        PlannedExercise(
            muscleGroup: .shoulders,
            exerciseName: "DB Lateral Raise",
            setCount: 1,
            repsPhase1: 15, repsPhase2: 12,
            failurePhase1: false, failurePhase2: false,
            coachNote: "Slight forward lean · thumb slightly down · control the drop"
        ),
        PlannedExercise(
            muscleGroup: .shoulders,
            exerciseName: "Rear Delt Cable Fly",
            setCount: 2,
            repsPhase1: 15, repsPhase2: 12,
            failurePhase1: false, failurePhase2: false,
            coachNote: "DEDICATED rear delt — cables crossed · never to failure · squeeze 1 sec at peak"
        ),

        // ─── ARMS (3 sets) — tricep long head priority ───────────────────
        PlannedExercise(
            muscleGroup: .arms,
            exerciseName: "Barbell Curl",
            setCount: 1,
            repsPhase1: 10, repsPhase2: 8,
            failurePhase1: true, failurePhase2: true,
            coachNote: "Full ROM · no momentum · supinate at top"
        ),
        PlannedExercise(
            muscleGroup: .arms,
            exerciseName: "Overhead Tricep Extension",
            setCount: 1,
            repsPhase1: 12, repsPhase2: 8,
            failurePhase1: false, failurePhase2: true,
            coachNote: "EZ bar or DB · long head priority · crucial for rear-view arm size"
        ),
        PlannedExercise(
            muscleGroup: .arms,
            exerciseName: "Tricep Rope Pushdown",
            setCount: 1,
            repsPhase1: 15, repsPhase2: 12,
            failurePhase1: true, failurePhase2: true,
            coachNote: "Split the rope at bottom · squeeze laterally"
        ),

        // ─── LEGS (2 sets) ────────────────────────────────────────────────
        PlannedExercise(
            muscleGroup: .legs,
            exerciseName: "Romanian Deadlift",
            setCount: 1,
            repsPhase1: 10, repsPhase2: 8,
            failurePhase1: false, failurePhase2: true,
            coachNote: "Hip hinge · feel hamstring stretch at bottom · controlled"
        ),
        PlannedExercise(
            muscleGroup: .legs,
            exerciseName: "Leg Press",
            setCount: 1,
            repsPhase1: 12, repsPhase2: 10,
            failurePhase1: true, failurePhase2: true,
            coachNote: "Full depth · don't lock out at top"
        )
    ]
}
