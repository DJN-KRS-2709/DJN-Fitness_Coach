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
            // Only wipe if the store is genuinely corrupt (not a routine migration).
            // New properties with schema-level defaults migrate automatically — no wipe needed.
            let storeURL = config.url
            let isCorrupt = (error as NSError).domain == NSCocoaErrorDomain
            guard isCorrupt else { fatalError("ModelContainer failed unexpectedly: \(error)") }
            try? FileManager.default.removeItem(at: storeURL)
            try? FileManager.default.removeItem(at: storeURL.appendingPathExtension("wal"))
            try? FileManager.default.removeItem(at: storeURL.appendingPathExtension("shm"))
            do {
                return try ModelContainer(for: schema, configurations: [config])
            } catch {
                fatalError("Failed to create ModelContainer after corruption reset: \(error)")
            }
        }
    }()
}
