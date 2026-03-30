import SwiftUI
import SwiftData
import Charts
import UIKit

struct ProgressView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var bodyMetrics: [BodyMetric] = []
    @State private var recentLogs: [DailyLog] = []
    @State private var selectedPeriod: Period = .month
    @State private var coachHandoffImage: UIImage? = nil
    @State private var navigateToCoach = false

    enum Period: String, CaseIterable {
        case week = "7D"
        case month = "30D"
        case quarter = "90D"
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.background.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 20) {
                        periodPicker
                        videosEntryCard
                        trainingConsistencyCard
                        weightChartCard
                        weeklyVolumeCard
                        performanceSummaryCard
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 24)
                }
            }
            .navigationTitle("Progress")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(AppColors.background, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
        .onAppear { loadData() }
        .onChange(of: selectedPeriod) { _, _ in loadData() }
    }

    // MARK: - Videos Entry

    private var videosEntryCard: some View {
        NavigationLink(destination: ProgressMediaView(onSendToCoach: { img in
            coachHandoffImage = img
            navigateToCoach = true
        })) {
            AppCard {
                HStack(spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(AppColors.purple.opacity(0.15))
                            .frame(width: 44, height: 44)
                        Image(systemName: "photo.stack.fill")
                            .font(.system(size: 18))
                            .foregroundColor(AppColors.purple)
                    }
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Photos & Videos")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(AppColors.textPrimary)
                        Text("Track visual progress — send photos to AI coach")
                            .font(.system(size: 12))
                            .foregroundColor(AppColors.textSecondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(AppColors.textSecondary)
                }
            }
        }
        // Hidden coach navigation trigger
        .background(
            NavigationLink(
                destination: CoachView(pendingImage: coachHandoffImage),
                isActive: $navigateToCoach,
                label: { EmptyView() }
            )
            .hidden()
        )
    }

    // MARK: - Period Picker

    private var periodPicker: some View {
        HStack(spacing: 0) {
            ForEach(Period.allCases, id: \.self) { period in
                Button {
                    selectedPeriod = period
                } label: {
                    Text(period.rawValue)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(selectedPeriod == period ? .black : AppColors.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(selectedPeriod == period ? AppColors.blue : Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }
        }
        .padding(4)
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Training Consistency

    private var trainingConsistencyCard: some View {
        AppCard {
            VStack(alignment: .leading, spacing: 14) {
                SectionHeader(title: "Training Consistency")

                HStack(spacing: 0) {
                    consistencyStat(
                        value: "\(recentLogs.filter { $0.workout?.completed == true }.count)",
                        label: "Lifts",
                        color: AppColors.blue
                    )
                    Divider().frame(height: 40).background(AppColors.cardBorder)
                    consistencyStat(
                        value: "\(recentLogs.filter { $0.cardio?.type == .cardioVO2 && $0.cardio?.completed == true }.count)",
                        label: "VO2",
                        color: AppColors.orange
                    )
                    Divider().frame(height: 40).background(AppColors.cardBorder)
                    consistencyStat(
                        value: "\(recentLogs.filter { $0.cardio?.type == .cardioNorwegian && $0.cardio?.completed == true }.count)",
                        label: "4×4",
                        color: AppColors.red
                    )
                    Divider().frame(height: 40).background(AppColors.cardBorder)
                    consistencyStat(
                        value: "\(recentLogs.filter { $0.cardio?.type == .cardioZone2 && $0.cardio?.completed == true }.count)",
                        label: "Zone 2",
                        color: AppColors.green
                    )
                }

                // Mini calendar heatmap
                sessionHeatmap
            }
        }
    }

    private func consistencyStat(value: String, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundColor(color)
            Text(label)
                .font(.system(size: 11))
                .foregroundColor(AppColors.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var sessionHeatmap: some View {
        let days = periodDays
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        let allDays = (0..<days).compactMap {
            calendar.date(byAdding: .day, value: -(days - 1 - $0), to: today)
        }

        let columns = Array(repeating: GridItem(.flexible(), spacing: 3), count: 7)

        return LazyVGrid(columns: columns, spacing: 3) {
            ForEach(allDays, id: \.self) { day in
                let log = recentLogs.first { calendar.isDate($0.date, inSameDayAs: day) }
                let color = heatmapColor(for: log)
                RoundedRectangle(cornerRadius: 2)
                    .fill(color)
                    .frame(height: 10)
            }
        }
    }

    private func heatmapColor(for log: DailyLog?) -> Color {
        guard let log else { return AppColors.cardBorder.opacity(0.4) }
        if log.workout?.completed == true { return AppColors.blue.opacity(0.8) }
        if let cardio = log.cardio, cardio.completed { return AppColors.forSessionType(cardio.type).opacity(0.8) }
        return AppColors.cardBorder.opacity(0.2)
    }

    // MARK: - Weight Chart

    private var weightChartCard: some View {
        AppCard {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(title: "Body Weight", subtitle: "Target: ~80 kg")

                if bodyMetrics.isEmpty {
                    Text("No weight data yet — log your morning weight from the dashboard")
                        .font(.system(size: 13))
                        .foregroundColor(AppColors.textSecondary)
                        .padding(.vertical, 8)
                } else {
                    Chart {
                        ForEach(bodyMetrics, id: \.date) { metric in
                            LineMark(
                                x: .value("Date", metric.date),
                                y: .value("Weight", metric.weightKg)
                            )
                            .foregroundStyle(AppColors.blue)
                            .lineStyle(StrokeStyle(lineWidth: 2))

                            AreaMark(
                                x: .value("Date", metric.date),
                                yStart: .value("Min", 78.0),
                                yEnd: .value("Weight", metric.weightKg)
                            )
                            .foregroundStyle(AppColors.blue.opacity(0.1))

                            PointMark(
                                x: .value("Date", metric.date),
                                y: .value("Weight", metric.weightKg)
                            )
                            .foregroundStyle(AppColors.blue)
                            .symbolSize(30)
                        }

                        RuleMark(y: .value("Target", 80.0))
                            .foregroundStyle(AppColors.green.opacity(0.5))
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                            .annotation(position: .trailing, alignment: .leading) {
                                Text("80")
                                    .font(.system(size: 9))
                                    .foregroundColor(AppColors.green)
                            }
                    }
                    .chartYScale(domain: (bodyMetrics.map(\.weightKg).min() ?? 76) - 1 ... (bodyMetrics.map(\.weightKg).max() ?? 84) + 1)
                    .chartXAxis {
                        AxisMarks(values: .stride(by: .day, count: axisStride)) { _ in
                            AxisGridLine().foregroundStyle(AppColors.cardBorder)
                            AxisValueLabel(format: .dateTime.day().month(.abbreviated))
                                .foregroundStyle(AppColors.textSecondary)
                        }
                    }
                    .chartYAxis {
                        AxisMarks { value in
                            AxisGridLine().foregroundStyle(AppColors.cardBorder)
                            AxisValueLabel()
                                .foregroundStyle(AppColors.textSecondary)
                        }
                    }
                    .frame(height: 180)

                    if let latest = bodyMetrics.last {
                        HStack {
                            statBadge(label: "Latest", value: String(format: "%.1f kg", latest.weightKg), color: AppColors.blue)
                            if bodyMetrics.count > 1, let first = bodyMetrics.first {
                                let diff = latest.weightKg - first.weightKg
                                statBadge(label: "Change", value: String(format: "%+.1f kg", diff), color: abs(diff) < 0.5 ? AppColors.green : AppColors.orange)
                            }
                            if let bf = latest.bodyFatPercent {
                                statBadge(label: "Body Fat", value: String(format: "%.1f%%", bf), color: bf <= 11 ? AppColors.green : AppColors.orange)
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Weekly Volume Card

    private var weeklyVolumeCard: some View {
        AppCard {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(title: "Session Volume Trend")
                let workouts = recentLogs.compactMap { $0.workout }.filter { $0.completed }
                if workouts.isEmpty {
                    Text("No lifting sessions logged yet")
                        .font(.system(size: 13))
                        .foregroundColor(AppColors.textSecondary)
                } else {
                    Chart {
                        ForEach(Array(workouts.suffix(20).enumerated()), id: \.offset) { idx, w in
                            BarMark(
                                x: .value("Session", idx),
                                y: .value("Sets", w.totalSets)
                            )
                            .foregroundStyle(AppColors.blue.gradient)
                            .cornerRadius(4)
                        }
                    }
                    .chartXAxis(.hidden)
                    .chartYAxis {
                        AxisMarks { value in
                            AxisGridLine().foregroundStyle(AppColors.cardBorder)
                            AxisValueLabel()
                                .foregroundStyle(AppColors.textSecondary)
                        }
                    }
                    .frame(height: 120)
                    Text("Total sets per session (last \(min(workouts.count, 20)) sessions)")
                        .font(.system(size: 11))
                        .foregroundColor(AppColors.textSecondary)
                }
            }
        }
    }

    // MARK: - Performance Summary

    private var performanceSummaryCard: some View {
        AppCard {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(title: "Performance Summary")

                let workouts = recentLogs.compactMap { $0.workout }.filter { $0.completed }
                let avgRPE = workouts.isEmpty ? 0 : workouts.map(\.perceivedExertion).reduce(0, +) / workouts.count
                let totalDuration = workouts.map(\.durationMinutes).reduce(0, +)
                let avgDuration = workouts.isEmpty ? 0 : totalDuration / workouts.count

                let recoveryLogs = recentLogs.compactMap { $0.recovery }
                let avgSleep = recoveryLogs.isEmpty ? 0.0 : recoveryLogs.map(\.sleepHours).reduce(0, +) / Double(recoveryLogs.count)
                let avgEnergy = recoveryLogs.isEmpty ? 0 : recoveryLogs.map(\.energyScore).reduce(0, +) / recoveryLogs.count

                StatRow(label: "Sessions logged", value: "\(workouts.count)", icon: "dumbbell.fill")
                StatRow(label: "Avg RPE", value: avgRPE == 0 ? "—" : "\(avgRPE)/10", icon: "flame.fill", valueColor: avgRPE >= 8 ? AppColors.orange : AppColors.green)
                StatRow(label: "Avg session duration", value: avgDuration == 0 ? "—" : "\(avgDuration) min", icon: "timer")
                Divider().background(AppColors.cardBorder)
                StatRow(label: "Avg sleep", value: avgSleep == 0 ? "—" : String(format: "%.1fh", avgSleep), icon: "moon.fill", valueColor: avgSleep >= 7 ? AppColors.green : AppColors.orange)
                StatRow(label: "Avg energy score", value: avgEnergy == 0 ? "—" : "\(avgEnergy)/5", icon: "bolt.fill", valueColor: avgEnergy >= 4 ? AppColors.green : AppColors.yellow)
            }
        }
    }

    // MARK: - Helpers

    private func statBadge(label: String, value: String, color: Color) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(color)
            Text(label)
                .font(.system(size: 10))
                .foregroundColor(AppColors.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var periodDays: Int {
        switch selectedPeriod {
        case .week: return 7
        case .month: return 30
        case .quarter: return 90
        }
    }

    private var axisStride: Int {
        switch selectedPeriod {
        case .week: return 1
        case .month: return 7
        case .quarter: return 14
        }
    }

    private func loadData() {
        let ds = DataService(modelContext: modelContext)
        recentLogs = ds.fetchRecentLogs(days: periodDays)
        bodyMetrics = ds.fetchBodyMetrics(days: periodDays)
    }
}
