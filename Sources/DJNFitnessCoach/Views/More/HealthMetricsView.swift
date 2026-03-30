import SwiftUI
import SwiftData

struct HealthMetricsView: View {
    @Environment(\.modelContext) private var modelContext
    @ObservedObject private var healthKit = HealthKitService.shared
    @State private var dataService: DataService?
    @State private var todayLog: DailyLog?
    @State private var weeklyCounters: RuleEngine.WeeklyCounters = .init()
    @State private var recentLogs: [DailyLog] = []
    @State private var showingRecoveryCheck = false

    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.background.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 20) {
                        recoveryCard
                        restingEnergyCard
                        weeklyOverviewCard
                        if healthKit.snapshot.isAvailable {
                            appleHealthCard
                        } else {
                            healthAccessCard
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 24)
                }
            }
            .navigationTitle("Health Metrics")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(AppColors.background, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .sheet(isPresented: $showingRecoveryCheck) {
                if let log = todayLog, let ds = dataService {
                    RecoveryCheckInView(dailyLog: log, dataService: ds) { refreshData() }
                }
            }
        }
        .onAppear { setupAndRefresh() }
    }

    // MARK: - Resting Energy

    private var restingEnergyCard: some View {
        AppCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    SectionHeader(title: "Resting Energy")
                    Spacer()
                    Button {
                        Task { await healthKit.refreshRestingEnergyHistory(force: true) }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 13))
                            .foregroundColor(AppColors.textSecondary)
                    }
                }

                if let median = healthKit.restingEnergyMedian {
                    // Main stat row
                    HStack(alignment: .top, spacing: 0) {
                        VStack(spacing: 3) {
                            Text("\(median)")
                                .font(.system(size: 36, weight: .bold, design: .rounded))
                                .foregroundColor(AppColors.purple)
                            Text("kcal median (30 days)")
                                .font(.system(size: 11))
                                .foregroundColor(AppColors.textSecondary)
                        }
                        .frame(maxWidth: .infinity)

                        VStack(spacing: 3) {
                            let trend = healthKit.restingEnergyTrend
                            Image(systemName: {
                                if case .increasing = trend { return "arrow.up.circle.fill" }
                                if case .decreasing = trend { return "arrow.down.circle.fill" }
                                return "minus.circle.fill"
                            }())
                                .font(.system(size: 28))
                                .foregroundColor({
                                    if case .increasing = trend { return AppColors.orange }
                                    if case .decreasing = trend { return AppColors.red }
                                    return AppColors.green
                                }())
                            Text(trend.symbol)
                                .font(.system(size: 11))
                                .foregroundColor(AppColors.textSecondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                    }

                    // Sparkline — last 30 days (oldest → newest, left → right)
                    if healthKit.restingEnergyHistory.count >= 3 {
                        let history = healthKit.restingEnergyHistory.reversed().map { Double($0) }
                        let minV = history.min() ?? 1800
                        let maxV = history.max() ?? 2100
                        let range = maxV - minV

                        VStack(alignment: .leading, spacing: 4) {
                            Text("30-day history")
                                .font(.system(size: 10))
                                .foregroundColor(AppColors.textSecondary)

                            GeometryReader { geo in
                                let w = geo.size.width
                                let h = geo.size.height
                                let count = history.count
                                let stepX = count > 1 ? w / CGFloat(count - 1) : w

                                ZStack(alignment: .leading) {
                                    // Median reference line
                                    let medianY = range > 0
                                        ? h - CGFloat((Double(median) - minV) / range) * h
                                        : h / 2
                                    Rectangle()
                                        .fill(AppColors.purple.opacity(0.3))
                                        .frame(height: 1)
                                        .offset(y: medianY)

                                    // Bars
                                    HStack(alignment: .bottom, spacing: 1) {
                                        ForEach(Array(history.enumerated()), id: \.offset) { _, val in
                                            let barH = range > 0
                                                ? max(2, CGFloat((val - minV) / range) * h)
                                                : h / 2
                                            RoundedRectangle(cornerRadius: 2)
                                                .fill(AppColors.purple.opacity(0.6))
                                                .frame(width: stepX - 2, height: barH)
                                        }
                                    }
                                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                                }
                            }
                            .frame(height: 60)

                            HStack {
                                Text("30 days ago")
                                Spacer()
                                Text("Today")
                            }
                            .font(.system(size: 9))
                            .foregroundColor(AppColors.textSecondary)
                        }
                    }

                    // Range stats
                    if !healthKit.restingEnergyHistory.isEmpty {
                        let vals = healthKit.restingEnergyHistory
                        HStack(spacing: 0) {
                            statPill(label: "Min", value: "\(vals.min() ?? 0) kcal", color: AppColors.blue)
                            statPill(label: "Median", value: "\(median) kcal", color: AppColors.purple)
                            statPill(label: "Max", value: "\(vals.max() ?? 0) kcal", color: AppColors.orange)
                            statPill(label: "Days", value: "\(vals.count)", color: AppColors.textSecondary)
                        }
                    }

                } else {
                    HStack(spacing: 10) {
                        Image(systemName: "flame.fill").foregroundColor(AppColors.purple).font(.system(size: 18))
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Fetching resting energy history…")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(AppColors.textPrimary)
                            Text("Requires Apple Health access and Apple Watch data")
                                .font(.system(size: 11))
                                .foregroundColor(AppColors.textSecondary)
                        }
                    }
                }
            }
        }
    }

    private func statPill(label: String, value: String, color: Color) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundColor(color)
            Text(label)
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(AppColors.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Recovery

    private var recoveryCard: some View {
        AppCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    SectionHeader(title: "Recovery")
                    Spacer()
                    Button("Check In") { showingRecoveryCheck = true }
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(AppColors.accent)
                }

                if let recovery = todayLog?.recovery {
                    let state = recovery.recoveryState
                    HStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .fill(AppColors.forRecoveryState(state).opacity(0.15))
                                .frame(width: 52, height: 52)
                            Image(systemName: state.icon)
                                .font(.system(size: 22))
                                .foregroundColor(AppColors.forRecoveryState(state))
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            Text(state.rawValue + " Recovery")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(AppColors.textPrimary)
                            HStack(spacing: 12) {
                                miniStat(icon: "moon.fill",  value: String(format: "%.1fh", recovery.sleepHours), color: AppColors.purple)
                                miniStat(icon: "bolt.fill",  value: "\(recovery.energyScore)/5",   color: AppColors.yellow)
                                miniStat(icon: "flame.fill", value: "\(recovery.sorenessScore)/5", color: AppColors.orange)
                                miniStat(icon: "brain.head.profile", value: "\(recovery.motivationScore)/5", color: AppColors.blue)
                            }
                        }
                    }

                    Divider().background(AppColors.cardBorder)

                    // Full recovery stats
                    VStack(spacing: 8) {
                        StatRow(label: "Sleep",              value: String(format: "%.1fh (quality %d/5)", recovery.sleepHours, recovery.sleepQuality), icon: "moon.fill",      valueColor: recovery.sleepHours >= 7 ? AppColors.green : AppColors.orange)
                        StatRow(label: "Energy",             value: "\(recovery.energyScore)/5",    icon: "bolt.fill",            valueColor: recovery.energyScore >= 4 ? AppColors.green : AppColors.orange)
                        StatRow(label: "Soreness",           value: "\(recovery.sorenessScore)/5",  icon: "figure.strengthtraining.traditional", valueColor: recovery.sorenessScore <= 2 ? AppColors.green : AppColors.orange)
                        StatRow(label: "Stress",             value: "\(recovery.stressScore)/5",    icon: "brain",                valueColor: recovery.stressScore <= 2 ? AppColors.green : AppColors.orange)
                        StatRow(label: "Motivation",         value: "\(recovery.motivationScore)/5",icon: "flame.fill",           valueColor: recovery.motivationScore >= 4 ? AppColors.green : AppColors.orange)
                        StatRow(label: "Libido",             value: recovery.libidoStatus.rawValue, icon: "heart.fill",           valueColor: recovery.libidoStatus == .low ? AppColors.red : AppColors.green)
                        StatRow(label: "Perceived Recovery", value: "\(recovery.perceivedRecoveryScore)/10", icon: "gauge.medium", valueColor: recovery.perceivedRecoveryScore >= 7 ? AppColors.green : AppColors.orange)
                        if let rhr = recovery.restingHeartRate {
                            StatRow(label: "Resting HR", value: "\(rhr) bpm", icon: "heart.fill", valueColor: rhr <= 55 ? AppColors.green : rhr <= 65 ? AppColors.yellow : AppColors.red)
                        }
                    }
                } else {
                    HStack {
                        Image(systemName: "questionmark.circle.fill")
                            .foregroundColor(AppColors.textSecondary)
                        Text("No recovery data today — tap Check In")
                            .font(.system(size: 13))
                            .foregroundColor(AppColors.textSecondary)
                        Spacer()
                    }
                }
            }
        }
    }

    private func miniStat(icon: String, value: String, color: Color) -> some View {
        HStack(spacing: 3) {
            Image(systemName: icon).font(.system(size: 10)).foregroundColor(color)
            Text(value).font(.system(size: 12, weight: .medium)).foregroundColor(AppColors.textSecondary)
        }
    }

    // MARK: - Weekly Overview

    private var weeklyOverviewCard: some View {
        AppCard {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(title: "This Week")

                HStack(spacing: 0) {
                    weekStat(value: "\(weeklyCounters.liftingDone)",  label: "Lifts", icon: "dumbbell.fill",  color: AppColors.blue)
                    Divider().frame(height: 40).background(AppColors.cardBorder)
                    weekStat(value: "\(weeklyCounters.vo2Done)",      label: "VO2",  icon: "lungs.fill",      color: AppColors.orange)
                    Divider().frame(height: 40).background(AppColors.cardBorder)
                    weekStat(value: "\(weeklyCounters.norwegianDone)", label: "4×4",  icon: "bolt.fill",       color: AppColors.red)
                    Divider().frame(height: 40).background(AppColors.cardBorder)
                    weekStat(value: "\(weeklyCounters.zone2Done)",    label: "Zone 2", icon: "heart.fill",    color: AppColors.green)
                }

                weekCalendarStrip
            }
        }
    }

    private func weekStat(value: String, label: String, icon: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon).font(.system(size: 14)).foregroundColor(color)
            Text(value)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(AppColors.textPrimary)
            Text(label).font(.system(size: 10, weight: .medium)).foregroundColor(AppColors.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var weekCalendarStrip: some View {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let weekStart = calendar.dateInterval(of: .weekOfYear, for: today)?.start ?? today
        let days = (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: weekStart) }
        let dayLetters = ["M","T","W","T","F","S","S"]

        return HStack(spacing: 4) {
            ForEach(Array(days.enumerated()), id: \.offset) { idx, day in
                let isToday = calendar.isDate(day, inSameDayAs: today)
                let log = dataService?.fetchLog(for: day)
                let sessionColor = sessionColorForLog(log)
                VStack(spacing: 4) {
                    Text(dayLetters[idx]).font(.system(size: 10, weight: .medium)).foregroundColor(AppColors.textSecondary)
                    ZStack {
                        Circle().fill(isToday ? AppColors.accent.opacity(0.2) : Color.clear).frame(width: 28, height: 28)
                        if let color = sessionColor {
                            Circle().fill(color).frame(width: 22, height: 22)
                        } else {
                            Circle().strokeBorder(isToday ? AppColors.accent : AppColors.cardBorder, lineWidth: 1.5).frame(width: 22, height: 22)
                        }
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    private func sessionColorForLog(_ log: DailyLog?) -> Color? {
        guard let log else { return nil }
        if log.workout?.completed == true { return AppColors.blue }
        if let cardio = log.cardio, cardio.completed { return AppColors.forSessionType(cardio.type) }
        return nil
    }

    // MARK: - Apple Health

    private var appleHealthCard: some View {
        let h = healthKit.snapshot
        return AppCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    SectionHeader(title: "Apple Health")
                    Spacer()
                    Button {
                        Task { await healthKit.refreshSnapshot() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 13))
                            .foregroundColor(AppColors.textSecondary)
                    }
                }

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    if let rhr = h.restingHR {
                        healthMetric(value: "\(Int(rhr))", unit: "bpm", label: "Resting HR", icon: "heart.fill",
                                     color: rhr <= 55 ? AppColors.green : rhr <= 65 ? AppColors.yellow : AppColors.red)
                    }
                    if let hrv = h.hrv {
                        healthMetric(value: "\(Int(hrv))", unit: "ms", label: "HRV", icon: "waveform.path.ecg",
                                     color: hrv >= 50 ? AppColors.green : hrv >= 30 ? AppColors.yellow : AppColors.red)
                    }
                    if let sleep = h.sleepHours {
                        healthMetric(value: String(format: "%.1f", sleep), unit: "h", label: "Sleep", icon: "moon.fill",
                                     color: sleep >= 7 ? AppColors.green : sleep >= 6 ? AppColors.yellow : AppColors.red)
                    }
                    if let steps = h.steps {
                        healthMetric(value: steps >= 1000 ? "\(steps / 1000).\((steps % 1000) / 100)k" : "\(steps)",
                                     unit: "", label: "Steps", icon: "figure.walk",
                                     color: steps >= 8000 ? AppColors.green : AppColors.textSecondary)
                    }
                    if let vo2 = h.vo2Max {
                        healthMetric(value: String(format: "%.0f", vo2), unit: "mL/kg", label: "VO2 Max", icon: "lungs.fill",
                                     color: vo2 >= 50 ? AppColors.green : vo2 >= 40 ? AppColors.yellow : AppColors.red)
                    }
                    if let cals = h.activeCalories {
                        healthMetric(value: "\(cals)", unit: "kcal", label: "Active", icon: "flame.fill", color: AppColors.orange)
                    }
                    if let w = h.bodyWeight {
                        healthMetric(value: String(format: "%.1f", w), unit: "kg", label: "Weight", icon: "scalemass.fill", color: AppColors.blue)
                    }
                    if let bf = h.bodyFat {
                        healthMetric(value: String(format: "%.1f", bf), unit: "%", label: "Body Fat", icon: "figure.arms.open",
                                     color: bf <= 11 ? AppColors.green : AppColors.orange)
                    }
                }
            }
        }
    }

    private var healthAccessCard: some View {
        AppCard {
            HStack(spacing: 12) {
                Image(systemName: "heart.text.square.fill").font(.system(size: 22)).foregroundColor(AppColors.red)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Apple Health").font(.system(size: 14, weight: .semibold)).foregroundColor(AppColors.textPrimary)
                    Text("Grant Health access to see HR, HRV, sleep, steps, VO2 max").font(.system(size: 12)).foregroundColor(AppColors.textSecondary)
                }
                Spacer()
                Button {
                    Task { await healthKit.requestAuthorization() }
                } label: {
                    Text("Enable").font(.system(size: 12, weight: .semibold)).foregroundColor(AppColors.red)
                }
            }
        }
    }

    private func healthMetric(value: String, unit: String, label: String, icon: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon).font(.system(size: 16)).foregroundColor(color)
            HStack(alignment: .lastTextBaseline, spacing: 2) {
                Text(value).font(.system(size: 18, weight: .bold, design: .rounded)).foregroundColor(AppColors.textPrimary)
                if !unit.isEmpty {
                    Text(unit).font(.system(size: 10, weight: .medium)).foregroundColor(AppColors.textSecondary)
                }
            }
            Text(label).font(.system(size: 10, weight: .medium)).foregroundColor(AppColors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(color.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Setup

    private func setupAndRefresh() {
        let ds = DataService(modelContext: modelContext)
        dataService = ds
        refreshData()
    }

    private func refreshData() {
        guard let ds = dataService else { return }
        todayLog = ds.fetchOrCreateTodayLog()
        let weekLogs = ds.fetchLogsForCurrentWeek()
        weeklyCounters = RuleEngine.buildWeeklyCounters(from: weekLogs)
        recentLogs = ds.fetchRecentLogs(days: 7)
    }
}
