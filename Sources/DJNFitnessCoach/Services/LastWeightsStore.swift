import Foundation

/// Persists the last-used weight for every (exercise name, set number) pair.
/// Pre-populates the workout log automatically so you never start from 0 kg.
final class LastWeightsStore {
    static let shared = LastWeightsStore()
    private let key = "djn_last_weights_v1"
    private init() {}

    private var store: [String: Double] {
        get { UserDefaults.standard.dictionary(forKey: key) as? [String: Double] ?? [:] }
        set { UserDefaults.standard.set(newValue, forKey: key) }
    }

    /// Last weight used for a specific exercise + set number. Returns 0 if never logged.
    func weight(for exercise: String, setNumber: Int) -> Double {
        store[key(exercise, setNumber)] ?? 0
    }

    /// Save all sets from a completed session (called after every workout save).
    func persist(_ sets: [WorkoutSetEntry]) {
        var current = store
        for s in sets {
            current[key(s.exerciseName, s.setNumber)] = s.weight
        }
        store = current
    }

    private func key(_ exercise: String, _ setNumber: Int) -> String {
        "\(exercise)::\(setNumber)"
    }
}
