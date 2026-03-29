import SwiftUI
import SwiftData

struct CardioLogView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var selectedType: SessionType = .cardioVO2
    @State private var durationMinutes: Int = 45
    @State private var avgHR: Int = 0
    @State private var maxHR: Int = 0
    @State private var distanceKm: Double = 0
    @State private var notes: String = ""

    // Norwegian 4x4
    @State private var intervals: Int = 4
    @State private var intervalDuration: Int = 4
    @State private var restDuration: Int = 3

    private let cardioTypes: [SessionType] = [.cardioVO2, .cardioNorwegian, .cardioZone2]

    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.background.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 20) {
                        typeSelector
                        sessionInfoCard
                        if selectedType == .cardioNorwegian {
                            norwegianCard
                        }
                        durationCard
                        metricsCard
                        guidelinesCard
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle("Log Cardio")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(AppColors.background, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.foregroundColor(AppColors.textSecondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveSession() }
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(AppColors.orange)
                }
            }
        }
    }

    // MARK: - Type Selector

    private var typeSelector: some View {
        HStack(spacing: 10) {
            ForEach(cardioTypes, id: \.self) { type in
                Button { selectedType = type } label: {
                    VStack(spacing: 6) {
                        Image(systemName: type.icon)
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(selectedType == type ? .black : AppColors.forSessionType(type))
                        Text(type.rawValue)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(selectedType == type ? .black : AppColors.textSecondary)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(selectedType == type ? AppColors.forSessionType(type) : AppColors.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(
                        selectedType == type ? Color.clear : AppColors.cardBorder, lineWidth: 0.5
                    ))
                }
            }
        }
    }

    // MARK: - Session Info

    private var sessionInfoCard: some View {
        AppCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 12) {
                    Image(systemName: selectedType.icon)
                        .font(.system(size: 28))
                        .foregroundColor(AppColors.forSessionType(selectedType))
                    VStack(alignment: .leading, spacing: 3) {
                        Text(selectedType.rawValue)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(AppColors.textPrimary)
                        Text(sessionDescription)
                            .font(.system(size: 13))
                            .foregroundColor(AppColors.textSecondary)
                    }
                }
            }
        }
    }

    private var sessionDescription: String {
        switch selectedType {
        case .cardioVO2: return "High intensity running · ~80-90% max HR · Longevity & CV fitness"
        case .cardioNorwegian: return "4 × 4 min at 90-95% max HR · 3 min recovery · Max 1× per week"
        case .cardioZone2: return "Low intensity · ~60-70% max HR · Aerobic base & recovery support"
        default: return ""
        }
    }

    // MARK: - Duration

    private var durationCard: some View {
        AppCard {
            VStack(alignment: .leading, spacing: 10) {
                SectionHeader(title: "Duration")
                HStack {
                    Button { if durationMinutes > 10 { durationMinutes -= 5 } } label: {
                        Image(systemName: "minus.circle.fill")
                            .font(.system(size: 28))
                            .foregroundColor(AppColors.textSecondary)
                    }
                    Spacer()
                    VStack(spacing: 2) {
                        Text("\(durationMinutes)")
                            .font(.system(size: 48, weight: .bold, design: .rounded))
                            .foregroundColor(AppColors.textPrimary)
                        Text("minutes")
                            .font(.system(size: 13))
                            .foregroundColor(AppColors.textSecondary)
                    }
                    Spacer()
                    Button { durationMinutes += 5 } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 28))
                            .foregroundColor(AppColors.forSessionType(selectedType))
                    }
                }
            }
        }
    }

    // MARK: - Norwegian 4x4 Specifics

    private var norwegianCard: some View {
        AppCard {
            VStack(alignment: .leading, spacing: 14) {
                SectionHeader(title: "Norwegian 4×4 Structure")

                HStack(spacing: 20) {
                    intervalStepper(label: "Intervals", value: $intervals, min: 2, max: 6)
                    intervalStepper(label: "Work (min)", value: $intervalDuration, min: 2, max: 8)
                    intervalStepper(label: "Rest (min)", value: $restDuration, min: 1, max: 5)
                }

                HStack {
                    Image(systemName: "info.circle")
                        .font(.system(size: 12))
                        .foregroundColor(AppColors.red)
                    Text("Target: 90-95% max HR during work intervals")
                        .font(.system(size: 12))
                        .foregroundColor(AppColors.textSecondary)
                }
            }
        }
    }

    private func intervalStepper(label: String, value: Binding<Int>, min: Int, max: Int) -> some View {
        VStack(spacing: 6) {
            Text(label)
                .font(.system(size: 11))
                .foregroundColor(AppColors.textSecondary)
            HStack(spacing: 6) {
                Button { if value.wrappedValue > min { value.wrappedValue -= 1 } } label: {
                    Image(systemName: "minus.circle.fill").foregroundColor(AppColors.textSecondary).font(.system(size: 20))
                }
                Text("\(value.wrappedValue)")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(AppColors.textPrimary)
                    .frame(width: 32, alignment: .center)
                Button { if value.wrappedValue < max { value.wrappedValue += 1 } } label: {
                    Image(systemName: "plus.circle.fill").foregroundColor(AppColors.red).font(.system(size: 20))
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Metrics

    private var metricsCard: some View {
        AppCard {
            VStack(alignment: .leading, spacing: 14) {
                SectionHeader(title: "Metrics (optional)")
                HStack(spacing: 16) {
                    metricStepper(label: "Avg HR", value: $avgHR, step: 1, unit: "bpm", color: AppColors.red)
                    metricStepper(label: "Max HR", value: $maxHR, step: 1, unit: "bpm", color: AppColors.orange)
                    metricStepperDouble(label: "Distance", value: $distanceKm, step: 0.1, unit: "km", color: AppColors.green)
                }
                TextField("Notes (optional)", text: $notes, axis: .vertical)
                    .font(.system(size: 14))
                    .foregroundColor(AppColors.textPrimary)
                    .lineLimit(2...4)
                    .padding(.top, 4)
            }
        }
    }

    private func metricStepper(label: String, value: Binding<Int>, step: Int, unit: String, color: Color) -> some View {
        VStack(alignment: .center, spacing: 6) {
            Text(label)
                .font(.system(size: 11))
                .foregroundColor(AppColors.textSecondary)
            HStack(spacing: 4) {
                Button { if value.wrappedValue >= step { value.wrappedValue -= step } } label: {
                    Image(systemName: "minus.circle.fill").foregroundColor(AppColors.textSecondary)
                }
                VStack(spacing: 0) {
                    Text(value.wrappedValue == 0 ? "—" : "\(value.wrappedValue)")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(value.wrappedValue == 0 ? AppColors.textSecondary : AppColors.textPrimary)
                    Text(unit)
                        .font(.system(size: 9))
                        .foregroundColor(AppColors.textSecondary)
                }
                .frame(width: 42)
                Button { value.wrappedValue += step } label: {
                    Image(systemName: "plus.circle.fill").foregroundColor(color)
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func metricStepperDouble(label: String, value: Binding<Double>, step: Double, unit: String, color: Color) -> some View {
        VStack(alignment: .center, spacing: 6) {
            Text(label)
                .font(.system(size: 11))
                .foregroundColor(AppColors.textSecondary)
            HStack(spacing: 4) {
                Button { if value.wrappedValue >= step { value.wrappedValue -= step } } label: {
                    Image(systemName: "minus.circle.fill").foregroundColor(AppColors.textSecondary)
                }
                VStack(spacing: 0) {
                    Text(value.wrappedValue == 0 ? "—" : String(format: "%.1f", value.wrappedValue))
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(value.wrappedValue == 0 ? AppColors.textSecondary : AppColors.textPrimary)
                    Text(unit)
                        .font(.system(size: 9))
                        .foregroundColor(AppColors.textSecondary)
                }
                .frame(width: 42)
                Button { value.wrappedValue += step } label: {
                    Image(systemName: "plus.circle.fill").foregroundColor(color)
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Guidelines

    private var guidelinesCard: some View {
        AppCard {
            VStack(alignment: .leading, spacing: 10) {
                SectionHeader(title: "Weekly Caps")
                StatRow(label: "VO2 Max sessions", value: "1–2×", icon: "lungs.fill")
                StatRow(label: "Norwegian 4×4", value: "Max 1×", icon: "bolt.fill")
                StatRow(label: "Zone 2", value: "1×", icon: "heart.fill")
                StatRow(label: "Session duration", value: "~45 min", icon: "timer")
            }
        }
    }

    // MARK: - Save

    private func saveSession() {
        let ds = DataService(modelContext: modelContext)
        let todayLog = ds.fetchOrCreateTodayLog()
        let session = ds.createCardioSession(type: selectedType, for: todayLog)
        session.durationMinutes = durationMinutes
        session.avgHeartRate = avgHR > 0 ? avgHR : nil
        session.maxHeartRate = maxHR > 0 ? maxHR : nil
        session.distanceKm = distanceKm > 0 ? distanceKm : nil
        session.notes = notes
        session.completed = true
        if selectedType == .cardioNorwegian {
            session.intervals = intervals
            session.intervalDurationMinutes = intervalDuration
            session.restDurationMinutes = restDuration
        }
        todayLog.sessionType = selectedType
        ds.save()
        dismiss()
    }
}
