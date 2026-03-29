import SwiftUI

struct BodyMetricEntryView: View {
    @Environment(\.dismiss) private var dismiss
    var dataService: DataService

    @State private var weight: Double = 80.0
    @State private var bodyFat: Double = 9.5
    @State private var trackBodyFat = false

    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.background.ignoresSafeArea()
                VStack(spacing: 24) {
                    weightCard
                    bodyFatCard
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.top, 20)
            }
            .navigationTitle("Body Metrics")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(AppColors.background, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.foregroundColor(AppColors.textSecondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        dataService.saveBodyMetric(weightKg: weight, bodyFat: trackBodyFat ? bodyFat : nil)
                        dataService.save()
                        dismiss()
                    }
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(AppColors.blue)
                }
            }
        }
    }

    private var weightCard: some View {
        AppCard {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(title: "Morning Weight")
                HStack {
                    Button { if weight > 50 { weight -= 0.1 } } label: {
                        Image(systemName: "minus.circle.fill").font(.system(size: 30)).foregroundColor(AppColors.textSecondary)
                    }
                    Spacer()
                    VStack(spacing: 2) {
                        Text(String(format: "%.1f", weight))
                            .font(.system(size: 52, weight: .bold, design: .rounded))
                            .foregroundColor(AppColors.textPrimary)
                        Text("kg")
                            .font(.system(size: 16))
                            .foregroundColor(AppColors.textSecondary)
                    }
                    Spacer()
                    Button { weight += 0.1 } label: {
                        Image(systemName: "plus.circle.fill").font(.system(size: 30)).foregroundColor(AppColors.blue)
                    }
                }
                HStack {
                    Text("Target: ~80 kg")
                        .font(.system(size: 12))
                        .foregroundColor(AppColors.textSecondary)
                    Spacer()
                    let diff = weight - 80.0
                    Text(diff == 0 ? "On target" : (diff > 0 ? "+\(String(format: "%.1f", diff)) kg" : "\(String(format: "%.1f", diff)) kg"))
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(abs(diff) < 1.0 ? AppColors.green : AppColors.orange)
                }
            }
        }
    }

    private var bodyFatCard: some View {
        AppCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    SectionHeader(title: "Body Fat %")
                    Spacer()
                    Toggle("", isOn: $trackBodyFat)
                        .labelsHidden()
                        .tint(AppColors.blue)
                }
                if trackBodyFat {
                    HStack {
                        Button { if bodyFat > 5 { bodyFat -= 0.5 } } label: {
                            Image(systemName: "minus.circle.fill").font(.system(size: 30)).foregroundColor(AppColors.textSecondary)
                        }
                        Spacer()
                        VStack(spacing: 2) {
                            Text(String(format: "%.1f", bodyFat) + "%")
                                .font(.system(size: 48, weight: .bold, design: .rounded))
                                .foregroundColor(bodyFat <= 11 ? AppColors.green : AppColors.orange)
                            Text("body fat")
                                .font(.system(size: 13))
                                .foregroundColor(AppColors.textSecondary)
                        }
                        Spacer()
                        Button { bodyFat += 0.5 } label: {
                            Image(systemName: "plus.circle.fill").font(.system(size: 30)).foregroundColor(AppColors.blue)
                        }
                    }
                    Text("Target range: 8–11%")
                        .font(.system(size: 12))
                        .foregroundColor(AppColors.textSecondary)
                } else {
                    Text("Toggle on to log body fat estimate")
                        .font(.system(size: 13))
                        .foregroundColor(AppColors.textSecondary)
                }
            }
        }
    }
}
