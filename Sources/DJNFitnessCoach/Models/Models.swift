import Foundation
import SwiftData

// MARK: - Daily Log (anchor for each calendar day)

@Model
final class DailyLog {
    @Attribute(.unique) var date: Date
    var sessionType: SessionType?     // determined by rule engine
    var notes: String

    @Relationship(deleteRule: .cascade) var workout: WorkoutSession?
    @Relationship(deleteRule: .cascade) var cardio: CardioSession?
    @Relationship(deleteRule: .cascade) var nutrition: NutritionLog?
    @Relationship(deleteRule: .cascade) var recovery: RecoveryLog?
    @Relationship(deleteRule: .cascade) var supplements: SupplementLog?

    init(date: Date = Calendar.current.startOfDay(for: Date()), notes: String = "") {
        self.date = Calendar.current.startOfDay(for: date)
        self.notes = notes
    }
}

enum SessionType: String, Codable, CaseIterable {
    case lifting = "Lifting"
    case cardioVO2 = "VO2 Max"
    case cardioNorwegian = "Norwegian 4x4"
    case cardioZone2 = "Zone 2"
    case rest = "Rest"
    case recovery = "Active Recovery"

    var isLifting: Bool { self == .lifting }
    var isCardio: Bool { [.cardioVO2, .cardioNorwegian, .cardioZone2].contains(self) }
    var isHighIntensityCardio: Bool { [.cardioVO2, .cardioNorwegian].contains(self) }

    var icon: String {
        switch self {
        case .lifting: return "dumbbell.fill"
        case .cardioVO2: return "lungs.fill"
        case .cardioNorwegian: return "bolt.fill"
        case .cardioZone2: return "heart.fill"
        case .rest: return "moon.zzz.fill"
        case .recovery: return "figure.walk"
        }
    }

    var color: String {
        switch self {
        case .lifting: return "blue"
        case .cardioVO2: return "orange"
        case .cardioNorwegian: return "red"
        case .cardioZone2: return "green"
        case .rest: return "purple"
        case .recovery: return "teal"
        }
    }
}

// MARK: - Workout Session

@Model
final class WorkoutSession {
    var date: Date
    var durationMinutes: Int
    var perceivedExertion: Int    // 1-10 RPE
    var notes: String
    var completed: Bool

    @Relationship(deleteRule: .cascade) var sets: [LiftingSet]

    init(date: Date = Date(), durationMinutes: Int = 60, perceivedExertion: Int = 8, notes: String = "", completed: Bool = false) {
        self.date = date
        self.durationMinutes = durationMinutes
        self.perceivedExertion = perceivedExertion
        self.notes = notes
        self.completed = completed
        self.sets = []
    }

    var totalSets: Int { sets.count }
    var totalVolume: Double { sets.reduce(0) { $0 + (Double($1.reps) * $1.weight) } }

    func setsFor(muscle: MuscleGroup) -> [LiftingSet] {
        sets.filter { $0.muscleGroup == muscle }
    }
}

enum MuscleGroup: String, Codable, CaseIterable {
    case chest = "Chest"
    case back = "Back"
    case shoulders = "Shoulders"
    case arms = "Arms"
    case legs = "Legs"
    case core = "Core"

    var defaultSets: Int {
        switch self {
        case .chest:     return 5   // 3× Incline Barbell, 1× Cable Fly, 1× Flat DB
        case .back:      return 4   // 2× Pull-Up, 1× Pullover, 1× Row
        case .shoulders: return 4   // 1× OHP, 1× Lateral, 2× Rear Delt
        case .arms:      return 3   // 1× Curl, 1× Overhead Ext, 1× Pushdown
        case .legs:      return 2   // 1× RDL, 1× Leg Press
        case .core:      return 0
        }
    }

    var icon: String {
        switch self {
        case .chest: return "figure.strengthtraining.traditional"
        case .back: return "figure.rowing"
        case .shoulders: return "arrow.up.and.line.horizontal.and.arrow.down"
        case .arms: return "figure.arms.open"
        case .legs: return "figure.run"
        case .core: return "circle.grid.cross.fill"
        }
    }
}

@Model
final class LiftingSet {
    var muscleGroup: MuscleGroup
    var exerciseName: String
    var setNumber: Int
    var reps: Int
    var weight: Double            // kg
    var toFailure: Bool
    var rpe: Int                  // 1-10
    var notes: String

