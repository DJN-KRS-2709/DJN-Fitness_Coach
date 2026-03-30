import SwiftUI
import SwiftData

struct DashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @ObservedObject private var healthKit = HealthKitService.shared
    @State private var dataService: DataService?
    @State private var todayLog: DailyLog?
    @State private var recommendation: RuleEngine.SessionRecommendation?
    @State private var weeklyCounters: RuleEngine.WeeklyCounters = .init()
    @State private var showingWorkoutLog = false
    @State private var showingCardioLog = false
    @State private var showingCardioPicker = false
    @State private var selectedCardioType: SessionType = .cardioVO2
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
                        todayCard
                        energyAndMacrosCard
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 24)
                }
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showingWorkoutLog) {
                WorkoutLogView(planSets: WorkoutPlanService.shared.templateSets())
            }
            .sheet(isPresented: $showingCardioLog) {
                CardioLogView(initialType: selectedCardioType)
            }
            .sheet(isPresented: $showingCardioPicker) {
                cardioPickerSheet
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
            Button { showingBodyMetric = true } label: {
                Image(systemName: "scalemass.fill")
                    .font(.system(size: 20))
                    .foregroundColor(AppColors.textSecondary)
                    .frame(width: 40, height: 40)
                    .background(AppColors.cardBackground)
                    .clipShape(Circle())
            }
        }
    }

    // MARK: - Today Card

    private var todayCard: some View {
        let todayDone = isTodayDone
        let rec = recommendation

        return AppCard {
            VStack(alignment: .leading, spacing: 16) {

                // Label row
                HStack {
                    Text("TODAY")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(AppColors.textSecondary)
                        .tracking(1.2)
                    Spacer()
                    if todayDone {
                        Label("Done", systemImage: "checkmark.circle.fill")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(AppColors.green)
                    } else if let r = rec, r.volumeModifier < 1.0 {
                        Label("Volume adjusted", systemImage: "arrow.down.circle.fill")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(AppColors.yellow)
                    }
                }

                // Session type + action
                if let r = rec {
                    if todayDone {
                        todayDoneRow(r)
                    } else {
                        todayActionRow(r)
                    }
                } else {
                    HStack(spacing: 12) {
                        Circle()
                            .fill(AppColors.cardBorder.opacity(0.5))
                            .frame(width: 52, height: 52)
                        Text("Loading…")
                            .font(.system(size: 16))
                            .foregroundColor(AppColors.textSecondary)
                    }
                }

                // Tomorrow hint
                if let tomorrow = tomorrowLabel {
                    Divider().background(AppColors.cardBorder)
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 6) {
                            Text("Tomorrow")
                                .font(.system(size: 12))
                                .foregroundColor(AppColors.textSecondary)
                            Text("→")
                                .foregroundColor(AppColors.textSecondary)
                            Text(tomorrow)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(AppColors.textPrimary)
                            if tomorrow == "Lifting", WorkoutPlanService.shared.isActive {
                                Text("· \(WorkoutPlanService.shared.weekLabel)")
                                    .font(.system(size: 11))
                                    .foregroundColor(AppColors.purple)
                            }
                            Spacer()
                            if tomorrow == "Lifting" {
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(AppColors.blue)
                            }
                        }
                        if tomorrow == "Lifting" {
                            Button {
                                showingWorkoutLog = true
                            } label: {
                                tomorrowLiftingPlanPreview
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }

    private func todayActionRow(_ rec: RuleEngine.SessionRecommendation) -> some View {
        let color = AppColors.forSessionType(rec.sessionType)
        let isLifting = rec.sessionType == .lifting

        return Button {
            if isLifting {
                showingWorkoutLog = true
            } else {
                selectedCardioType = rec.sessionType.isCardio ? rec.sessionType : .cardioVO2
                showingCardioPicker = true
            }
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(color.opacity(0.15))
                            .frame(width: 56, height: 56)
                        Image(systemName: rec.sessionType.icon)
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundColor(color)
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
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(color)
                }

                if !rec.cardioNotes.isEmpty {
                    ForEach(rec.cardioNotes, id: \.self) { note in
                        Label(note, systemImage: "info.circle.fill")
                            .font(.system(size: 12))
                            .foregroundColor(AppColors.yellow)
                    }
                }

                if rec.volumeModifier < 1.0 {
                    HStack {
                        Image(systemName: "chart.bar.fill")
                            .font(.system(size: 11))
                            .foregroundColor(AppColors.yellow)
                        Text("Volume \(Int(rec.volumeModifier * 100))% · Failure \(rec.allowFailureSets ? "allowed" : "off")")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(AppColors.yellow)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(AppColors.yellow.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }

                // CTA button
                HStack {
                    Image(systemName: isLifting ? "dumbbell.fill" : "figure.run")
                        .font(.system(size: 13, weight: .semibold))
                    Text(isLifting ? "Start Lifting Session" : "Select Cardio Type")
                        .font(.system(size: 14, weight: .bold))
                }
                .foregroundColor(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(color)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .buttonStyle(.plain)
    }

    private func todayDoneRow(_ rec: RuleEngine.SessionRecommendation) -> some View {
        // Use what was ACTUALLY completed, not the recommendation
        let actualType: SessionType
        let subtitle: String
        if let c = todayLog?.cardio, c.completed {
            actualType = c.type
            subtitle = "\(c.type.rawValue) · \(c.durationMinutes) min"
        } else if let w = todayLog?.workout, w.completed {
            actualType = .lifting
            subtitle = "\(w.totalSets) sets · \(w.durationMinutes) min · RPE \(w.perceivedExertion)"
        } else {
            actualType = rec.sessionType
            subtitle = ""
        }
        let color = AppColors.forSessionType(actualType)

        return HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.12))
                    .frame(width: 52, height: 52)
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 24))
                    .foregroundColor(AppColors.green)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(actualType.rawValue + " completed")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundColor(AppColors.textPrimary)
                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.system(size: 13))
                        .foregroundColor(AppColors.textSecondary)
                }
            }
            Spacer()
        }
    }

    // MARK: - Tomorrow Lifting Plan Preview

    private var tomorrowLiftingPlanPreview: some View {
        let svc = WorkoutPlanService.shared
        let phase = svc.currentPhase
        let exercises = WorkoutPlan.exercises

        return VStack(alignment: .leading, spacing: 6) {
            ForEach(MuscleGroup.allCases, id: \.self) { muscle in
                let group = exercises.filter { $0.muscleGroup == muscle }
                if !group.isEmpty {
                    HStack(spacing: 6) {
                        Text(muscle.rawValue.uppercased())
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(AppColors.blue)
                            .tracking(0.5)
                            .frame(width: 60, alignment: .leading)
                        Text(group.map { ex in
                            let reps = phase == 1 ? ex.repsPhase1 : ex.repsPhase2
                            return "\(ex.setCount)×\(reps) \(ex.exerciseName)"
                        }.joined(separator: "  ·  "))
                            .font(.system(size: 11))
                            .foregroundColor(AppColors.textSecondary)
                            .lineLimit(1)
                    }
                }
            }
        }
        .padding(10)
        .background(AppColors.blue.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Cardio Picker Sheet

    private var cardioPickerSheet: some View {
        NavigationStack {
            ZStack {
                AppColors.background.ignoresSafeArea()
                VStack(spacing: 12) {
                    Text("Select Cardio Type")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(AppColors.textPrimary)
                        .padding(.top, 8)

                    ForEach([SessionType.cardioVO2, .cardioNorwegian, .cardioZone2], id: \.self) { type in
                        Button {
                            selectedCardioType = type
                            showingCardioPicker = false
                            showingCardioLog = true
                        } label: {
                            cardioTypeButton(type)
                        }
                    }

                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showingCardioPicker = false }
                        .foregroundColor(AppColors.textSecondary)
                }
            }
        }
        .presentationDetents([.medium])
        .presentationBackground(AppColors.background)
    }

    private func cardioTypeButton(_ type: SessionType) -> some View {
        let color = AppColors.forSessionType(type)
        let isRecommended = recommendation?.sessionType == type
        let desc: String
        switch type {
        case .cardioVO2:       desc = "~45 min · 85–95% HR max · running"
        case .cardioNorwegian: desc = "4×4 min intervals · max once/week"
        case .cardioZone2:     desc = "~45 min · conversational pace · fat burn"
        default:               desc = ""
        }

        return HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(color.opacity(0.15))
                    .frame(width: 52, height: 52)
                Image(systemName: type.icon)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(color)
            }
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(type.rawValue)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(AppColors.textPrimary)
                    if isRecommended {
                        Text("Recommended")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.black)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(color)
                            .clipShape(Capsule())
                    }
                }
                Text(desc)
                    .font(.system(size: 12))
                    .foregroundColor(AppColors.textSecondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(AppColors.textSecondary)
        }
        .padding(14)
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(
            isRecommended ? color.opacity(0.5) : AppColors.cardBorder,
            lineWidth: isRecommended ? 1.5 : 0.5
        ))
    }

    // MARK: - Energy + Macros Card

    private var energyAndMacrosCard: some View {
        let nutrition = todayLog?.nutrition
        let consumed = nutrition?.calories ?? 0

        // Prefer 30-day HealthKit median, then today's reading, then Mifflin-St Jeor estimate
        let restingSource: RestingSource
        let basal: Int
        if let median = healthKit.restingEnergyMedian {
            basal = median
            restingSource = .healthKitMedian
        } else if let todayBasal = healthKit.snapshot.basalCalories {
            basal = todayBasal
            restingSource = .healthKitToday
        } else {
            basal = estimatedBMR
            restingSource = .estimated
        }
        let active  = healthKit.snapshot.activeCalories ?? 0

        let totalBurn = basal + active
        let balance   = consumed - totalBurn

        return AppCard {
            VStack(alignment: .leading, spacing: 18) {

                SectionHeader(title: "Energy Balance")

                // Main three-column row
                HStack(alignment: .top, spacing: 0) {
                    energyStat(
                        value: "\(consumed)",
                        label: "consumed",
                        color: AppColors.green
                    )
                    energyStat(
                        value: "\(basal)",
                        label: restingSource == .healthKitMedian ? "resting (30d)" :
                               restingSource == .healthKitToday  ? "resting (today)" : "resting*",
                        color: AppColors.purple
                    )
                    energyStat(
                        value: "+\(active)",
                        label: "activity",
                        color: AppColors.orange
                    )
                    energyStat(
                        value: balance >= 0 ? "+\(balance)" : "\(balance)",
                        label: balance >= 0 ? "surplus" : "deficit",
                        color: abs(balance) <= 300 ? AppColors.green : balance > 300 ? AppColors.orange : AppColors.red
                    )
                }

                // Calorie progress bar (consumed vs total burn)
                if totalBurn > 0 {
                    let progress = min(Double(consumed) / Double(totalBurn), 1.5)
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 4).fill(AppColors.cardBorder).frame(height: 8)
                            RoundedRectangle(cornerRadius: 4)
                                .fill(consumed > totalBurn ? AppColors.orange : AppColors.green)
                                .frame(width: geo.size.width * min(progress, 1.0), height: 8)
                                .animation(.easeInOut(duration: 0.6), value: progress)
                        }
                    }
                    .frame(height: 8)
                    if restingSource == .estimated {
                        Text("* Resting calories estimated (BMR). Grant Health access for accurate data.")
                            .font(.system(size: 10))
                            .foregroundColor(AppColors.textSecondary)
                            .italic()
                    } else if restingSource == .healthKitMedian {
                        let trend = healthKit.restingEnergyTrend
                        if trend != .stable {
                            HStack(spacing: 4) {
                                Image(systemName: {
                                    if case .increasing = trend { return "arrow.up.circle.fill" }
                                    return "arrow.down.circle.fill"
                                }())
                                    .font(.system(size: 10))
                                    .foregroundColor({
                                        if case .increasing = trend { return AppColors.orange }
                                        return AppColors.red
                                    }())
                                Text(trend.symbol)
                                    .font(.system(size: 10))
                                    .foregroundColor(AppColors.textSecondary)
                                    .italic()
                            }
                        }
                    }
                }

                Divider().background(AppColors.cardBorder)

                // Macro breakdown
                SectionHeader(title: "Macros")

                VStack(spacing: 10) {
                    macroBar(
                        label: "Protein",
                        value: nutrition?.proteinG ?? 0,
                        low: Double(UserProfile.proteinMin),
                        high: Double(UserProfile.proteinMax),
                        unit: "g",
                        color: AppColors.blue
                    )
                    macroBar(
                        label: "Carbs",
                        value: nutrition?.carbsG ?? 0,
                        low: Double(UserProfile.carbsMin),
                        high: Double(UserProfile.carbsMax),
                        unit: "g",
                        color: AppColors.orange
                    )
                    macroBar(
                        label: "Fat",
                        value: nutrition?.fatG ?? 0,
                        low: Double(UserProfile.fatMin),
                        high: Double(UserProfile.fatMax),
                        unit: "g",
                        color: AppColors.yellow
                    )
                }

                if nutrition == nil {
                    Text("No nutrition logged today — tap Nutrition in the tab bar.")
                        .font(.system(size: 12))
                        .foregroundColor(AppColors.textSecondary)
                }
            }
        }
    }

    private func energyStat(value: String, label: String, color: Color) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundColor(color)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(AppColors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    private func macroBar(label: String, value: Double, low: Double, high: Double, unit: String, color: Color) -> some View {
        let progress = high > 0 ? Swift.min(value / high, 1.2) : 0
        let inRange   = value >= low && value <= high
        let statusColor = inRange ? AppColors.green : (value < low ? AppColors.orange : AppColors.red)

        return HStack(spacing: 10) {
            Text(label)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(AppColors.textSecondary)
                .frame(width: 52, alignment: .leading)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4).fill(AppColors.cardBorder).frame(height: 8)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(color.opacity(0.8))
                        .frame(width: geo.size.width * Swift.min(progress, 1.0), height: 8)
                        .animation(.easeInOut(duration: 0.5), value: progress)
                }
            }
            .frame(height: 8)

            HStack(spacing: 2) {
                Text("\(Int(value))\(unit)")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor(AppColors.textPrimary)
                Image(systemName: inRange ? "checkmark.circle.fill" : (value < low ? "arrow.up.circle.fill" : "exclamationmark.circle.fill"))
                    .font(.system(size: 10))
                    .foregroundColor(statusColor)
            }
            .frame(width: 62, alignment: .trailing)
        }
    }

    // MARK: - Helpers

    private var isTodayDone: Bool {
        todayLog?.workout?.completed == true || todayLog?.cardio?.completed == true
    }

    private var tomorrowLabel: String? {
        // Base on what was ACTUALLY completed today (most accurate)
        if let c = todayLog?.cardio, c.completed {
            return "Lifting"
        }
        if let w = todayLog?.workout, w.completed {
            return "Cardio"
        }
        // Nothing done yet — opposite of today's recommendation
        guard let rec = recommendation else { return nil }
        return rec.sessionType.isCardio ? "Lifting" : "Cardio"
    }

    private enum RestingSource {
        case healthKitMedian   // 30-day median from HealthKit ← best
        case healthKitToday    // today's partial reading
        case estimated         // Mifflin-St Jeor fallback
    }

    /// Mifflin-St Jeor BMR estimate for fixed profile
    private var estimatedBMR: Int {
        Int(10 * UserProfile.weightKg + 6.25 * UserProfile.heightCm - 5 * Double(UserProfile.age) + 5)
    }

    // MARK: - Setup

    private func setupAndRefresh() {
        let ds = DataService(modelContext: modelContext)
        dataService = ds
        refreshData()
        Task { await healthKit.requestAuthorization() }
    }

    private func refreshData() {
        guard let ds = dataService else { return }
        let log = ds.fetchOrCreateTodayLog()
        todayLog = log

        let nutrition = ds.fetchOrCreateNutritionLog(for: log)
        if nutrition.calories == 0 { autoFillNutrition(nutrition) }

        recommendation = ds.buildTodayRecommendation()
        let weekLogs = ds.fetchLogsForCurrentWeek()
        weeklyCounters = RuleEngine.buildWeeklyCounters(from: weekLogs)
        ds.save()
    }

    private func autoFillNutrition(_ n: NutritionLog) {
        if n.quarkG == 0      { n.quarkG = 500 }
        if n.wheyG == 0       { n.wheyG = 50 }
        if n.clearWheyG == 0  { n.clearWheyG = 40 }
        if n.caseinG == 0     { n.caseinG = 50 }
        if n.collagenG == 0   { n.collagenG = 20 }
        if n.proteinMilkMl == 0 { n.proteinMilkMl = 333 }
        if n.beefOrChickenG == 0 { n.beefOrChickenG = 200 }
        if n.eggsCount == 0   { n.eggsCount = 2 }
        if n.riceDryG == 0    { n.riceDryG = 200 }
        if n.fruitPortions == 0 { n.fruitPortions = 1 }
        if n.dates == 0       { n.dates = 1 }
        if n.darkChocolateG == 0 { n.darkChocolateG = 20 }
        if n.vegetablesG == 0 { n.vegetablesG = 350 }
        if n.flatWhitesCount == 0 { n.flatWhitesCount = 3 }
        if n.sodiumMg == 0    { n.sodiumMg = 2500 }
        if n.hydrationL == 0  { n.hydrationL = 3.0 }
        n.walnutsIncluded = true

        var protein = 0.0; var carbs = 0.0; var fat = 0.0; var kcal = 0.0
        protein += n.quarkG * 0.11; carbs += n.quarkG * 0.04; fat += n.quarkG * 0.002; kcal += n.quarkG * 0.63
        protein += (n.wheyG / 30) * 25; carbs += (n.wheyG / 30) * 2; fat += (n.wheyG / 30) * 1.5; kcal += (n.wheyG / 30) * 120
        protein += (n.clearWheyG / 34) * 22; carbs += (n.clearWheyG / 34) * 3; kcal += (n.clearWheyG / 34) * 100
        protein += (n.caseinG / 30) * 24; carbs += (n.caseinG / 30) * 3; fat += (n.caseinG / 30) * 1; kcal += (n.caseinG / 30) * 116
        protein += n.beefOrChickenG * 0.26; fat += n.beefOrChickenG * 0.04; kcal += n.beefOrChickenG * 1.45
        protein += Double(n.eggsCount) * 6; carbs += Double(n.eggsCount) * 0.6; fat += Double(n.eggsCount) * 5; kcal += Double(n.eggsCount) * 70
        protein += n.riceDryG * 0.07; carbs += n.riceDryG * 0.78; fat += n.riceDryG * 0.007; kcal += n.riceDryG * 3.5
        carbs += Double(n.fruitPortions) * 20; kcal += Double(n.fruitPortions) * 80
        carbs += Double(n.dates) * 18; protein += Double(n.dates) * 0.2; kcal += Double(n.dates) * 72
        protein += n.darkChocolateG * 0.1; carbs += n.darkChocolateG * 0.6; fat += n.darkChocolateG * 0.45; kcal += n.darkChocolateG * 5.4
        protein += n.vegetablesG * 0.02; carbs += n.vegetablesG * 0.07; fat += n.vegetablesG * 0.003; kcal += n.vegetablesG * 0.35
        protein += Double(n.flatWhitesCount) * 1.5; carbs += Double(n.flatWhitesCount) * 8; fat += Double(n.flatWhitesCount) * 1.5; kcal += Double(n.flatWhitesCount) * 52
        protein += 3.2; carbs += 2.4; fat += 15.8; kcal += 161
        n.proteinG = protein; n.carbsG = carbs; n.fatG = fat; n.calories = Int(kcal)
    }
}
