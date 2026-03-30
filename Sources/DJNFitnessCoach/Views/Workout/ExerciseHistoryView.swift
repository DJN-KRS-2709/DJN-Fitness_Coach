import SwiftUI
import SwiftData

struct ExerciseHistoryTarget: Identifiable {
    let id = UUID()
    let exerciseName: String
    let muscle: MuscleGroup
}

struct ExerciseHistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let target: ExerciseHistoryTarget

    @State private var sessions: [(date: Date, sets: [LiftingSet])] = []

    private var allSets: [LiftingSet] { sessions.flatMap { $0.sets } }
    private var bestWeight: Double { allSets.map { $0.weight }.max() ?? 0 }
    private var totalVolume: Double { allSets.reduce(0) { $0 + Double($1.reps) * $1.weight } }

    // One max-weight value per session (for the mini chart), oldest → newest
    private var weightProgression: [Double] {
        sessions.reversed().map { $0.sets.map { $0.weight }.max() ?? 0 }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.background.ignoresSafeArea()
                if sessions.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        VStack(spacing: 16) {
                            statsCard
                            if weightProgression.count >= 2 { progressionChart }
                            sessionsList
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                        .padding(.bottom, 32)
                    }
                }
            }
            .navigationTitle(target.exerciseName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(AppColors.background, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }.foregroundColor(AppColors.blue)
                }
            }
        }
        .onAppear { loadHistory() }
    }

    // MARK: - Stats Card

    private var statsCard: some View {
        AppCard {
            HStack(spacing: 0) {
                statCell(
                    title: "Best Set",
                    value: bestWeight == 0 ? "BW" : String(format: "%.1f", bestWeight),
                    unit: bestWeight == 0 ? nil : "kg",
                    color: AppColors.blue
                )
                Divider().frame(height: 44).background(AppColors.cardBorder)
                statCell(title: "Sessions", value: "\(sessions.count)", unit: nil, color: AppColors.purple)
                Divider().frame(height: 44).background(AppColors.cardBorder)
                statCell(title: "Total Sets", value: "\(allSets.count)", unit: nil, color: AppColors.teal)
            }
        }
    }

    private func statCell(title: String, value: String, unit: String?, color: Color) -> some View {
        VStack(spacing: 3) {
            HStack(alignment: .lastTextBaseline, spacing: 2) {
                Text(value)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(color)
                if let unit = unit {
                    Text(unit)
                        .font(.system(size: 12))
                        .foregroundColor(AppColors.textSecondary)
                }
            }
            Text(title)
                .font(.system(size: 11))
                .foregroundColor(AppColors.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Progression Chart

    private var progressionChart: some View {
        AppCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    SectionHeader(title: "Weight Progression")
                    Spacer()
                    // Trend indicator
                    if let first = weightProgression.first, let last = weightProgression.last, first > 0 {
                        let delta = last - first
                        HStack(spacing: 4) {
                            Image(systemName: delta >= 0 ? "arrow.up.right" : "arrow.down.right")
                            Text(delta == 0 ? "Stable" : String(format: "%+.1f kg", delta))
                        }
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(delta >= 0 ? AppColors.green : AppColors.orange)
                    }
                }

                GeometryReader { geo in
                    let maxVal = weightProgression.max() ?? 1
                    let minVal = weightProgression.min() ?? 0
                    let range = maxVal - minVal
                    let barWidth = max(4, (geo.size.width - CGFloat(weightProgression.count - 1) * 4) / CGFloat(weightProgression.count))

                    HStack(alignment: .bottom, spacing: 4) {
                        ForEach(Array(weightProgression.enumerated()), id: \.offset) { idx, val in
                            let normalized = range > 0 ? (val - minVal) / range : 1.0
                            let height = max(8, (geo.size.height - 16) * CGFloat(normalized) + 16)
                            let isLatest = idx == weightProgression.count - 1
                            RoundedRectangle(cornerRadius: 3)
                                .fill(isLatest ? AppColors.blue : AppColors.blue.opacity(0.35))
                                .frame(width: barWidth, height: height)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                }
                .frame(height: 64)

                HStack {
                    if let oldest = sessions.last {
                        Text(shortDate(oldest.date))
                            .font(.system(size: 10))
                            .foregroundColor(AppColors.textSecondary)
                    }
                    Spacer()
                    if let newest = sessions.first {
                        Text(shortDate(newest.date))
                            .font(.system(size: 10))
                            .foregroundColor(AppColors.textSecondary)
                    }
                }
            }
        }
    }

    // MARK: - Sessions List

    private var sessionsList: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Sessions", subtitle: "newest first")
            ForEach(sessions, id: \.date) { session in
                sessionCard(session)
            }
        }
    }

    private func sessionCard(_ session: (date: Date, sets: [LiftingSet])) -> some View {
        let maxWeight = session.sets.map { $0.weight }.max() ?? 0

        return AppCard(padding: 14) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(dateLabel(session.date))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(AppColors.textPrimary)
                    Spacer()
                    Text(maxWeight == 0 ? "Bodyweight" : String(format: "%.1f kg top", maxWeight))
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundColor(AppColors.blue)
                }

                VStack(spacing: 4) {
                    ForEach(session.sets, id: \.setNumber) { set in
                        HStack(spacing: 8) {
                            Text("S\(set.setNumber)")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(AppColors.textSecondary)
                                .frame(width: 22, alignment: .leading)

                            Text(set.weight == 0 ? "BW" : String(format: "%.1f kg", set.weight))
                                .font(.system(size: 13, weight: set.weight == maxWeight ? .bold : .regular, design: .rounded))
                                .foregroundColor(set.weight == maxWeight && maxWeight > 0 ? AppColors.blue : AppColors.textPrimary)
                                .frame(width: 60, alignment: .leading)

                            Text("×  \(set.reps) reps")
                                .font(.system(size: 13))
                                .foregroundColor(AppColors.textPrimary)

                            if set.toFailure {
                                Text("F")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundColor(.black)
                                    .frame(width: 18, height: 18)
                                    .background(AppColors.red)
                                    .clipShape(Circle())
                            }

                            Spacer()
                        }
                    }
                }
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 44))
                .foregroundColor(AppColors.textSecondary.opacity(0.3))
            Text("No history yet")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(AppColors.textSecondary)
            Text("Log a set of \(target.exerciseName) to start tracking progress.")
                .font(.system(size: 13))
                .foregroundColor(AppColors.textSecondary.opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Helpers

    private func dateLabel(_ date: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(date) { return "Today" }
        if cal.isDateInYesterday(date) { return "Yesterday" }
        let f = DateFormatter()
        f.dateFormat = "EEEE, d MMM"
        return f.string(from: date)
    }

    private func shortDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "d MMM"
        return f.string(from: date)
    }

    private func loadHistory() {
        let ds = DataService(modelContext: modelContext)
        sessions = ds.fetchExerciseSessions(exerciseName: target.exerciseName)
    }
}
