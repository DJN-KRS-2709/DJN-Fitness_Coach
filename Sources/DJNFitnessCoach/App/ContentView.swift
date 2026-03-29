import SwiftUI

struct ContentView: View {
    @State private var selectedTab: Tab = .dashboard

    enum Tab: String, CaseIterable {
        case dashboard = "Dashboard"
        case workout = "Workout"
        case nutrition = "Nutrition"
        case supplements = "Supplements"
        case progress = "Progress"

        var icon: String {
            switch self {
            case .dashboard: return "house.fill"
            case .workout: return "figure.strengthtraining.traditional"
            case .nutrition: return "fork.knife"
            case .supplements: return "pill.fill"
            case .progress: return "chart.line.uptrend.xyaxis"
            }
        }
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            DashboardView()
                .tabItem { Label("Dashboard", systemImage: Tab.dashboard.icon) }
                .tag(Tab.dashboard)

            WorkoutHubView()
                .tabItem { Label("Workout", systemImage: Tab.workout.icon) }
                .tag(Tab.workout)

            NutritionView()
                .tabItem { Label("Nutrition", systemImage: Tab.nutrition.icon) }
                .tag(Tab.nutrition)

            SupplementsView()
                .tabItem { Label("Supplements", systemImage: Tab.supplements.icon) }
                .tag(Tab.supplements)

            ProgressView()
                .tabItem { Label("Progress", systemImage: Tab.progress.icon) }
                .tag(Tab.progress)
        }
        .tint(AppColors.accent)
    }
}
