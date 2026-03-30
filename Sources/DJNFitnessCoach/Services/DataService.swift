import Foundation
import SwiftData

@MainActor
class DataService: ObservableObject {
    private var modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - Daily Log

    func fetchOrCreateTodayLog() -> DailyLog {
        let today = Calendar.current.startOfDay(for: Date())
        let descriptor = FetchDescriptor<DailyLog>(
            predicate: #Predicate { $0.date == today }
        )
        if let existing = try? modelContext.fetch(descriptor).first {
            return existing
        }
        let log = DailyLog(date: today)
        modelContext.insert(log)

        // Auto-create supplement log and detect alternate day
        let supplementLog = SupplementLog(date: today, isAlternateDay: isAlternateDay(for: today))
        modelContext.insert(supplementLog)
        log.supplements = supplementLog

        return log
    }

    func fetchLog(for date: Date) -> DailyLog? {
        let day = Calendar.current.startOfDay(for: date)
        let descriptor = FetchDescriptor<DailyLog>(
            predicate: #Predicate { $0.date == day }
        )
        return try? modelContext.fetch(descriptor).first
    }

    func fetchLogsForCurrentWeek() -> [DailyLog] {
        let calendar = Calendar.current
        guard let weekStart = calendar.dateInterval(of: .weekOfYear, for: Date())?.start else { return [] }
        let weekEnd = calendar.date(byAdding: .day, value: 7, to: weekStart) ?? Date()
        let descriptor = FetchDescriptor<DailyLog>(
            predicate: #Predicate { $0.date >= weekStart && $0.date < weekEnd },
            sortBy: [SortDescriptor(\.date)]
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    func fetchRecentLogs(days: Int = 30) -> [DailyLog] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        let descriptor = FetchDescriptor<DailyLog>(
            predicate: #Predicate { $0.date >= cutoff },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    // MARK: - Workout Session

    func createWorkoutSession(for log: DailyLog) -> WorkoutSession {
        let session = WorkoutSession(date: log.date)
        modelContext.insert(session)
        log.workout = session
        return session
    }

    func addLiftingSet(_ set: LiftingSet, to session: WorkoutSession) {
        modelContext.insert(set)
        session.sets.append(set)
    }

    // MARK: - Cardio Session

    func createCardioSession(type: SessionType, for log: DailyLog) -> CardioSession {
        let session = CardioSession(date: log.date, type: type)
        modelContext.insert(session)
        log.cardio = session
        return session
    }

    // MARK: - Nutrition Log

    func fetchOrCreateNutritionLog(for log: DailyLog) -> NutritionLog {
        if let existing = log.nutrition { return existing }
        let nutrition = NutritionLog(date: log.date)
        modelContext.insert(nutrition)
        log.nutrition = nutrition
        return nutrition
    }

    // MARK: - Recovery Log

    func fetchOrCreateRecoveryLog(for log: DailyLog) -> RecoveryLog {
        if let existing = log.recovery { return existing }
        let recovery = RecoveryLog(date: log.date)
        modelContext.insert(recovery)
        log.recovery = recovery
        return recovery
    }

    // MARK: - Body Metrics

    func saveBodyMetric(weightKg: Double, bodyFat: Double?) {
        let today = Calendar.current.startOfDay(for: Date())
        let descriptor = FetchDescriptor<BodyMetric>(
            predicate: #Predicate { $0.date == today }
        )
        if let existing = try? modelContext.fetch(descriptor).first {
            existing.weightKg = weightKg
            existing.bodyFatPercent = bodyFat
        } else {
            let metric = BodyMetric(date: today, weightKg: weightKg, bodyFatPercent: bodyFat)
            modelContext.insert(metric)
        }
    }

    func fetchBodyMetrics(days: Int = 90) -> [BodyMetric] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        let descriptor = FetchDescriptor<BodyMetric>(
            predicate: #Predicate { $0.date >= cutoff },
            sortBy: [SortDescriptor(\.date)]
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    // MARK: - Rule Engine

    func buildTodayRecommendation() -> RuleEngine.SessionRecommendation {
        let weekLogs = fetchLogsForCurrentWeek()
        let counters = RuleEngine.buildWeeklyCounters(from: weekLogs)
        let recentLogs = fetchRecentLogs(days: 3)
        let previousSession = recentLogs.dropFirst().first   // yesterday

        let previousType: SessionType? = {
            if previousSession?.workout?.completed == true { return .lifting }
            if let c = previousSession?.cardio, c.completed { return c.type }
            return nil
        }()

        let todayLog = fetchOrCreateTodayLog()
        let recovery = todayLog.recovery

        return RuleEngine.recommend(
            previousSessionType: previousType,
            recovery: recovery,
            weeklyCounters: counters,
            lastMealTime: todayLog.nutrition?.firstMealTime,
            workoutEndTime: todayLog.workout?.date
        )
    }

    // MARK: - Exercise History

    /// Returns up to `limit` past sessions containing sets for `exerciseName`, newest first.
    func fetchExerciseSessions(exerciseName: String, limit: Int = 20) -> [(date: Date, sets: [LiftingSet])] {
        let descriptor = FetchDescriptor<WorkoutSession>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        let allSessions = (try? modelContext.fetch(descriptor)) ?? []
        var results: [(date: Date, sets: [LiftingSet])] = []
        for session in allSessions {
            let matching = session.sets
                .filter { $0.exerciseName == exerciseName }
                .sorted { $0.setNumber < $1.setNumber }
            guard !matching.isEmpty else { continue }
            results.append((session.date, matching))
            if results.count >= limit { break }
        }
        return results
    }

    // MARK: - Helpers

    private func isAlternateDay(for date: Date) -> Bool {
        // Day 0 = even, Day 1 = odd; alternate day supplements on odd days
        let dayOfYear = Calendar.current.ordinality(of: .day, in: .year, for: date) ?? 0
        return dayOfYear % 2 != 0
    }

    func save() {
        try? modelContext.save()
    }
}