    init(muscleGroup: MuscleGroup, exerciseName: String, setNumber: Int = 1, reps: Int = 10, weight: Double = 0, toFailure: Bool = false, rpe: Int = 8, notes: String = "") {
        self.muscleGroup = muscleGroup
        self.exerciseName = exerciseName
        self.setNumber = setNumber
        self.reps = reps
        self.weight = weight
        self.toFailure = toFailure
        self.rpe = rpe
        self.notes = notes
    }
}

// MARK: - Cardio Session

@Model
final class CardioSession {
    var date: Date
    var type: SessionType
    var durationMinutes: Int
    var avgHeartRate: Int?
    var maxHeartRate: Int?
    var distanceKm: Double?
    var notes: String
    var completed: Bool

    // Norwegian 4x4 specifics
    var intervals: Int?
    var intervalDurationMinutes: Int?
    var restDurationMinutes: Int?

    init(date: Date = Date(), type: SessionType = .cardioZone2, durationMinutes: Int = 45, notes: String = "", completed: Bool = false) {
        self.date = date
        self.type = type
        self.durationMinutes = durationMinutes
        self.notes = notes
        self.completed = completed
    }
}

// MARK: - Nutrition Log

@Model
final class NutritionLog {
    var date: Date
    var calories: Int
    var proteinG: Double
    var carbsG: Double
    var fatG: Double
    var sodiumMg: Int
    var hydrationL: Double
    var firstMealTime: Date?
    var notes: String

    // Macro sub-breakdown
    var quarkG: Double
    var wheyG: Double
    var clearWheyG: Double
    var caseinG: Double
    var collagenG: Double = 0       // default enables safe SwiftData migration
    var proteinMilkMl: Double = 0  // default enables safe SwiftData migration
    var beefOrChickenG: Double
    var eggsCount: Int
    var riceDryG: Double
    var fruitPortions: Int
    var dates: Int            // Medjool dates
    var darkChocolateG: Double
    var vegetablesG: Double
    var flatWhitesCount: Int
    var walnutsIncluded: Bool

    // Quick-add extras (restaurant, ice cream, etc.)
    var extraCalories: Int
    var extraProteinG: Double
    var extraCarbsG: Double
    var extraFatG: Double
    var extraNotes: String

    init(date: Date = Date()) {
        self.date = date
        self.calories = 0
        self.proteinG = 0
        self.carbsG = 0
        self.fatG = 0
        self.sodiumMg = 2500
        self.hydrationL = 3.0
        self.notes = ""
        self.quarkG = 500
        self.wheyG = 50
        self.clearWheyG = 40
        self.caseinG = 50
        self.collagenG = 20
        self.proteinMilkMl = 333
        self.beefOrChickenG = 200
        self.eggsCount = 2
        self.riceDryG = 200
        self.fruitPortions = 1
        self.dates = 1
        self.darkChocolateG = 20
        self.vegetablesG = 350
        self.flatWhitesCount = 3
        self.walnutsIncluded = true
        self.extraCalories = 0
        self.extraProteinG = 0
        self.extraCarbsG = 0
        self.extraFatG = 0
        self.extraNotes = ""
    }

    var proteinTarget: ClosedRange<Int> { UserProfile.proteinMin...UserProfile.proteinMax }
    var carbsTarget: ClosedRange<Int> { UserProfile.carbsMin...UserProfile.carbsMax }
    var fatTarget: ClosedRange<Int> { UserProfile.fatMin...UserProfile.fatMax }
    var caloriesTarget: ClosedRange<Int> { UserProfile.caloriesMin...UserProfile.caloriesMax }
}

// MARK: - Recovery Log

@Model
final class RecoveryLog {
    var date: Date
    var sleepHours: Double
    var sleepQuality: Int         // 1-5
    var restingHeartRate: Int?
    var energyScore: Int          // 1-5
    var motivationScore: Int      // 1-5
    var sorenessScore: Int        // 1-5 (1=none, 5=very sore)
    var stressScore: Int          // 1-5
    var libidoStatus: LibidoStatus
    var perceivedRecoveryScore: Int // 1-10
    var notes: String
    var steps: Int

    init(date: Date = Date()) {
        self.date = date
        self.sleepHours = 7.5
        self.sleepQuality = 4
        self.energyScore = 4
        self.motivationScore = 4
        self.sorenessScore = 2
        self.stressScore = 2
        self.libidoStatus = .normal
        self.perceivedRecoveryScore = 8
        self.notes = ""
        self.steps = 0
    }

