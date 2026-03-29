import SwiftUI
import SwiftData

struct DashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var dataService: DataService?
    @State private var todayLog: DailyLog?
    @State private var recommendation: RuleEngine.SessionRecommendation?
    @State private var weeklyCounters: RuleEngine.WeeklyCounters = .init()
    @State private var showingRecoveryCheck = false
    @State private var showingBodyMetric = false
    @State private var currentDate = Date()

    private let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEEE, d MMM"
        return f
    }()

    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.background.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 20) {
                        headerSection
                        if let rec = recommendation {
                            recommendationCard(rec)
                        }
                        weeklyOverviewCard
                        recoverySnapshotCard
                        quickActionsCard
                        nutritionSnapshotCard
                        supplementSnapshotCard
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 24)
                }
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showingRecoveryCheck) {
                if let log = todayLog, let ds = dataService {
                    RecoveryCheckInView(dailyLog: log, dataService: ds) {
                        refreshData()
                    }
                }
            }
            .sheet(isPresented: $showingBodyMetric) {
                if let ds = dataService {
                    BodyMetricEntryView(dataService: ds)
                }
            }
        }
        .onAppear { setupAndRefresh() }
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text("DJN Coach")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(AppColors.textPrimary)
                Text(dateFormatter.string(from: currentDate))
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(AppColors.textSecondary)
            }
            Spacer()
            Button {
                showingBodyMetric = true
            } label: {
                Image(systemName: "scalemass.fill")
                    .font(.system(size: 20))
                    .foregroundColor(AppColors.textSecondary)
                    .frame(width: 40, height: 40)
                    .background(AppColors.cardBackground)
                    .clipShape(Circle())
            }
        }
    }

    // MARK: - Recommendation Card

    private func recommendationCard(_ rec: RuleEngine.SessionRecommendation) -> some View {
        AppCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("TODAY")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(AppColors.textSecondary)
                        .tracking(1.2)
                    Spacer()
                    if rec.volumeModifier < 1.0 {
                        Label("Adjusted", systemImage: "arrow.down.circle.fill")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(AppColors.yellow)
                    }
                }

                HStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(AppColors.forSessionType(rec.sessionType).opacity(0.15))
                            .frame(width: 56, height: 56)
                        Image(systemName: rec.sessionType.icon)
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundColor(AppColors.forSessionType(rec.sessionType))
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text(rec.sessionType.rawValue)
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundColor(AppColors.textPrimary)
                        Text(rec.reason)
                            .font(.system(size: 13))
                            .foregroundColor(AppColors.textSecondary)
                            .lineLimit(2)
                    }
                }

                if !rec.cardioNotes.isEmpty {
                    ForEach(rec.cardioNotes, id: \.self) { note in
                        Label(note, systemImage: "info.circle.fill")
                            .font(.system(size: 12))
                            .foregroundColor(AppColors.yellow)
                    }
                }

                if !rec.nutritionAlerts.isEmpty {
                    ForEach(rec.nutritionAlerts, id: \.self) { alert in
                        Label(alert, systemImage: "bolt.fill")
                            .font(.system(size: 12))
                            .foregroundColor(AppColors.orange)
                    }
                }

                if rec.volumeModifier < 1.0 {
                    HStack {
                        Image(systemName: "chart.bar.fill")
                            .font(.system(size: 12))
                            .foregroundColor(AppColors.yellow)
                        Text("Volume reduced to \(Int(rec.volumeModifier * 100))% • Failure sets \(rec.allowFailureSets ? "allowed" : "disabled")")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(AppColors.yellow)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(AppColors.yellow.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
        }
    }

    // MARK: - Weekly Overview

    private var weeklyOverviewCard: some View {
        AppCard {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(title: "This Week")
                HStack(spacing: 0) {
                    weekStat(value: "\(weeklyCounters.liftingDone)", label: "Lifts", icon: "dumbbell.fill", color: AppColors.blue)
                    Divider().frame(height: 40).background(AppColors.cardBorder)
                    weekStat(value: "\(weeklyCounters.vo2Done)", label: "VO2", icon: "lungs.fill", color: AppColors.orange)
                    Divider().frame(height: 40).background(AppColors.cardBorder)
                    weekStat(value: "\(weeklyCounters.norwegianDone)", label: "4x4", icon: "bolt.fill", color: AppColors.red)
                    Divider().frame(height: 40).background(AppColors.cardBorder)
                    weekStat(value: "\(weeklyCounters.zone2Done)", label: "Z2", icon: "heart.fill", color: AppColors.green)
                }

                // Weekly calendar strip
                weekCalendarStrip
            }
        }
    }

    private func weekStat(value: String, label: String, icon: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(color)
            Text(value)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(AppColors.textPrimary)
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(AppColors.textSecondary)
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
                    Text(dayLetters[idx])
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(AppColors.textSecondary)
                    ZStack {
                        Circle()
                            .fill(isToday ? AppColors.accent.opacity(0.2) : Color.clear)
                            .frame(width: 28, height: 28)
                        if let color = sessionColor {
                            Circle()
                                .fill(color)
                                .frame(width: 22, height: 22)
                        } else {
                            Circle()
                                .strokeBorder(isToday ? AppColors.accent : AppColors.cardBorder, lineWidth: 1.5)
                                .frame(width: 22, height: 22)
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

    // MARK: - Recovery Snapshot

    private var recoverySnapshotCard: some View {
        AppCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    SectionHeader(title: "Recovery")
                    Spacer()
                    Button("Check In") {
                        showingRecoveryCheck = true
                    }
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(AppColors.accent)
                }

                if let recovery = todayLog?.recovery {
                    HStack(spacing: 16) {
                        let state = recovery.recoveryState
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
                                miniStat(icon: "moon.fill", value: String(format: "%.1fh", recovery.sleepHours), color: AppColors.purple)
                                miniStat(icon: "bolt.fill", value: "\(recovery.energyScore)/5", color: AppColors.yellow)
                                miniStat(icon: "flame.fill", value: "\(recovery.sorenessScore)/5", color: AppColors.orange)
                            }
                        }
                    }
                } else {
                    HStack {
                        Image(systemName: "questionmark.circle.fill")
                            .foregroundColor(AppColors.textSecondary)
                        Text("No recovery data yet — tap Check In")
                            .font(.system(size: 13))
                            .foregroundColor(AppColors.textSecondary)
                    }
                }
            }
        }
    }

    private func miniStat(icon: String, value: String, color: Color) -> some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 10))
                .foregroundColor(color)
            Text(value)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(AppColors.textSecondary)
        }
    }

    // MARK: - Quick Actions

    private var quickActionsCard: some View {
        HStack(spacing: 12) {
            NavigationLink(destination: WorkoutLogView()) {
                quickAction(icon: "dumbbell.fill", label: "Log Lift", color: AppColors.blue)
            }
            NavigationLink(destination: CardioLogView()) {
                quickAction(icon: "figure.run", label: "Log Cardio", color: AppColors.orange)
            }
        }
    }

    private func quickAction(icon: String, label: String, color: Color) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(color)
            Text(label)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(AppColors.textPrimary)
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(AppColors.textSecondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(AppColors.cardBorder, lineWidth: 0.5))
    }

    // MARK: - Nutrition Snapshot

    private var nutritionSnapshotCard: some View {
        AppCard {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(title: "Nutrition Today")
                if let nutrition = todayLog?.nutrition {
                    HStack(spacing: 16) {
                        MacroRingView(
                            label: "Protein",
                            current: nutrition.proteinG,
                            target: Double(UserProfile.proteinMin)...Double(UserProfile.proteinMax),
                            color: AppColors.blue,
                            unit: "g"
                        )
                        MacroRingView(
                            label: "Carbs",
                            current: nutrition.carbsG,
                            target: Double(UserProfile.carbsMin)...Double(UserProfile.carbsMax),
                            color: AppColors.orange,
                            unit: "g"
                        )
                        MacroRingView(
                            label: "Fats",
                            current: nutrition.fatG,
                            target: Double(UserProfile.fatMin)...Double(UserProfile.fatMax),
                            color: AppColors.yellow,
                            unit: "g"
                        )
                        MacroRingView(
                            label: "Kcal",
                            current: Double(nutrition.calories),
                            target: Double(UserProfile.caloriesMin)...Double(UserProfile.caloriesMax),
                            color: AppColors.green,
                            unit: "kcal"
                        )
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                } else {
                    Text("No nutrition logged yet")
                        .font(.system(size: 13))
                        .foregroundColor(AppColors.textSecondary)
                }
            }
        }
    }

    // MARK: - Supplement Snapshot

    private var supplementSnapshotCard: some View {
        AppCard {
            VStack(alignment: .leading, spacing: 10) {
                SectionHeader(title: "Supplements")
                if let supps = todayLog?.supplements {
                    let pct = supps.completionPercentage
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .stroke(AppColors.cardBorder, lineWidth: 4)
                                .frame(width: 44, height: 44)
                            Circle()
                                .trim(from: 0, to: pct)
                                .stroke(pct > 0.8 ? AppColors.green : AppColors.orange, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                                .rotationEffect(.degrees(-90))
                                .frame(width: 44, height: 44)
                                .animation(.easeInOut, value: pct)
                            Text("\(Int(pct * 100))%")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(AppColors.textPrimary)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(supps.dailyCompletionCount) of \(supps.dailyTotalCount) daily taken")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(AppColors.textPrimary)
                            if supps.isAlternateDay {
                                Text("+ Alternate day: \(supps.alternateDayCompletionCount)/2")
                                    .font(.system(size: 12))
                                    .foregroundColor(AppColors.textSecondary)
                            }
                        }
                        Spacer()
                    }
                } else {
                    Text("Loading supplements...")
                        .font(.system(size: 13))
                        .foregroundColor(AppColors.textSecondary)
                }
            }
        }
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
        recommendation = ds.buildTodayRecommendation()
        let weekLogs = ds.fetchLogsForCurrentWeek()
        weeklyCounters = RuleEngine.buildWeeklyCounters(from: weekLogs)
        ds.save()
    }
}
