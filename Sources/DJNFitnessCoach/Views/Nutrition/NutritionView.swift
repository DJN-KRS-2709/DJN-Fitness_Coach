import SwiftUI
import SwiftData

struct NutritionView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var todayLog: DailyLog?
    @State private var nutrition: NutritionLog?
    @State private var dataService: DataService?

    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.background.ignoresSafeArea()
                if let n = nutrition {
                    ScrollView {
                        VStack(spacing: 20) {
                            macroSummaryCard(n)
                            foodChecklistCard(n)
                            mealTimingCard(n)
                            targetsReferenceCard
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                        .padding(.bottom, 24)
                    }
                } else {
                    ProgressView()
                        .tint(AppColors.accent)
                }
            }
            .navigationTitle("Nutrition")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(AppColors.background, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { dataService?.save() }
                        .foregroundColor(AppColors.orange)
                }
            }
        }
        .onAppear { setup() }
    }

    // MARK: - Macro Summary

    private func macroSummaryCard(_ n: NutritionLog) -> some View {
        AppCard {
            VStack(spacing: 16) {
                SectionHeader(title: "Daily Macros")

                HStack(spacing: 12) {
                    MacroRingView(
                        label: "Protein",
                        current: n.proteinG,
                        target: Double(UserProfile.proteinMin)...Double(UserProfile.proteinMax),
                        color: AppColors.blue, unit: "g"
                    )
                    MacroRingView(
                        label: "Carbs",
                        current: n.carbsG,
                        target: Double(UserProfile.carbsMin)...Double(UserProfile.carbsMax),
                        color: AppColors.orange, unit: "g"
                    )
                    MacroRingView(
                        label: "Fat",
                        current: n.fatG,
                        target: Double(UserProfile.fatMin)...Double(UserProfile.fatMax),
                        color: AppColors.yellow, unit: "g"
                    )
                    MacroRingView(
                        label: "Kcal",
                        current: Double(n.calories),
                        target: Double(UserProfile.caloriesMin)...Double(UserProfile.caloriesMax),
                        color: AppColors.green, unit: ""
                    )
                }
                .frame(maxWidth: .infinity, alignment: .center)

                Button("Recalculate from food log") {
                    recalculateMacros(n)
                }
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(AppColors.textSecondary)
            }
        }
    }

    // MARK: - Food Checklist

    private func foodChecklistCard(_ n: NutritionLog) -> some View {
        AppCard(padding: 0) {
            VStack(alignment: .leading, spacing: 0) {
                SectionHeader(title: "Daily Food Log")
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 10)

                Group {
                    foodSection(title: "PROTEIN STACK", color: AppColors.blue) {
                        quarkRow(n)
                        proteinRow("Whey", grams: $nutrition.bound(\.wheyG), target: 50, n: n)
                        proteinRow("Clear Whey", grams: $nutrition.bound(\.clearWheyG), target: 40, n: n)
                        proteinRow("Casein", grams: $nutrition.bound(\.caseinG), target: 50, n: n)
                        meatRow(n)
                        eggsRow(n)
                    }
                    foodSection(title: "CARBS & FRUIT", color: AppColors.orange) {
                        riceRow(n)
                        fruitRow(n)
                        datesRow(n)
                    }
                    foodSection(title: "FATS & EXTRAS", color: AppColors.yellow) {
                        darkChocolateRow(n)
                        vegetablesRow(n)
                        flatWhiteRow(n)
                    }
                    foodSection(title: "HYDRATION", color: AppColors.teal) {
                        sodiumRow(n)
                        hydrationRow(n)
                    }
                }
            }
        }
    }

    private func foodSection<Content: View>(title: String, color: Color, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Rectangle()
                    .fill(color)
                    .frame(width: 3, height: 14)
                    .clipShape(Capsule())
                Text(title)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(color)
                    .tracking(0.8)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(color.opacity(0.06))
            content()
        }
    }

    // MARK: - Individual Food Rows

    private func quarkRow(_ n: NutritionLog) -> some View {
        NutritionStepperRow(
            label: "Low Fat Quark",
            value: Binding(get: { n.quarkG }, set: { n.quarkG = $0 }),
            step: 50, unit: "g", targetRange: 400...600,
            hint: "Target: 500g"
        )
    }

    private func proteinRow(_ name: String, grams: Binding<Double>, target: Double, n: NutritionLog) -> some View {
        NutritionStepperRow(
            label: name,
            value: grams,
            step: 5, unit: "g", targetRange: (target * 0.8)...(target * 1.2),
            hint: "Target: ~\(Int(target))g"
        )
    }

    private func meatRow(_ n: NutritionLog) -> some View {
        NutritionStepperRow(
            label: "Beef / Chicken",
            value: Binding(get: { n.beefOrChickenG }, set: { n.beefOrChickenG = $0 }),
            step: 25, unit: "g", targetRange: 150...250,
            hint: "Target: ~200g"
        )
    }

    private func eggsRow(_ n: NutritionLog) -> some View {
        NutritionIntRow(
            label: "Eggs",
            value: Binding(get: { n.eggsCount }, set: { n.eggsCount = $0 }),
            unit: "eggs", targetRange: 2...4,
            hint: "Usually 2-3"
        )
    }

    private func riceRow(_ n: NutritionLog) -> some View {
        NutritionStepperRow(
            label: "Rice (dry weight)",
            value: Binding(get: { n.riceDryG }, set: { n.riceDryG = $0 }),
            step: 25, unit: "g", targetRange: 150...250,
            hint: "Target: ~200g dry"
        )
    }

    private func fruitRow(_ n: NutritionLog) -> some View {
        NutritionIntRow(
            label: "Fruit portions",
            value: Binding(get: { n.fruitPortions }, set: { n.fruitPortions = $0 }),
            unit: "portions", targetRange: 1...3,
            hint: "Apple, kiwi, blueberries, ½ banana"
        )
    }

    private func datesRow(_ n: NutritionLog) -> some View {
        NutritionIntRow(
            label: "Medjool dates",
            value: Binding(get: { n.dates }, set: { n.dates = $0 }),
            unit: "dates", targetRange: 1...2,
            hint: "1 as baseline"
        )
    }

    private func darkChocolateRow(_ n: NutritionLog) -> some View {
        NutritionStepperRow(
            label: "Dark Chocolate",
            value: Binding(get: { n.darkChocolateG }, set: { n.darkChocolateG = $0 }),
            step: 5, unit: "g", targetRange: 15...30,
            hint: "~20g daily"
        )
    }

    private func vegetablesRow(_ n: NutritionLog) -> some View {
        NutritionStepperRow(
            label: "Vegetables",
            value: Binding(get: { n.vegetablesG }, set: { n.vegetablesG = $0 }),
            step: 50, unit: "g", targetRange: 300...500,
            hint: "300-400g target"
        )
    }

    private func flatWhiteRow(_ n: NutritionLog) -> some View {
        NutritionIntRow(
            label: "Flat whites",
            value: Binding(get: { n.flatWhitesCount }, set: { n.flatWhitesCount = $0 }),
            unit: "cups", targetRange: 2...4,
            hint: "3-4 × ~120ml oat milk"
        )
    }

    private func sodiumRow(_ n: NutritionLog) -> some View {
        NutritionIntRow(
            label: "Sodium",
            value: Binding(get: { n.sodiumMg }, set: { n.sodiumMg = $0 }),
            unit: "mg", targetRange: 2000...3000,
            hint: "2-3g target (Himalayan salt)"
        )
    }

    private func hydrationRow(_ n: NutritionLog) -> some View {
        NutritionStepperRow(
            label: "Hydration",
            value: Binding(get: { n.hydrationL }, set: { n.hydrationL = $0 }),
            step: 0.25, unit: "L", targetRange: 2.5...4.0,
            hint: "Include workout drink"
        )
    }

    // MARK: - Meal Timing

    private func mealTimingCard(_ n: NutritionLog) -> some View {
        AppCard {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(title: "Meal Timing", subtitle: "Intermittent fasting structure")
                StatRow(label: "Training time", value: "Morning (fasted)", icon: "sunrise.fill")
                StatRow(label: "First full meal", value: "~12:00", icon: "fork.knife")
                StatRow(label: "Post-workout gap", value: "~2.5h", icon: "timer")
                if n.hydrationL < 2.5 {
                    HStack {
                        Image(systemName: "drop.fill")
                            .foregroundColor(AppColors.teal)
                        Text("Post-workout: add whey + Himalayan salt to workout drink")
                            .font(.system(size: 12))
                            .foregroundColor(AppColors.teal)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(AppColors.teal.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
        }
    }

    // MARK: - Targets Reference

    private var targetsReferenceCard: some View {
        AppCard {
            VStack(alignment: .leading, spacing: 10) {
                SectionHeader(title: "Daily Targets")
                StatRow(label: "Calories", value: "2800–3200 kcal", icon: "flame.fill")
                StatRow(label: "Protein", value: "200–230g", icon: "drop.fill", valueColor: AppColors.blue)
                StatRow(label: "Carbs", value: "270–320g", icon: "leaf.fill", valueColor: AppColors.orange)
                StatRow(label: "Fat", value: "70–90g", icon: "circle.fill", valueColor: AppColors.yellow)
                StatRow(label: "Sodium", value: "2–3g", icon: "sparkles", valueColor: AppColors.teal)
            }
        }
    }

    // MARK: - Macro Calculation

    private func recalculateMacros(_ n: NutritionLog) {
        // Approximate macro calculation based on food items
        var protein: Double = 0
        var carbs: Double = 0
        var fat: Double = 0
        var kcal: Double = 0

        // Quark (per 100g: ~11p, ~4c, ~0.2f = 63kcal)
        protein += n.quarkG * 0.11
        carbs += n.quarkG * 0.04
        fat += n.quarkG * 0.002
        kcal += n.quarkG * 0.63

        // Whey (per serving ~25g protein, 2c, 1.5f)
        protein += (n.wheyG / 30) * 25
        carbs += (n.wheyG / 30) * 2
        fat += (n.wheyG / 30) * 1.5
        kcal += (n.wheyG / 30) * 120

        // Clear whey (per serving ~22g protein, 3c, 0f)
        protein += (n.clearWheyG / 34) * 22
        carbs += (n.clearWheyG / 34) * 3
        kcal += (n.clearWheyG / 34) * 100

        // Casein (per serving ~24g protein, 3c, 1f)
        protein += (n.caseinG / 30) * 24
        carbs += (n.caseinG / 30) * 3
        fat += (n.caseinG / 30) * 1
        kcal += (n.caseinG / 30) * 116

        // Beef/Chicken (lean, per 100g: ~26p, 0c, 4f)
        protein += n.beefOrChickenG * 0.26
        fat += n.beefOrChickenG * 0.04
        kcal += n.beefOrChickenG * 1.45

        // Eggs (per egg: ~6p, 0.6c, 5f)
        protein += Double(n.eggsCount) * 6
        carbs += Double(n.eggsCount) * 0.6
        fat += Double(n.eggsCount) * 5
        kcal += Double(n.eggsCount) * 70

        // Rice dry weight (per 100g dry: ~7p, 78c, 0.7f)
        protein += n.riceDryG * 0.07
        carbs += n.riceDryG * 0.78
        fat += n.riceDryG * 0.007
        kcal += n.riceDryG * 3.5

        // Fruit (~20g carbs per portion)
        carbs += Double(n.fruitPortions) * 20
        kcal += Double(n.fruitPortions) * 80

        // Medjool dates (per date: ~18c, 0.2p, 0.03f)
        carbs += Double(n.dates) * 18
        protein += Double(n.dates) * 0.2
        kcal += Double(n.dates) * 72

        // Dark chocolate (per 20g: ~2p, 12c, 9f)
        protein += n.darkChocolateG * 0.1
        carbs += n.darkChocolateG * 0.6
        fat += n.darkChocolateG * 0.45
        kcal += n.darkChocolateG * 5.4

        // Vegetables (per 100g: ~2p, 7c, 0.3f)
        protein += n.vegetablesG * 0.02
        carbs += n.vegetablesG * 0.07
        fat += n.vegetablesG * 0.003
        kcal += n.vegetablesG * 0.35

        // Flat whites (per cup ~120ml oat milk: ~1.5p, 8c, 1.5f)
        protein += Double(n.flatWhitesCount) * 1.5
        carbs += Double(n.flatWhitesCount) * 8
        fat += Double(n.flatWhitesCount) * 1.5
        kcal += Double(n.flatWhitesCount) * 52

        // Walnuts default ~20g: ~2.5p, 2c, 13f
        protein += 2.5; carbs += 2; fat += 13; kcal += 131
        // 2 Brazil nuts: ~0.7p, 0.4c, 2.8f
        protein += 0.7; carbs += 0.4; fat += 2.8; kcal += 30
        // Parmesan ~12g: ~4.5p, 0c, 3f
        protein += 4.5; fat += 3; kcal += 43
        // Creatine adds ~0 macros

        n.proteinG = protein
        n.carbsG = carbs
        n.fatG = fat
        n.calories = Int(kcal)
    }

    private func setup() {
        let ds = DataService(modelContext: modelContext)
        dataService = ds
        todayLog = ds.fetchOrCreateTodayLog()
        if let log = todayLog {
            nutrition = ds.fetchOrCreateNutritionLog(for: log)
        }
        ds.save()
    }
}

// MARK: - Stepper Rows

struct NutritionStepperRow: View {
    let label: String
    @Binding var value: Double
    let step: Double
    let unit: String
    let targetRange: ClosedRange<Double>
    let hint: String

    private var inRange: Bool { targetRange.contains(value) }
    private var color: Color { inRange ? AppColors.green : AppColors.orange }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(AppColors.textPrimary)
                Text(hint)
                    .font(.system(size: 11))
                    .foregroundColor(AppColors.textSecondary)
            }
            Spacer()
            HStack(spacing: 10) {
                Button { if value >= step { value -= step } } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.system(size: 22))
                        .foregroundColor(AppColors.textSecondary)
                }
                Text(step < 1 ? String(format: "%.2f", value) : "\(Int(value))\(unit)")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(color)
                    .frame(width: 64, alignment: .center)
                Button { value += step } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 22))
                        .foregroundColor(color)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        Divider().background(AppColors.cardBorder).padding(.leading, 16)
    }
}

struct NutritionIntRow: View {
    let label: String
    @Binding var value: Int
    let unit: String
    let targetRange: ClosedRange<Int>
    let hint: String

    private var inRange: Bool { targetRange.contains(value) }
    private var color: Color { inRange ? AppColors.green : AppColors.orange }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(AppColors.textPrimary)
                Text(hint)
                    .font(.system(size: 11))
                    .foregroundColor(AppColors.textSecondary)
            }
            Spacer()
            HStack(spacing: 10) {
                Button { if value > 0 { value -= 1 } } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.system(size: 22))
                        .foregroundColor(AppColors.textSecondary)
                }
                Text("\(value) \(unit)")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(color)
                    .frame(width: 72, alignment: .center)
                Button { value += 1 } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 22))
                        .foregroundColor(color)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        Divider().background(AppColors.cardBorder).padding(.leading, 16)
    }
}

// MARK: - Optional Binding Extension

extension Binding where Value == NutritionLog? {
    func bound(_ keyPath: WritableKeyPath<NutritionLog, Double>) -> Binding<Double> {
        Binding<Double>(
            get: { self.wrappedValue?[keyPath: keyPath] ?? 0 },
            set: { self.wrappedValue?[keyPath: keyPath] = $0 }
        )
    }
}
