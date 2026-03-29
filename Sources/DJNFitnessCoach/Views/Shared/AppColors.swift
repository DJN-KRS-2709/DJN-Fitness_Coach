import SwiftUI

enum AppColors {
    static let accent = Color("AccentColor")
    static let background = Color(red: 0.07, green: 0.07, blue: 0.09)
    static let cardBackground = Color(red: 0.12, green: 0.12, blue: 0.15)
    static let cardBorder = Color(red: 0.22, green: 0.22, blue: 0.28)
    static let textPrimary = Color.white
    static let textSecondary = Color(red: 0.6, green: 0.6, blue: 0.65)
    static let green = Color(red: 0.2, green: 0.85, blue: 0.45)
    static let orange = Color(red: 1.0, green: 0.6, blue: 0.1)
    static let red = Color(red: 1.0, green: 0.25, blue: 0.25)
    static let blue = Color(red: 0.2, green: 0.55, blue: 1.0)
    static let purple = Color(red: 0.7, green: 0.3, blue: 1.0)
    static let teal = Color(red: 0.1, green: 0.8, blue: 0.8)
    static let yellow = Color(red: 1.0, green: 0.85, blue: 0.0)

    static func forSessionType(_ type: SessionType) -> Color {
        switch type {
        case .lifting: return blue
        case .cardioVO2: return orange
        case .cardioNorwegian: return red
        case .cardioZone2: return green
        case .rest: return purple
        case .recovery: return teal
        }
    }

    static func forRecoveryState(_ state: RecoveryState) -> Color {
        switch state {
        case .high: return green
        case .moderate: return yellow
        case .low: return red
        }
    }
}

// MARK: - Reusable Card

struct AppCard<Content: View>: View {
    let content: Content
    var padding: CGFloat = 16

    init(padding: CGFloat = 16, @ViewBuilder content: () -> Content) {
        self.padding = padding
        self.content = content()
    }

    var body: some View {
        content
            .padding(padding)
            .background(AppColors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(AppColors.cardBorder, lineWidth: 0.5)
            )
    }
}

// MARK: - Section Header

struct SectionHeader: View {
    let title: String
    var subtitle: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(AppColors.textSecondary)
                .textCase(.uppercase)
                .tracking(0.8)
            if let sub = subtitle {
                Text(sub)
                    .font(.system(size: 11))
                    .foregroundColor(AppColors.textSecondary.opacity(0.7))
            }
        }
    }
}

// MARK: - Macro Ring

struct MacroRingView: View {
    let label: String
    let current: Double
    let target: ClosedRange<Double>
    let color: Color
    let unit: String

    private var progress: Double {
        min(current / target.upperBound, 1.0)
    }

    private var isInRange: Bool {
        target.contains(current)
    }

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .stroke(color.opacity(0.15), lineWidth: 5)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(isInRange ? color : AppColors.orange, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.6), value: progress)
                VStack(spacing: 0) {
                    Text("\(Int(current))")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(AppColors.textPrimary)
                    Text(unit)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(AppColors.textSecondary)
                }
            }
            .frame(width: 64, height: 64)
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(AppColors.textSecondary)
        }
    }
}

// MARK: - Stat Row

struct StatRow: View {
    let label: String
    let value: String
    var valueColor: Color = AppColors.textPrimary
    var icon: String? = nil

    var body: some View {
        HStack {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 13))
                    .foregroundColor(AppColors.textSecondary)
                    .frame(width: 20)
            }
            Text(label)
                .font(.system(size: 14))
                .foregroundColor(AppColors.textSecondary)
            Spacer()
            Text(value)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(valueColor)
        }
    }
}

// MARK: - Score Picker

struct ScorePicker: View {
    let label: String
    @Binding var value: Int
    let range: ClosedRange<Int>
    let lowLabel: String
    let highLabel: String
    var color: Color = AppColors.accent

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(label)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(AppColors.textPrimary)
                Spacer()
                Text("\(value)")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(color)
                    .frame(width: 28)
            }
            HStack(spacing: 6) {
                Text(lowLabel)
                    .font(.system(size: 10))
                    .foregroundColor(AppColors.textSecondary)
                    .frame(width: 36, alignment: .leading)
                HStack(spacing: 4) {
                    ForEach(range, id: \.self) { i in
                        Circle()
                            .fill(i <= value ? color : AppColors.cardBorder)
                            .frame(width: 24, height: 24)
                            .overlay(
                                Text("\(i)")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundColor(i <= value ? .black : AppColors.textSecondary)
                            )
                            .onTapGesture { value = i }
                    }
                }
                Text(highLabel)
                    .font(.system(size: 10))
                    .foregroundColor(AppColors.textSecondary)
                    .frame(width: 36, alignment: .trailing)
            }
        }
    }
}

extension Color {
    static let appBackground = AppColors.background
    static let appCard = AppColors.cardBackground
}
