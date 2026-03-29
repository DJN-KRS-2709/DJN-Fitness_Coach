import SwiftUI
import SwiftData

struct WorkoutHubView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var showingWorkoutLog = false
    @State private var showingCardioLog = false
    @State private var recentSessions: [DailyLog] = []

    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.background.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 20) {
                        sessionTypeButtons
                        recentSessionsList
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 24)
                }
            }
            .navigationTitle("Workout")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(AppColors.background, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .sheet(isPresented: $showingWorkoutLog) {
                WorkoutLogView()
            }
            .sheet(isPresented: $showingCardioLog) {
                CardioLogView()
            }
        }
        .onAppear { loadRecent() }
    }

    private var sessionTypeButtons: some View {
        VStack(spacing: 12) {
            Button { showingWorkoutLog = true } label: {
                sessionButton(
                    icon: "dumbbell.fill",
                    title: "Full Body Lifting",
                    subtitle: "Chest · Back · Shoulders · Arms · Legs",
                    color: AppColors.blue
                )
            }

            Button { showingCardioLog = true } label: {
                sessionButton(
                    icon: "figure.run",
                    title: "Cardio Session",
                    subtitle: "VO2 Max · Norwegian 4x4 · Zone 2",
                    color: AppColors.orange
                )
            }
        }
    }

    private func sessionButton(icon: String, title: String, subtitle: String, color: Color) -> some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(color.opacity(0.15))
                    .frame(width: 52, height: 52)
                Image(systemName: icon)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(color)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(AppColors.textPrimary)
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundColor(AppColors.textSecondary)
            }
            Spacer()
            Image(systemName: "plus.circle.fill")
                .font(.system(size: 22))
                .foregroundColor(color)
        }
        .padding(16)
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(AppColors.cardBorder, lineWidth: 0.5))
    }

    private var recentSessionsList: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Recent Sessions")
            if recentSessions.isEmpty {
                Text("No sessions logged yet")
                    .font(.system(size: 14))
                    .foregroundColor(AppColors.textSecondary)
                    .padding(.vertical, 8)
            } else {
                ForEach(recentSessions, id: \.date) { log in
                    sessionRow(log)
                }
            }
        }
    }

    private func sessionRow(_ log: DailyLog) -> some View {
        AppCard(padding: 14) {
            HStack(spacing: 12) {
                if let workout = log.workout, workout.completed {
                    sessionIcon(type: .lifting)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Full Body Lifting")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(AppColors.textPrimary)
                        HStack(spacing: 8) {
                            Text("\(workout.totalSets) sets")
                            Text("·")
                            Text("\(workout.durationMinutes) min")
                            Text("·")
                            Text("RPE \(workout.perceivedExertion)")
                        }
                        .font(.system(size: 12))
                        .foregroundColor(AppColors.textSecondary)
                    }
                } else if let cardio = log.cardio, cardio.completed {
                    sessionIcon(type: cardio.type)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(cardio.type.rawValue)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(AppColors.textPrimary)
                        HStack(spacing: 8) {
                            Text("\(cardio.durationMinutes) min")
                            if let hr = cardio.avgHeartRate {
                                Text("·")
                                Text("~\(hr) bpm avg")
                            }
                            if let dist = cardio.distanceKm {
                                Text("·")
                                Text(String(format: "%.1f km", dist))
                            }
                        }
                        .font(.system(size: 12))
                        .foregroundColor(AppColors.textSecondary)
                    }
                }
                Spacer()
                Text(relativeDate(log.date))
                    .font(.system(size: 11))
                    .foregroundColor(AppColors.textSecondary)
            }
        }
    }

    private func sessionIcon(type: SessionType) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10)
                .fill(AppColors.forSessionType(type).opacity(0.15))
                .frame(width: 40, height: 40)
            Image(systemName: type.icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(AppColors.forSessionType(type))
        }
    }

    private func relativeDate(_ date: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(date) { return "Today" }
        if cal.isDateInYesterday(date) { return "Yesterday" }
        let formatter = DateFormatter()
        formatter.dateFormat = "E d MMM"
        return formatter.string(from: date)
    }

    private func loadRecent() {
        let ds = DataService(modelContext: modelContext)
        recentSessions = ds.fetchRecentLogs(days: 14).filter {
            $0.workout?.completed == true || $0.cardio?.completed == true
        }
    }
}
