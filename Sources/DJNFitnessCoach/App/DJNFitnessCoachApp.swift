import SwiftUI
import SwiftData

@main
struct DJNFitnessCoachApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .modelContainer(AppModelContainer.shared)
                .preferredColorScheme(.dark)
        }
    }
}

enum AppModelContainer {
    static let shared: ModelContainer = {
        let schema = Schema([
            DailyLog.self,
            WorkoutSession.self,
            LiftingSet.self,
            CardioSession.self,
            NutritionLog.self,
            RecoveryLog.self,
            SupplementLog.self,
            BodyMetric.self,
        ])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }()
}