    var recoveryState: RecoveryState {
        var lowMarkers = 0
        if sleepQuality <= 2 { lowMarkers += 1 }
        if energyScore <= 2 { lowMarkers += 1 }
        if motivationScore <= 2 { lowMarkers += 1 }
        if sorenessScore >= 4 { lowMarkers += 1 }
        if stressScore >= 4 { lowMarkers += 1 }
        if libidoStatus == .low { lowMarkers += 1 }
        if let rhr = restingHeartRate, rhr > 65 { lowMarkers += 1 }

        switch lowMarkers {
        case 0...1: return .high
        case 2...3: return .moderate
        default: return .low
        }
    }
}

enum RecoveryState: String, Codable {
    case high = "High"
    case moderate = "Moderate"
    case low = "Low"

    var color: String {
        switch self {
        case .high: return "green"
        case .moderate: return "yellow"
        case .low: return "red"
        }
    }

    var icon: String {
        switch self {
        case .high: return "checkmark.circle.fill"
        case .moderate: return "exclamationmark.circle.fill"
        case .low: return "xmark.circle.fill"
        }
    }
}

enum LibidoStatus: String, Codable, CaseIterable {
    case normal = "Normal"
    case elevated = "Elevated"
    case low = "Low"
}

// MARK: - Supplement Log

@Model
final class SupplementLog {
    var date: Date
    var isAlternateDay: Bool

    // Daily supplements
    var omega3: Bool
    var magnesium: Bool
    var glycine: Bool
    var nad: Bool
    var ashwagandha: Bool
    var urolithinA: Bool
    var vitaminDK2: Bool
    var zinc: Bool
    var boron: Bool
    var creatine: Bool
    var glutamine: Bool
    var clearWheyDone: Bool
    var wheyDone: Bool
    var caseinDone: Bool

    // Alternate day
    var methyleneBlue: Bool
    var cuminOil: Bool

    init(date: Date = Date(), isAlternateDay: Bool = false) {
        self.date = date
        self.isAlternateDay = isAlternateDay
        self.omega3 = true
        self.magnesium = true
        self.glycine = true
        self.nad = true
        self.ashwagandha = true
        self.urolithinA = true
        self.vitaminDK2 = true
        self.zinc = true
        self.boron = true
        self.creatine = true
        self.glutamine = true
        self.clearWheyDone = true
        self.wheyDone = true
        self.caseinDone = true
        self.methyleneBlue = isAlternateDay
        self.cuminOil = isAlternateDay
    }

    var dailyCompletionCount: Int {
        [omega3, magnesium, glycine, nad, ashwagandha, urolithinA, vitaminDK2, zinc, boron, creatine, glutamine, clearWheyDone, wheyDone, caseinDone]
            .filter { $0 }.count
    }

    var dailyTotalCount: Int { 14 }

    var alternateDayCompletionCount: Int {
        [methyleneBlue, cuminOil].filter { $0 }.count
    }

    var completionPercentage: Double {
        let total = isAlternateDay ? dailyTotalCount + 2 : dailyTotalCount
        let done = isAlternateDay ? dailyCompletionCount + alternateDayCompletionCount : dailyCompletionCount
        return total > 0 ? Double(done) / Double(total) : 0
    }
}

// MARK: - Progress Video

@Model
final class ProgressVideo {
    var date: Date
    var fileName: String       // stored in app Documents/ProgressVideos/ ("" for photos stored inline)
    var notes: String
    var thumbnailData: Data?
    var mediaType: String      // "video" or "photo"
    var imageData: Data?       // full-res JPEG for photos

    init(date: Date = Date(), fileName: String, notes: String = "", mediaType: String = "video") {
        self.date = Calendar.current.startOfDay(for: date)
        self.fileName = fileName
        self.notes = notes
        self.mediaType = mediaType
    }

    var isPhoto: Bool { mediaType == "photo" }

    var fileURL: URL? {
        guard !fileName.isEmpty,
              let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return nil }
        return docs.appendingPathComponent("ProgressVideos").appendingPathComponent(fileName)
    }
}

// MARK: - Body Metric

@Model
final class BodyMetric {
    @Attribute(.unique) var date: Date
    var weightKg: Double
    var bodyFatPercent: Double?
    var notes: String

    init(date: Date = Date(), weightKg: Double, bodyFatPercent: Double? = nil, notes: String = "") {
        self.date = Calendar.current.startOfDay(for: date)
        self.weightKg = weightKg
        self.bodyFatPercent = bodyFatPercent
        self.notes = notes
    }
}
