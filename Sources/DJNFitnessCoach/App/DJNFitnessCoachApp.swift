import SwiftUI
import SwiftData

@main
struct DJNFitnessCoachApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .modelContainer(AppModelContainer.shared)
                .preferredColorScheme(.dark)
                .task {
                    await HealthKitService.shared.requestAuthorization()
                }
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
            ProgressVideo.self,
        ])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            // Migration failed — wipe store and recreate cleanly
            let storeURL = config.url
            try? FileManager.default.removeItem(at: storeURL)
            try? FileManager.default.removeItem(at: storeURL.appendingPathExtension("wal"))
            try? FileManager.default.removeItem(at: storeURL.appendingPathExtension("shm"))
            do {
                return try ModelContainer(for: schema, configurations: [config])
            } catch {
                fatalError("Failed to create ModelContainer after reset: \(error)")
            }
        }
    }()
}
