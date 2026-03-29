import Foundation

struct UserProfile {
    // Fixed profile - single user app
    static let age: Int = 43
    static let sex: String = "male"
    static let heightCm: Double = 181
    static let weightKg: Double = 80
    static let bodyFatMin: Double = 8
    static let bodyFatMax: Double = 11
    static let trainingAgeMin: Int = 25
    static let trainingAgeMax: Int = 27

    static let goals: [String] = ["Longevity", "Cardiovascular Fitness", "Maintain Muscle", "Maintain Performance"]

    // Training defaults
    static let liftingSplit: String = "Full Body"
    static let chestSets: Int = 4
    static let backSets: Int = 4
    static let shoulderSets: Int = 2
    static let armSets: Int = 2
    static let legsMin: Int = 2
    static let legsMax: Int = 3

    // Weekly cardio targets
    static let vo2MaxTargetMin: Int = 1
    static let vo2MaxTargetMax: Int = 2
    static let norwegianMax: Int = 1
    static let zone2Target: Int = 1

    // Nutrition targets
    static let caloriesMin: Int = 2800
    static let caloriesMax: Int = 3200
    static let proteinMin: Int = 200
    static let proteinMax: Int = 230
    static let carbsMin: Int = 270
    static let carbsMax: Int = 320
    static let fatMin: Int = 70
    static let fatMax: Int = 90

    static let firstMealTime: String = "12:00"
    static let postWorkoutMealDelayHours: Double = 2.5
    static let sodiumTargetMin: Int = 2000
    static let sodiumTargetMax: Int = 3000 // mg
}
