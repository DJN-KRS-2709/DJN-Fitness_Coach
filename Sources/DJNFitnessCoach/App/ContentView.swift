import SwiftUI

struct ContentView: View {
    @State private var selectedTab: Tab = .dashboard

    enum Tab: String, CaseIterable {
        case dashboard = "Dashboard"
        case coach = "Coach"
        case progress = "Progress"
        case nutrition = "Nutrition"
        case more = "More"

        var icon: String {
            switch self {
            case .dashboard: return "house.fill"
            case .coach:     return "brain.head.profile"
            case .progress:  return "chart.line.uptrend.xyaxis"
            case .nutrition: return "fork.knife"
            case .more:      return "ellipsis.circle.fill"
            }
        }
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            DashboardView()
                .tabItem { Label("Dashboard", systemImage: Tab.dashboard.icon) }
                .tag(Tab.dashboard)

            CoachView()
                .tabItem { Label("Coach", systemImage: Tab.coach.icon) }
                .tag(Tab.coach)

            ProgressView()
                .tabItem { Label("Progress", systemImage: Tab.progress.icon) }
                .tag(Tab.progress)

            NutritionView()
                .tabItem { Label("Nutrition", systemImage: Tab.nutrition.icon) }
                .tag(Tab.nutrition)

            MoreView()
                .tabItem { Label("More", systemImage: Tab.more.icon) }
                .tag(Tab.more)
        }
        .tint(AppColors.accent)
    }
}
