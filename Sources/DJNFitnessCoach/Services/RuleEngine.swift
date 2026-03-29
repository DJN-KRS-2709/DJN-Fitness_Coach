import Foundation
import SwiftData

/// The core rule engine that determines session recommendations, adjusts volume,
/// selects cardio type, and flags nutrition actions.
struct RuleEngine {

    // MARK: - Weekly Counters

    struct WeeklyCounters {
        var liftingDone: Int = 0
        var vo2Done: Int = 0
        var norwegianDone: Int = 0
        var zone2Done: Int = 0

        var totalHighIntensityCardio: Int { vo2Done + norwegianDone }
    }

    // MARK: - Session Recommendation

    struct SessionRecommendation {
        let sessionType: SessionType
        let reason: String
        let volumeModifier: Double       // 1.0 = normal, 0.8 = -20%, etc.
        let allowFailureSets: Bool
        let cardioNotes: [String]
        let nutritionAlerts: [String]
    }

    static func recommend(
        previousSessionType: SessionType?,
        recovery: RecoveryLog?,
        weeklyCounters: WeeklyCounters,
        lastMealTime: Date?,
        workoutEndTime: Date?
    ) -> SessionRecommendation {

        let recoveryState = recovery?.recoveryState ?? .high
        let isLiftingDay = shouldLift(previous: previousSessionType)
        let baseType = isLiftingDay ? SessionType.lifting : selectCardioType(recovery: recoveryState, counters: weeklyCounters)

        var volumeModifier: Double = 1.0
        var allowFailure = true
        var reasons: [String] = []
        var cardioNotes: [String] = []
        var nutritionAlerts: [String] = []

        // Recovery-based adjustments
        switch recoveryState {
        case .high:
            reasons.append("Recovery is high — proceed as planned.")
        case .moderate:
            volumeModifier = 0.85
            allowFailure = false
            reasons.append("Recovery is moderate — reduce volume ~15%, back off failure sets.")
            if baseType.isHighIntensityCardio {
                cardioNotes.append("Consider swapping to Zone 2 given moderate recovery.")
            }
        case .low:
            volumeModifier = 0.70
            allowFailure = false
            reasons.append("Recovery is low — reduce volume ~30%, no failure sets.")
            if baseType.isHighIntensityCardio {
                cardioNotes.append("⚠️ High intensity cardio blocked — switch to Zone 2 or rest.")
            }
        }

        // Cardio safety caps
        if weeklyCounters.totalHighIntensityCardio >= 2 && baseType.isHighIntensityCardio {
            cardioNotes.append("2 high-intensity sessions already logged this week — Zone 2 required.")
        }
        if weeklyCounters.norwegianDone >= 1 && baseType == .cardioNorwegian {
            cardioNotes.append("Norwegian 4x4 already done this week — select VO2 max or Zone 2.")
        }

        // Nutrition alerts
        if let end = workoutEndTime {
            let gap = Date().timeIntervalSince(end) / 3600
            if gap > UserProfile.postWorkoutMealDelayHours {
                nutritionAlerts.append("⚡ Post-workout meal window: add carbs + protein now (dates, fast carbs, whey).")
            }
        }

        let finalType = resolveCardioIfBlocked(base: baseType, recovery: recoveryState, counters: weeklyCounters)

        return SessionRecommendation(
            sessionType: finalType,
            reason: reasons.joined(separator: " "),
            volumeModifier: volumeModifier,
            allowFailureSets: allowFailure,
            cardioNotes: cardioNotes,
            nutritionAlerts: nutritionAlerts
        )
    }

    // MARK: - Logic Helpers

    private static func shouldLift(previous: SessionType?) -> Bool {
        guard let prev = previous else { return true }
        return prev.isCardio || prev == .rest || prev == .recovery
    }

    private static func selectCardioType(recovery: RecoveryState, counters: WeeklyCounters) -> SessionType {
        guard recovery != .low else { return .cardioZone2 }

        if counters.vo2Done < UserProfile.vo2MaxTargetMax && counters.totalHighIntensityCardio < 2 {
            return .cardioVO2
        }
        if counters.zone2Done < UserProfile.zone2Target {
            return .cardioZone2
        }
        return .cardioZone2
    }

    private static func resolveCardioIfBlocked(base: SessionType, recovery: RecoveryState, counters: WeeklyCounters) -> SessionType {
        guard base.isHighIntensityCardio else { return base }
        if recovery == .low { return .cardioZone2 }
        if counters.totalHighIntensityCardio >= 2 { return .cardioZone2 }
        if base == .cardioNorwegian && counters.norwegianDone >= 1 { return .cardioVO2 }
        return base
    }

    // MARK: - Performance Decline Detection

    static func detectPerformanceDecline(recentSessions: [WorkoutSession]) -> Bool {
        guard recentSessions.count >= 2 else { return false }
        let last = recentSessions.prefix(2).map { $0.totalVolume }
        return last[0] < last[1] * 0.95  // >5% drop in total volume
    }

    // MARK: - Weekly Summary

    static func buildWeeklyCounters(from logs: [DailyLog]) -> WeeklyCounters {
        var counters = WeeklyCounters()
        for log in logs {
            if log.workout?.completed == true { counters.liftingDone += 1 }
            if let cardio = log.cardio, cardio.completed {
                switch cardio.type {
                case .cardioVO2: counters.vo2Done += 1
                case .cardioNorwegian: counters.norwegianDone += 1
                case .cardioZone2: counters.zone2Done += 1
                default: break
                }
            }
        }
        return counters
    }
}
