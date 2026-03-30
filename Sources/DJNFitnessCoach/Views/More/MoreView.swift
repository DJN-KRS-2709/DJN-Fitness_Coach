import SwiftUI

struct MoreView: View {
    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.background.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 12) {
                        moreRow(
                            title: "Workout",
                            subtitle: "Log lifting & cardio sessions",
                            icon: "figure.strengthtraining.traditional",
                            color: AppColors.blue,
                            destination: AnyView(WorkoutHubView())
                        )
                        moreRow(
                            title: "Health Metrics",
                            subtitle: "Recovery, Apple Health, weekly overview",
                            icon: "heart.text.square.fill",
                            color: AppColors.red,
                            destination: AnyView(HealthMetricsView())
                        )
                        moreRow(
                            title: "Supplements",
                            subtitle: "Daily supplement checklist",
                            icon: "pill.fill",
                            color: AppColors.purple,
                            destination: AnyView(SupplementsView())
                        )
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                }
            }
            .navigationTitle("More")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(AppColors.background, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }

    private func moreRow(title: String, subtitle: String, icon: String, color: Color, destination: AnyView) -> some View {
        NavigationLink(destination: destination) {
            AppCard {
                HStack(spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(color.opacity(0.15))
                            .frame(width: 44, height: 44)
                        Image(systemName: icon)
                            .font(.system(size: 18))
                            .foregroundColor(color)
                    }
                    VStack(alignment: .leading, spacing: 3) {
                        Text(title)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(AppColors.textPrimary)
                        Text(subtitle)
                            .font(.system(size: 13))
                            .foregroundColor(AppColors.textSecondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(AppColors.textSecondary)
                }
            }
        }
    }
}
