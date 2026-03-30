import SwiftUI
import SwiftData

struct RecoveryCheckInView: View {
    @Environment(\.dismiss) private var dismiss
    var dailyLog: DailyLog
    var dataService: DataService
    var onComplete: () -> Void

    @State private var recovery: RecoveryLog?
    @State private var sleepHours: Double = 7.5
    @State private var isSyncingHealth = false
    @State private var sleepQuality: Int = 4
    @State private var rhr: Int = 0
    @State private var energyScore: Int = 4
    @State private var motivationScore: Int = 4
    @State private var sorenessScore: Int = 2
    @State private var stressScore: Int = 2
    @State private var libido: LibidoStatus = .normal
    @State private var perceivedRecovery: Int = 8
    @State private var notes: String = ""
    @State private var steps: Int = 0

    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.background.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 20) {
                        recoveryStatePreview
                        sleepCard
                        biofeedbackCard
                        hrCard
                        stepsCard
                        notesCard
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle("Recovery Check-In")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(AppColors.background, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.foregroundColor(AppColors.textSecondary)
                }
                ToolbarItem(placement: .principal) {
                    if HealthKitService.shared.isAuthorized {
                        Button {
                            Task { await syncFromHealth() }
                        } label: {
                            Label(isSyncingHealth ? "Syncing…" : "Sync Health", systemImage: "heart.text.square.fill")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(AppColors.red)
                        }
                        .disabled(isSyncingHealth)
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveAndDismiss() }
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(AppColors.green)
                }
            }
        }
        .onAppear { loadExisting() }
    }

    // MARK: - Recovery State Preview

    private var recoveryStatePreview: some View {
        let state = computedRecoveryState
        return AppCard {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(AppColors.forRecoveryState(state).opacity(0.15))
                        .frame(width: 60, height: 60)
                    Image(systemName: state.icon)
                        .font(.system(size: 26))
                        .foregroundColor(AppColors.forRecoveryState(state))
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(state.rawValue + " Recovery")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(AppColors.textPrimary)
                    Text(stateDescription(state))
                        .font(.system(size: 13))
                        .foregroundColor(AppColors.textSecondary)
                        .lineLimit(2)
                }
                Spacer()
            }
        }
    }

    private func stateDescription(_ state: RecoveryState) -> String {
        switch state {
        case .high: return "Proceed as planned — high intensity cleared"
        case .moderate: return "Reduce volume ~15%, consider Zone 2 over VO2"
        case .low: return "Block high intensity — prioritise Zone 2 or rest"
        }
    }

    // MARK: - Sleep

    private var sleepCard: some View {
        AppCard {
            VStack(alignment: .leading, spacing: 16) {
                SectionHeader(title: "Sleep")

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Hours slept")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(AppColors.textPrimary)
                        Spacer()
                        Text(String(format: "%.1f h", sleepHours))
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundColor(sleepHours >= 7 ? AppColors.green : AppColors.orange)
                    }
                    Slider(value: $sleepHours, in: 3...10, step: 0.25)
                        .tint(sleepHours >= 7 ? AppColors.green : AppColors.orange)
                }

                ScorePicker(
                    label: "Sleep Quality",
                    value: $sleepQuality,
                    range: 1...5,
                    lowLabel: "Poor",
                    highLabel: "Great",
                    color: AppColors.purple
                )
            }
        }
    }

    // MARK: - Biofeedback

    private var biofeedbackCard: some View {
        AppCard {
            VStack(alignment: .leading, spacing: 16) {
                SectionHeader(title: "Biofeedback")

                ScorePicker(label: "Energy", value: $energyScore, range: 1...5, lowLabel: "Crashed", highLabel: "High", color: AppColors.yellow)
                Divider().background(AppColors.cardBorder)
                ScorePicker(label: "Motivation", value: $motivationScore, range: 1...5, lowLabel: "None", highLabel: "Peak", color: AppColors.blue)
                Divider().background(AppColors.cardBorder)
                ScorePicker(label: "Soreness", value: $sorenessScore, range: 1...5, lowLabel: "None", highLabel: "Very sore", color: AppColors.orange)
                Divider().background(AppColors.cardBorder)
                ScorePicker(label: "Stress", value: $stressScore, range: 1...5, lowLabel: "None", highLabel: "High", color: AppColors.red)
                Divider().background(AppColors.cardBorder)
                ScorePicker(label: "Perceived Recovery", value: $perceivedRecovery, range: 1...10, lowLabel: "Wrecked", highLabel: "100%", color: AppColors.green)
                Divider().background(AppColors.cardBorder)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Libido")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(AppColors.textPrimary)
                    HStack(spacing: 10) {
                        ForEach(LibidoStatus.allCases, id: \.self) { status in
                            Button {
                                libido = status
                            } label: {
                                Text(status.rawValue)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(libido == status ? .black : AppColors.textSecondary)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 7)
                                    .background(libido == status ? AppColors.blue : AppColors.cardBorder.opacity(0.3))
                                    .clipShape(Capsule())
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - HR Card

    private var hrCard: some View {
        AppCard {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(title: "Resting Heart Rate (optional)")
                HStack {
                    Button { if rhr > 0 { rhr -= 1 } } label: {
                        Image(systemName: "minus.circle.fill").font(.system(size: 26)).foregroundColor(AppColors.textSecondary)
                    }
                    Spacer()
                    VStack(spacing: 2) {
                        Text(rhr == 0 ? "—" : "\(rhr)")
                            .font(.system(size: 40, weight: .bold, design: .rounded))
                            .foregroundColor(rhr == 0 ? AppColors.textSecondary : heartRateColor)
                        Text("bpm")
                            .font(.system(size: 13))
                            .foregroundColor(AppColors.textSecondary)
                    }
                    Spacer()
                    Button { rhr += 1 } label: {
                        Image(systemName: "plus.circle.fill").font(.system(size: 26)).foregroundColor(AppColors.red)
                    }
                }
                if rhr > 0 {
                    Text(rhr <= 55 ? "Baseline or below — good sign" : rhr <= 65 ? "Normal range" : "Elevated — factor into recovery")
                        .font(.system(size: 12))
                        .foregroundColor(heartRateColor)
                }
            }
        }
    }

    private var heartRateColor: Color {
        guard rhr > 0 else { return AppColors.textSecondary }
        if rhr <= 55 { return AppColors.green }
        if rhr <= 65 { return AppColors.yellow }
        return AppColors.red
    }

    // MARK: - Steps

    private var stepsCard: some View {
        AppCard {
            VStack(alignment: .leading, spacing: 10) {
                SectionHeader(title: "Steps (optional)")
                HStack {
                    Button { if steps >= 500 { steps -= 500 } } label: {
                        Image(systemName: "minus.circle.fill").font(.system(size: 26)).foregroundColor(AppColors.textSecondary)
                    }
                    Spacer()
                    VStack(spacing: 2) {
                        Text(steps == 0 ? "—" : "\(steps)")
                            .font(.system(size: 40, weight: .bold, design: .rounded))
                            .foregroundColor(steps >= 8000 ? AppColors.green : AppColors.textPrimary)
                        Text("steps")
                            .font(.system(size: 13))
                            .foregroundColor(AppColors.textSecondary)
                    }
                    Spacer()
                    Button { steps += 500 } label: {
                        Image(systemName: "plus.circle.fill").font(.system(size: 26)).foregroundColor(AppColors.green)
                    }
                }
            }
        }
    }

    // MARK: - Notes

    private var notesCard: some View {
        AppCard {
            VStack(alignment: .leading, spacing: 8) {
                SectionHeader(title: "Notes")
                TextField("How are you feeling today?", text: $notes, axis: .vertical)
                    .font(.system(size: 14))
                    .foregroundColor(AppColors.textPrimary)
                    .lineLimit(3...6)
            }
        }
    }

    // MARK: - Computed State

    private var computedRecoveryState: RecoveryState {
        var lowMarkers = 0
        if sleepQuality <= 2 { lowMarkers += 1 }
        if energyScore <= 2 { lowMarkers += 1 }
        if motivationScore <= 2 { lowMarkers += 1 }
        if sorenessScore >= 4 { lowMarkers += 1 }
        if stressScore >= 4 { lowMarkers += 1 }
        if libido == .low { lowMarkers += 1 }
        if rhr > 65 { lowMarkers += 1 }
        switch lowMarkers {
        case 0...1: return .high
        case 2...3: return .moderate
        default: return .low
        }
    }

    // MARK: - Health Sync

    private func syncFromHealth() async {
        isSyncingHealth = true
        let hk = HealthKitService.shared
        await hk.refreshSnapshot()
        let h = hk.snapshot
        if let sl = h.sleepHours { sleepHours = min(10, max(3, sl)) }
        if let rhrVal = h.restingHR { rhr = Int(rhrVal) }
        if let st = h.steps { steps = st }
        isSyncingHealth = false
    }

    // MARK: - Load / Save

    private func loadExisting() {
        if let existing = dailyLog.recovery {
            sleepHours = existing.sleepHours
            sleepQuality = existing.sleepQuality
            rhr = existing.restingHeartRate ?? 0
            energyScore = existing.energyScore
            motivationScore = existing.motivationScore
            sorenessScore = existing.sorenessScore
            stressScore = existing.stressScore
            libido = existing.libidoStatus
            perceivedRecovery = existing.perceivedRecoveryScore
            notes = existing.notes
            steps = existing.steps
        }
    }

    private func saveAndDismiss() {
        let rec = dataService.fetchOrCreateRecoveryLog(for: dailyLog)
        rec.sleepHours = sleepHours
        rec.sleepQuality = sleepQuality
        rec.restingHeartRate = rhr > 0 ? rhr : nil
        rec.energyScore = energyScore
        rec.motivationScore = motivationScore
        rec.sorenessScore = sorenessScore
        rec.stressScore = stressScore
        rec.libidoStatus = libido
        rec.perceivedRecoveryScore = perceivedRecovery
        rec.notes = notes
        rec.steps = steps
        dataService.save()
        onComplete()
        dismiss()
    }
}
