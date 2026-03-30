import SwiftUI
import SwiftData

struct NutritionView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var todayLog: DailyLog?
    @State private var nutrition: NutritionLog?
    @State private var dataService: DataService?
    @State private var showingQuickAdd = false

    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.background.ignoresSafeArea()
                if let n = nutrition {
                    ScrollView {
                        VStack(spacing: 20) {
                            macroSummaryCard(n)
                            quickAddCard(n)
                            foodChecklistCard(n)
                            mealTimingCard(n)
                            targetsReferenceCard
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                        .padding(.bottom, 24)
                    }
                } else {
                    SwiftUI.ProgressView().tint(AppColors.accent)
                }
            }
            .navigationTitle("Nutrition")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(AppColors.background, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingQuickAdd = true
                    } label: {
                        Label("Quick Add", systemImage: "plus.circle.fill")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(AppColors.orange)
                    }
                }
            }
            .sheet(isPresented: $showingQuickAdd) {
                if let n = nutrition {
                    QuickCalorieAddView(nutrition: n) {
                        recalculate(n)
                    }
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
                    MacroRingView(label: "Protein", current: n.proteinG,
                                  target: Double(UserProfile.proteinMin)...Double(UserProfile.proteinMax),
                                  color: AppColors.blue, unit: "g")
                    MacroRingView(label: "Carbs", current: n.carbsG,
                                  target: Double(UserProfile.carbsMin)...Double(UserProfile.carbsMax),
                                  color: AppColors.orange, unit: "g")
                    MacroRingView(label: "Fat", current: n.fatG,
                                  target: Double(UserProfile.fatMin)...Double(UserProfile.fatMax),
                                  color: AppColors.yellow, unit: "g")
                    MacroRingView(label: "Kcal", current: Double(n.calories),
                                  target: Double(UserProfile.caloriesMin)...Double(UserProfile.caloriesMax),
                                  color: AppColors.green, unit: "")
                }
                .frame(maxWidth: .infinity, alignment: .center)

                if n.extraCalories > 0 {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 12))
                            .foregroundColor(AppColors.orange)
                        Text("Includes \(n.extraCalories) kcal extra\(n.extraNotes.isEmpty ? "" : " · \(n.extraNotes)")")
                            .font(.system(size: 12))
                            .foregroundColor(AppColors.textSecondary)
                        Spacer()
                        Button("Clear") {
                            n.extraCalories = 0; n.extraProteinG = 0
                            n.extraCarbsG = 0; n.extraFatG = 0; n.extraNotes = ""
                            recalculate(n)
                        }
                        .font(.system(size: 12))
                        .foregroundColor(AppColors.red)
                    }
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .background(AppColors.orange.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
        }
    }

    // MARK: - Quick Add Card

    private func quickAddCard(_ n: NutritionLog) -> some View {
        Button { showingQuickAdd = true } label: {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(AppColors.orange.opacity(0.15))
                        .frame(width: 44, height: 44)
                    Image(systemName: "fork.knife.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(AppColors.orange)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text("Quick Add Calories")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(AppColors.textPrimary)
                    Text("Restaurant, ice cream, snack outside your plan")
                        .font(.system(size: 12))
                        .foregroundColor(AppColors.textSecondary)
                }
                Spacer()
                Image(systemName: "plus.circle")
                    .font(.system(size: 20))
                    .foregroundColor(AppColors.orange)
            }
            .padding(14)
            .background(AppColors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(AppColors.cardBorder, lineWidth: 0.5))
        }
    }

    // MARK: - Food Checklist

    private func foodChecklistCard(_ n: NutritionLog) -> some View {
        AppCard(padding: 0) {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    SectionHeader(title: "Daily Food Log", subtitle: "Tap ✓ to skip · scroll wheel to adjust")
                    Spacer()
                    Button("Reset") {
                        resetToDefaults(n)
                        recalculate(n)
                    }
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(AppColors.textSecondary)
                }
                .padding(.horizontal, 16).padding(.top, 16).padding(.bottom, 10)

                foodSection(title: "PROTEIN STACK", color: AppColors.blue) {
                    foodWheelRow(
                        label: "Low Fat Quark",
                        value: Binding(get: { n.quarkG }, set: { n.quarkG = $0; recalculate(n) }),
                        options: [100, 150, 200, 250, 300, 350, 400, 450, 500, 550, 600],
                        unit: "g", defaultValue: 500,
                        kcalEstimate: { Int($0 * 0.63) }
                    )
                    foodWheelRow(
                        label: "Whey Protein",
                        value: Binding(get: { n.wheyG }, set: { n.wheyG = $0; recalculate(n) }),
                        options: [10, 20, 30, 40, 50, 60, 70, 80],
                        unit: "g", defaultValue: 50,
                        kcalEstimate: { Int(($0 / 30) * 120) }
                    )
                    foodWheelRow(
                        label: "Clear Whey",
                        value: Binding(get: { n.clearWheyG }, set: { n.clearWheyG = $0; recalculate(n) }),
                        options: [17, 34, 51, 68],
                        unit: "g", defaultValue: 34,
                        kcalEstimate: { Int(($0 / 34) * 100) }
                    )
                    foodWheelRow(
                        label: "Casein",
                        value: Binding(get: { n.caseinG }, set: { n.caseinG = $0; recalculate(n) }),
                        options: [25, 50, 75, 100],
                        unit: "g", defaultValue: 50,
                        kcalEstimate: { Int(($0 / 30) * 116) }
                    )
                    foodWheelRow(
                        label: "Collagen Peptides",
                        value: Binding(get: { n.collagenG }, set: { n.collagenG = $0; recalculate(n) }),
                        options: [10, 15, 20, 25, 30, 40],
                        unit: "g", defaultValue: 20,
                        kcalEstimate: { Int($0 * 3.7) }
                    )
                    foodWheelRow(
                        label: "Schwarzwälder Proteinmilch",
                        value: Binding(get: { n.proteinMilkMl }, set: { n.proteinMilkMl = $0; recalculate(n) }),
                        options: [167, 250, 333, 500, 666],
                        unit: "ml", defaultValue: 333,
                        kcalEstimate: { Int($0 * 0.5) }
                    )
                    foodWheelRow(
                        label: "Beef / Chicken",
                        value: Binding(get: { n.beefOrChickenG }, set: { n.beefOrChickenG = $0; recalculate(n) }),
                        options: [100, 150, 200, 250, 300, 350, 400, 450, 500],
                        unit: "g", defaultValue: 200,
                        kcalEstimate: { Int($0 * 1.45) }
                    )
                    foodWheelRow(
                        label: "Eggs",
                        value: Binding(get: { Double(n.eggsCount) }, set: { n.eggsCount = Int($0); recalculate(n) }),
                        options: [1, 2, 3, 4, 5, 6],
                        unit: "eggs", defaultValue: 2,
                        kcalEstimate: { Int($0 * 70) }
                    )
                }
                foodSection(title: "CARBS & FRUIT", color: AppColors.orange) {
                    foodWheelRow(
                        label: "Rice (dry)",
                        value: Binding(get: { n.riceDryG }, set: { n.riceDryG = $0; recalculate(n) }),
                        options: [50, 75, 100, 125, 150, 175, 200, 225, 250, 275, 300, 325, 350, 375, 400],
                        unit: "g", defaultValue: 200,
                        kcalEstimate: { Int($0 * 3.5) }
                    )
                    foodWheelRow(
                        label: "Fruit",
                        value: Binding(get: { Double(n.fruitPortions) }, set: { n.fruitPortions = Int($0); recalculate(n) }),
                        options: [1, 2, 3, 4],
                        unit: "portions", defaultValue: 1,
                        kcalEstimate: { Int($0 * 80) }
                    )
                    foodWheelRow(
                        label: "Medjool Dates",
                        value: Binding(get: { Double(n.dates) }, set: { n.dates = Int($0); recalculate(n) }),
                        options: [1, 2, 3, 4, 5],
                        unit: "dates", defaultValue: 1,
                        kcalEstimate: { Int($0 * 72) }
                    )
                }
                foodSection(title: "FATS & EXTRAS", color: AppColors.yellow) {
                    foodWheelRow(
                        label: "Dark Chocolate",
                        value: Binding(get: { n.darkChocolateG }, set: { n.darkChocolateG = $0; recalculate(n) }),
                        options: [10, 15, 20, 25, 30, 40, 50],
                        unit: "g", defaultValue: 20,
                        kcalEstimate: { Int($0 * 5.4) }
                    )
                    foodToggleRow(label: "Walnuts + Brazil nuts", detail: "~20g · ~161 kcal",
                                  isOn: Binding(get: { n.walnutsIncluded }, set: { n.walnutsIncluded = $0; recalculate(n) }))
                    foodWheelRow(
                        label: "Vegetables",
                        value: Binding(get: { n.vegetablesG }, set: { n.vegetablesG = $0; recalculate(n) }),
                        options: [100, 150, 200, 250, 300, 350, 400, 450, 500, 600, 700],
                        unit: "g", defaultValue: 350,
                        kcalEstimate: { Int($0 * 0.35) }
                    )
                    foodWheelRow(
                        label: "Flat whites (oat milk)",
                        value: Binding(get: { Double(n.flatWhitesCount) }, set: { n.flatWhitesCount = Int($0); recalculate(n) }),
                        options: [1, 2, 3, 4, 5],
                        unit: "cups", defaultValue: 3,
                        kcalEstimate: { Int($0 * 52) }
                    )
                }
                foodSection(title: "HYDRATION", color: AppColors.teal) {
                    foodToggleRow(label: "Himalayan Salt", detail: "~2.5g sodium",
                                  isOn: Binding(get: { n.sodiumMg > 0 }, set: { n.sodiumMg = $0 ? 2500 : 0; recalculate(n) }))
                    foodToggleRow(label: "Hydration 3L+", detail: "Including workout drink",
                                  isOn: Binding(get: { n.hydrationL >= 2.5 }, set: { n.hydrationL = $0 ? 3.0 : 0; recalculate(n) }))
                }
            }
        }
    }

    private func foodSection<Content: View>(title: String, color: Color, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Rectangle().fill(color).frame(width: 3, height: 14).clipShape(Capsule())
                Text(title).font(.system(size: 11, weight: .bold)).foregroundColor(color).tracking(0.8)
            }
            .padding(.horizontal, 16).padding(.vertical, 8).background(color.opacity(0.06))
            content()
        }
    }

    /// Row with a scroll wheel for portion adjustment. Toggle sets value to 0 (off) or defaultValue (on).
    private func foodWheelRow(
        label: String,
        value: Binding<Double>,
        options: [Double],
        unit: String,
        defaultValue: Double,
        kcalEstimate: @escaping (Double) -> Int
    ) -> some View {
        let isOn = value.wrappedValue > 0
        return VStack(spacing: 0) {
            HStack(spacing: 12) {
                Button {
                    value.wrappedValue = isOn ? 0 : defaultValue
                } label: {
                    Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 22))
                        .foregroundColor(isOn ? AppColors.green : AppColors.cardBorder)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(label)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(isOn ? AppColors.textPrimary : AppColors.textSecondary)
                    Text(isOn ? "~\(kcalEstimate(value.wrappedValue)) kcal" : "not eating today")
                        .font(.system(size: 11))
                        .foregroundColor(AppColors.textSecondary)
                        .animation(.none, value: isOn)
                }

                Spacer()

                if isOn {
                    VStack(spacing: 0) {
                        Picker("", selection: value) {
                            ForEach(options, id: \.self) { opt in
                                Text("\(Int(opt))").tag(opt)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(width: 72, height: 72)
                        .clipped()
                        Text(unit)
                            .font(.system(size: 9))
                            .foregroundColor(AppColors.textSecondary)
                    }
                } else {
                    Text("–")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(AppColors.textSecondary.opacity(0.3))
                        .frame(width: 72, alignment: .center)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, isOn ? 6 : 10)
            .background(isOn ? Color.clear : AppColors.cardBorder.opacity(0.05))

            Divider().background(AppColors.cardBorder).padding(.leading, 56)
        }
    }

    private func foodToggleRow(label: String, detail: String, isOn: Binding<Bool>) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Button { isOn.wrappedValue.toggle() } label: {
                    Image(systemName: isOn.wrappedValue ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 22))
                        .foregroundColor(isOn.wrappedValue ? AppColors.green : AppColors.cardBorder)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(label)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(isOn.wrappedValue ? AppColors.textPrimary : AppColors.textSecondary)
                    Text(detail)
                        .font(.system(size: 11))
                        .foregroundColor(AppColors.textSecondary)
                }
                Spacer()
            }
            .padding(.horizontal, 16).padding(.vertical, 10)
            .background(isOn.wrappedValue ? Color.clear : AppColors.cardBorder.opacity(0.05))
            Divider().background(AppColors.cardBorder).padding(.leading, 56)
        }
    }

    // MARK: - Meal Timing

    private func mealTimingCard(_ n: NutritionLog) -> some View {
        AppCard {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(title: "Meal Timing", subtitle: "Intermittent fasting structure")
                StatRow(label: "Training time", value: "Morning (fasted)", icon: "sunrise.fill")
                StatRow(label: "First full meal", value: "~12:00", icon: "fork.knife")
                StatRow(label: "Post-workout gap", value: "~2.5h", icon: "timer")
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

    // MARK: - Recalculate

    private func recalculate(_ n: NutritionLog) {
        var protein: Double = 0; var carbs: Double = 0; var fat: Double = 0; var kcal: Double = 0

        protein += n.quarkG * 0.11;   carbs += n.quarkG * 0.04;    fat += n.quarkG * 0.002;  kcal += n.quarkG * 0.63
        protein += (n.wheyG / 30) * 25; carbs += (n.wheyG / 30) * 2; fat += (n.wheyG / 30) * 1.5; kcal += (n.wheyG / 30) * 120
        protein += (n.clearWheyG / 34) * 22; carbs += (n.clearWheyG / 34) * 3; kcal += (n.clearWheyG / 34) * 100
        protein += (n.caseinG / 30) * 24; carbs += (n.caseinG / 30) * 3; fat += (n.caseinG / 30) * 1; kcal += (n.caseinG / 30) * 116
        protein += n.collagenG * 0.9; kcal += n.collagenG * 3.7
        protein += n.proteinMilkMl * 0.08; carbs += n.proteinMilkMl * 0.04; fat += n.proteinMilkMl * 0.01; kcal += n.proteinMilkMl * 0.5
        protein += n.beefOrChickenG * 0.26; fat += n.beefOrChickenG * 0.04; kcal += n.beefOrChickenG * 1.45
        protein += Double(n.eggsCount) * 6; carbs += Double(n.eggsCount) * 0.6; fat += Double(n.eggsCount) * 5; kcal += Double(n.eggsCount) * 70
        protein += n.riceDryG * 0.07;  carbs += n.riceDryG * 0.78;  fat += n.riceDryG * 0.007; kcal += n.riceDryG * 3.5
        carbs += Double(n.fruitPortions) * 20; kcal += Double(n.fruitPortions) * 80
        carbs += Double(n.dates) * 18; protein += Double(n.dates) * 0.2; kcal += Double(n.dates) * 72
        protein += n.darkChocolateG * 0.1; carbs += n.darkChocolateG * 0.6; fat += n.darkChocolateG * 0.45; kcal += n.darkChocolateG * 5.4
        protein += n.vegetablesG * 0.02; carbs += n.vegetablesG * 0.07; fat += n.vegetablesG * 0.003; kcal += n.vegetablesG * 0.35
        protein += Double(n.flatWhitesCount) * 1.5; carbs += Double(n.flatWhitesCount) * 8; fat += Double(n.flatWhitesCount) * 1.5; kcal += Double(n.flatWhitesCount) * 52

        if n.walnutsIncluded {
            protein += 3.2; carbs += 2.4; fat += 15.8; kcal += 161
        }

        // Extra calories
        protein += n.extraProteinG; carbs += n.extraCarbsG; fat += n.extraFatG; kcal += Double(n.extraCalories)

        n.proteinG = protein; n.carbsG = carbs; n.fatG = fat; n.calories = Int(kcal)
        dataService?.save()
    }

    private func resetToDefaults(_ n: NutritionLog) {
        n.quarkG = 500; n.wheyG = 50; n.clearWheyG = 40; n.caseinG = 50; n.collagenG = 20; n.proteinMilkMl = 333
        n.beefOrChickenG = 200; n.eggsCount = 2; n.riceDryG = 200
        n.fruitPortions = 1; n.dates = 1; n.darkChocolateG = 20
        n.vegetablesG = 350; n.flatWhitesCount = 3; n.walnutsIncluded = true
        n.sodiumMg = 2500; n.hydrationL = 3.0
    }

    private func setup() {
        let ds = DataService(modelContext: modelContext)
        dataService = ds
        todayLog = ds.fetchOrCreateTodayLog()
        if let log = todayLog {
            let n = ds.fetchOrCreateNutritionLog(for: log)
            // Auto-calculate on first load if macros are zero
            if n.calories == 0 { recalculate(n) }
            nutrition = n
        }
        ds.save()
    }
}

// MARK: - Quick Calorie Add Sheet

struct QuickCalorieAddView: View {
    @Environment(\.dismiss) private var dismiss
    var nutrition: NutritionLog
    var onSave: () -> Void

    @State private var description = ""
    @State private var calories = 0
    @State private var protein: Double = 0
    @State private var carbs: Double = 0
    @State private var fat: Double = 0
    @State private var showMacros = false

    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.background.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 20) {
                        AppCard {
                            VStack(alignment: .leading, spacing: 16) {
                                SectionHeader(title: "What did you have?")

                                TextField("e.g. Restaurant pasta, ice cream...", text: $description)
                                    .font(.system(size: 15))
                                    .foregroundColor(AppColors.textPrimary)
                                    .padding(12)
                                    .background(AppColors.background)
                                    .clipShape(RoundedRectangle(cornerRadius: 10))

                                VStack(alignment: .leading, spacing: 8) {
                                    Text("CALORIES")
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundColor(AppColors.textSecondary)
                                        .tracking(0.8)

                                    HStack(spacing: 16) {
                                        Button { if calories >= 50 { calories -= 50 } } label: {
                                            Image(systemName: "minus.circle.fill").font(.system(size: 28)).foregroundColor(AppColors.textSecondary)
                                        }
                                        Text("\(calories)")
                                            .font(.system(size: 48, weight: .bold, design: .rounded))
                                            .foregroundColor(AppColors.orange)
                                            .frame(maxWidth: .infinity)
                                        Button { calories += 50 } label: {
                                            Image(systemName: "plus.circle.fill").font(.system(size: 28)).foregroundColor(AppColors.orange)
                                        }
                                    }

                                    // Quick tap amounts
                                    HStack(spacing: 8) {
                                        ForEach([200, 400, 600, 800], id: \.self) { preset in
                                            Button { calories = preset } label: {
                                                Text("+\(preset)")
                                                    .font(.system(size: 12, weight: .semibold))
                                                    .foregroundColor(calories == preset ? .black : AppColors.textSecondary)
                                                    .padding(.horizontal, 12).padding(.vertical, 6)
                                                    .background(calories == preset ? AppColors.orange : AppColors.cardBorder.opacity(0.3))
                                                    .clipShape(Capsule())
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        Button {
                            withAnimation { showMacros.toggle() }
                        } label: {
                            HStack {
                                Text(showMacros ? "Hide macros" : "Add macros (optional)")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(AppColors.textSecondary)
                                Spacer()
                                Image(systemName: showMacros ? "chevron.up" : "chevron.down")
                                    .font(.system(size: 12))
                                    .foregroundColor(AppColors.textSecondary)
                            }
                            .padding(.horizontal, 4)
                        }

                        if showMacros {
                            AppCard {
                                VStack(spacing: 14) {
                                    macroStepper("Protein", value: $protein, color: AppColors.blue)
                                    macroStepper("Carbs", value: $carbs, color: AppColors.orange)
                                    macroStepper("Fat", value: $fat, color: AppColors.yellow)
                                }
                            }
                        }
                    }
                    .padding(16)
                }
            }
            .navigationTitle("Quick Add")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(AppColors.background, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.foregroundColor(AppColors.textSecondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        nutrition.extraCalories += calories
                        nutrition.extraProteinG += protein
                        nutrition.extraCarbsG += carbs
                        nutrition.extraFatG += fat
                        if !description.isEmpty {
                            nutrition.extraNotes = nutrition.extraNotes.isEmpty ? description : "\(nutrition.extraNotes), \(description)"
                        }
                        onSave()
                        dismiss()
                    }
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(calories > 0 ? AppColors.orange : AppColors.textSecondary)
                    .disabled(calories == 0)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func macroStepper(_ label: String, value: Binding<Double>, color: Color) -> some View {
        HStack {
            Text(label).font(.system(size: 14, weight: .medium)).foregroundColor(AppColors.textPrimary)
            Spacer()
            Button { if value.wrappedValue >= 5 { value.wrappedValue -= 5 } } label: {
                Image(systemName: "minus.circle.fill").font(.system(size: 22)).foregroundColor(AppColors.textSecondary)
            }
            Text("\(Int(value.wrappedValue))g")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(color).frame(width: 56, alignment: .center)
            Button { value.wrappedValue += 5 } label: {
                Image(systemName: "plus.circle.fill").font(.system(size: 22)).foregroundColor(color)
            }
        }
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
