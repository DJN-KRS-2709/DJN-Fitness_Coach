import SwiftUI
import SwiftData

struct SupplementsView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var suppLog: SupplementLog?
    @State private var dataService: DataService?

    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.background.ignoresSafeArea()
                if let log = suppLog {
                    ScrollView {
                        VStack(spacing: 20) {
                            progressHeader(log)
                            dailyStack(log)
                            if log.isAlternateDay {
                                alternateDayStack(log)
                            } else {
                                alternateDayInfo
                            }
                            proteinSupplementsCard(log)
                            timingGuideCard
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                        .padding(.bottom, 24)
                    }
                } else {
                    ProgressView().tint(AppColors.accent)
                }
            }
            .navigationTitle("Supplements")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(AppColors.background, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { dataService?.save() }
                        .foregroundColor(AppColors.purple)
                }
            }
        }
        .onAppear { setup() }
    }

    // MARK: - Progress Header

    private func progressHeader(_ log: SupplementLog) -> some View {
        AppCard {
            VStack(spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Today's Stack")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundColor(AppColors.textPrimary)
                        Text(log.isAlternateDay ? "Daily + Alternate Day supplements" : "Daily supplements")
                            .font(.system(size: 13))
                            .foregroundColor(AppColors.textSecondary)
                    }
                    Spacer()
                    ZStack {
                        Circle()
                            .stroke(AppColors.purple.opacity(0.2), lineWidth: 6)
                            .frame(width: 56, height: 56)
                        Circle()
                            .trim(from: 0, to: log.completionPercentage)
                            .stroke(log.completionPercentage > 0.8 ? AppColors.green : AppColors.purple,
                                    style: StrokeStyle(lineWidth: 6, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                            .frame(width: 56, height: 56)
                            .animation(.easeInOut, value: log.completionPercentage)
                        Text("\(Int(log.completionPercentage * 100))%")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(AppColors.textPrimary)
                    }
                }

                Button {
                    markAllDaily(log)
                    dataService?.save()
                } label: {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                        Text("Mark All Daily Done")
                    }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(AppColors.purple)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }
        }
    }

    // MARK: - Daily Stack

    private func dailyStack(_ log: SupplementLog) -> some View {
        AppCard(padding: 0) {
            VStack(alignment: .leading, spacing: 0) {
                SectionHeader(title: "Daily Supplements")
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 10)

                suppToggleRow(
                    label: "Omega-3 Fish Oil",
                    detail: "360mg EPA / 240mg DHA",
                    icon: "drop.fill",
                    color: AppColors.teal,
                    isOn: Binding(get: { log.omega3 }, set: { log.omega3 = $0; dataService?.save() })
                )
                suppToggleRow(
                    label: "Magnesium Glycinate",
                    detail: "150mg",
                    icon: "moon.stars.fill",
                    color: AppColors.purple,
                    isOn: Binding(get: { log.magnesium }, set: { log.magnesium = $0; dataService?.save() })
                )
                suppToggleRow(
                    label: "Glycine",
                    detail: "2000mg",
                    icon: "zzz",
                    color: AppColors.blue,
                    isOn: Binding(get: { log.glycine }, set: { log.glycine = $0; dataService?.save() })
                )
                suppToggleRow(
                    label: "NAD+",
                    detail: "1000mg",
                    icon: "bolt.circle.fill",
                    color: AppColors.yellow,
                    isOn: Binding(get: { log.nad }, set: { log.nad = $0; dataService?.save() })
                )
                suppToggleRow(
                    label: "Ashwagandha",
                    detail: "2400mg",
                    icon: "leaf.fill",
                    color: AppColors.green,
                    isOn: Binding(get: { log.ashwagandha }, set: { log.ashwagandha = $0; dataService?.save() })
                )
                suppToggleRow(
                    label: "Urolithin A",
                    detail: "2000mg",
                    icon: "heart.fill",
                    color: AppColors.red,
                    isOn: Binding(get: { log.urolithinA }, set: { log.urolithinA = $0; dataService?.save() })
                )
                suppToggleRow(
                    label: "Vitamin D3 + K2",
                    detail: "2000 IU",
                    icon: "sun.max.fill",
                    color: AppColors.orange,
                    isOn: Binding(get: { log.vitaminDK2 }, set: { log.vitaminDK2 = $0; dataService?.save() })
                )
                suppToggleRow(
                    label: "Zinc Bisglycinate",
                    detail: "225mg",
                    icon: "shield.fill",
                    color: AppColors.blue,
                    isOn: Binding(get: { log.zinc }, set: { log.zinc = $0; dataService?.save() })
                )
                suppToggleRow(
                    label: "Boron",
                    detail: "4mg",
                    icon: "atom",
                    color: AppColors.textSecondary,
                    isOn: Binding(get: { log.boron }, set: { log.boron = $0; dataService?.save() })
                )
                suppToggleRow(
                    label: "Creatine",
                    detail: "10–15g",
                    icon: "flame.fill",
                    color: AppColors.orange,
                    isOn: Binding(get: { log.creatine }, set: { log.creatine = $0; dataService?.save() })
                )
                suppToggleRow(
                    label: "Glutamine",
                    detail: "5g",
                    icon: "waveform.path.ecg",
                    color: AppColors.green,
                    isOn: Binding(get: { log.glutamine }, set: { log.glutamine = $0; dataService?.save() })
                )
            }
        }
    }

    // MARK: - Alternate Day Stack

    private func alternateDayStack(_ log: SupplementLog) -> some View {
        AppCard(padding: 0) {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    SectionHeader(title: "Alternate Day", subtitle: "Today is an alternate day")
                    Spacer()
                    Label("Active", systemImage: "arrow.2.circlepath")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(AppColors.purple)
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 10)

                suppToggleRow(
                    label: "Methylene Blue",
                    detail: "10ml",
                    icon: "drop.halffull",
                    color: AppColors.blue,
                    isOn: Binding(get: { log.methyleneBlue }, set: { log.methyleneBlue = $0; dataService?.save() })
                )
                suppToggleRow(
                    label: "Cumin Oil",
                    detail: "2–3mg",
                    icon: "leaf.circle.fill",
                    color: AppColors.yellow,
                    isOn: Binding(get: { log.cuminOil }, set: { log.cuminOil = $0; dataService?.save() })
                )
            }
        }
    }

    private var alternateDayInfo: some View {
        AppCard {
            HStack(spacing: 12) {
                Image(systemName: "arrow.2.circlepath")
                    .font(.system(size: 22))
                    .foregroundColor(AppColors.textSecondary)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Alternate Day Supplements")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(AppColors.textPrimary)
                    Text("Methylene Blue + Cumin Oil — not due today")
                        .font(.system(size: 12))
                        .foregroundColor(AppColors.textSecondary)
                }
            }
        }
    }

    // MARK: - Protein Supplements

    private func proteinSupplementsCard(_ log: SupplementLog) -> some View {
        AppCard(padding: 0) {
            VStack(alignment: .leading, spacing: 0) {
                SectionHeader(title: "Protein Supplements")
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 10)

                suppToggleRow(
                    label: "Whey Protein",
                    detail: "~50g",
                    icon: "cup.and.saucer.fill",
                    color: AppColors.blue,
                    isOn: Binding(get: { log.wheyDone }, set: { log.wheyDone = $0; dataService?.save() })
                )
                suppToggleRow(
                    label: "Clear Whey",
                    detail: "~40g",
                    icon: "drop.circle.fill",
                    color: AppColors.teal,
                    isOn: Binding(get: { log.clearWheyDone }, set: { log.clearWheyDone = $0; dataService?.save() })
                )
                suppToggleRow(
                    label: "Casein",
                    detail: "~50g (before bed)",
                    icon: "moon.fill",
                    color: AppColors.purple,
                    isOn: Binding(get: { log.caseinDone }, set: { log.caseinDone = $0; dataService?.save() })
                )
            }
        }
    }

    // MARK: - Timing Guide

    private var timingGuideCard: some View {
        AppCard {
            VStack(alignment: .leading, spacing: 10) {
                SectionHeader(title: "Timing Reference")
                timingRow("Morning (fasted)", "Omega-3, NAD+, Vitamin D+K2, Ashwagandha, Boron, Zinc")
                timingRow("Pre/During workout", "Creatine, Clear Whey (in workout drink with Himalayan salt)")
                timingRow("Post workout", "Whey, fast carbs (dates)")
                timingRow("With meals", "Glutamine, Magnesium")
                timingRow("Before bed", "Casein, Glycine, Magnesium")
            }
        }
    }

    private func timingRow(_ time: String, _ supplements: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(time)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(AppColors.purple)
            Text(supplements)
                .font(.system(size: 12))
                .foregroundColor(AppColors.textSecondary)
        }
    }

    // MARK: - Toggle Row

    private func suppToggleRow(label: String, detail: String, icon: String, color: Color, isOn: Binding<Bool>) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(color.opacity(isOn.wrappedValue ? 0.2 : 0.06))
                        .frame(width: 36, height: 36)
                    Image(systemName: icon)
                        .font(.system(size: 14))
                        .foregroundColor(isOn.wrappedValue ? color : color.opacity(0.4))
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
                Toggle("", isOn: isOn)
                    .labelsHidden()
                    .tint(color)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(isOn.wrappedValue ? color.opacity(0.04) : Color.clear)
            Divider().background(AppColors.cardBorder).padding(.leading, 64)
        }
    }

    // MARK: - Helpers

    private func markAllDaily(_ log: SupplementLog) {
        log.omega3 = true
        log.magnesium = true
        log.glycine = true
        log.nad = true
        log.ashwagandha = true
        log.urolithinA = true
        log.vitaminDK2 = true
        log.zinc = true
        log.boron = true
        log.creatine = true
        log.glutamine = true
    }

    private func setup() {
        let ds = DataService(modelContext: modelContext)
        dataService = ds
        let log = ds.fetchOrCreateTodayLog()
        if let existing = log.supplements {
            suppLog = existing
        } else {
            let newLog = SupplementLog(date: log.date, isAlternateDay: false)
            modelContext.insert(newLog)
            log.supplements = newLog
            suppLog = newLog
        }
        ds.save()
    }
}
