import Foundation
import HealthKit

// MARK: - Resting Energy Trend

enum RestingEnergyTrend: Equatable {
    case increasing(delta: Int)
    case decreasing(delta: Int)
    case stable

    var symbol: String {
        switch self {
        case .increasing(let d): return "↑ +\(d) kcal vs prior week"
        case .decreasing(let d): return "↓ −\(d) kcal vs prior week"
        case .stable:            return "Stable"
        }
    }

    var color: String {
        switch self {
        case .increasing: return "orange"
        case .decreasing: return "red"
        case .stable:     return "green"
        }
    }
}

// MARK: - Health Snapshot

struct HealthSnapshot {
    var restingHR: Double?         // bpm
    var hrv: Double?               // ms (SDNN)
    var sleepHours: Double?        // hours
    var steps: Int?
    var activeCalories: Int?
    var basalCalories: Int?        // resting metabolic rate kcal
    var bodyWeight: Double?        // kg
    var bodyFat: Double?           // %
    var vo2Max: Double?            // mL/kg/min

    var tdee: Int? {
        guard let a = activeCalories, let b = basalCalories else { return nil }
        return a + b
    }

    var isAvailable: Bool {
        restingHR != nil || hrv != nil || sleepHours != nil || steps != nil || activeCalories != nil
    }

    var recoverySignalText: String {
        var parts: [String] = []
        if let hr = restingHR { parts.append("RHR \(Int(hr)) bpm") }
        if let h = hrv { parts.append("HRV \(Int(h)) ms") }
        if let s = sleepHours { parts.append(String(format: "Sleep %.1fh", s)) }
        if let st = steps { parts.append("\(st) steps") }
        return parts.isEmpty ? "No data" : parts.joined(separator: " · ")
    }
}

// MARK: - HealthKit Service

@MainActor
class HealthKitService: ObservableObject {
    static let shared = HealthKitService()

    @Published var isAuthorized = false
    @Published var snapshot = HealthSnapshot()

    /// Median resting energy (kcal) computed over last 30 complete days from HealthKit.
    @Published var restingEnergyMedian: Int?
    /// Trend vs prior week.
    @Published var restingEnergyTrend: RestingEnergyTrend = .stable
    /// Raw daily values, newest first (up to 30 days). Used for sparkline / debug.
    @Published var restingEnergyHistory: [Int] = []

    private let store = HKHealthStore()

    // Live activity observer
    private var activityObserverQuery: HKObserverQuery?
    private var lastActivityRefresh: Date = .distantPast

    // Cache keys
    private let cacheHistoryKey = "djn_resting_history_v1"
    private let cacheDateKey    = "djn_resting_history_date"

    private var readTypes: Set<HKObjectType> {
        var types: Set<HKObjectType> = []
        let quantityIDs: [HKQuantityTypeIdentifier] = [
            .restingHeartRate,
            .heartRateVariabilitySDNN,
            .stepCount,
            .bodyMass,
            .bodyFatPercentage,
            .vo2Max,
            .activeEnergyBurned,
            .basalEnergyBurned
        ]
        for id in quantityIDs {
            types.insert(HKQuantityType(id))
        }
        types.insert(HKCategoryType(.sleepAnalysis))
        return types
    }

    var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    // MARK: - Authorization

    func requestAuthorization() async {
        guard isAvailable else { return }
        // HealthKit always "succeeds" - user grants/denies per type silently
        try? await store.requestAuthorization(toShare: [], read: readTypes)
        isAuthorized = true
        await refreshSnapshot()
        startObservingActivityCalories()
    }

    // MARK: - Live Activity Observer

    /// Registers an HKObserverQuery so activity calories refresh automatically
    /// whenever the Watch / Health app writes new data — no user action needed.
    private func startObservingActivityCalories() {
        guard isAvailable, activityObserverQuery == nil else { return }
        let type = HKQuantityType(.activeEnergyBurned)

        let query = HKObserverQuery(sampleType: type, predicate: nil) { [weak self] _, completionHandler, error in
            guard error == nil else { completionHandler(); return }
            // Hop back to MainActor — the handler fires on a HealthKit background thread
            Task { @MainActor [weak self] in
                await self?.refreshActivityIfNeeded()
            }
            completionHandler()
        }

        activityObserverQuery = query
        store.execute(query)
    }

    /// Re-fetches only active + basal calories for today. Throttled to at most
    /// once per 60 seconds to avoid hammering HealthKit on rapid-fire updates.
    private func refreshActivityIfNeeded() async {
        guard Date().timeIntervalSince(lastActivityRefresh) > 60 else { return }
        lastActivityRefresh = Date()

        async let cals  = fetchActiveCalories(for: Date())
        async let basal = fetchBasalCalories(for: Date())
        let (c, b) = await (cals, basal)

        var updated = snapshot
        if let c { updated.activeCalories = c }
        if let b { updated.basalCalories  = b }
        snapshot = updated
    }

    // MARK: - Refresh All

    func refreshSnapshot(for date: Date = Date()) async {
        async let rhr    = fetchRestingHR(for: date)
        async let hrv    = fetchHRV(for: date)
        async let sleep  = fetchSleepHours(for: date)
        async let steps  = fetchSteps(for: date)
        async let cals   = fetchActiveCalories(for: date)
        async let basal  = fetchBasalCalories(for: date)
        async let weight = fetchLatestBodyWeight()
        async let fat    = fetchLatestBodyFat()
        async let vo2    = fetchLatestVO2Max()

        let (r, h, sl, st, c, b, w, f, v) = await (rhr, hrv, sleep, steps, cals, basal, weight, fat, vo2)

        snapshot = HealthSnapshot(
            restingHR: r, hrv: h, sleepHours: sl, steps: st,
            activeCalories: c, basalCalories: b,
            bodyWeight: w, bodyFat: f, vo2Max: v
        )

        // Resting energy: use cache if fresh, otherwise fetch 30-day history
        await refreshRestingEnergyHistory()
    }

    // MARK: - Resting Energy History

    func refreshRestingEnergyHistory(force: Bool = false) async {
        // Use cached data if less than 12 h old and not forced
        if !force, let cached = loadCachedHistory(), !cached.isEmpty {
            applyHistory(cached)
            return
        }
        // Fetch last 30 complete days (skip today — it's partial)
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        var values: [Double] = []
        for offset in 1...30 {
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else { continue }
            if let v = await fetchSumQuantity(.basalEnergyBurned, unit: .kilocalorie(), for: day),
               v > 1200 {   // sanity: ignore obviously incomplete readings
                values.append(v)
            }
        }
        guard !values.isEmpty else { return }
        cacheHistory(values)
        applyHistory(values)
    }

    private func applyHistory(_ values: [Double]) {
        let median = computeMedian(values)
        let trend  = computeTrend(values)
        restingEnergyHistory = values.map { Int($0) }
        restingEnergyMedian  = Int(median)
        restingEnergyTrend   = trend
    }

    private func computeMedian(_ values: [Double]) -> Double {
        let sorted = values.sorted()
        let mid = sorted.count / 2
        return sorted.count % 2 == 0
            ? (sorted[mid - 1] + sorted[mid]) / 2
            : sorted[mid]
    }

    private func computeTrend(_ values: [Double]) -> RestingEnergyTrend {
        guard values.count >= 14 else { return .stable }
        // values[0] = most recent completed day
        let recentMedian   = computeMedian(Array(values.prefix(7)))
        let previousMedian = computeMedian(Array(values[7..<14]))
        let delta = Int(recentMedian - previousMedian)
        if  delta >=  40 { return .increasing(delta:  delta) }
        if  delta <= -40 { return .decreasing(delta: -delta) }
        return .stable
    }

    // MARK: - Cache

    private func cacheHistory(_ values: [Double]) {
        UserDefaults.standard.set(Date(), forKey: cacheDateKey)
        if let data = try? JSONEncoder().encode(values) {
            UserDefaults.standard.set(data, forKey: cacheHistoryKey)
        }
    }

    private func loadCachedHistory() -> [Double]? {
        guard let date = UserDefaults.standard.object(forKey: cacheDateKey) as? Date,
              Date().timeIntervalSince(date) < 12 * 3600,
              let data = UserDefaults.standard.data(forKey: cacheHistoryKey),
              let values = try? JSONDecoder().decode([Double].self, from: data)
        else { return nil }
        return values
    }

    // MARK: - Individual Fetches

    func fetchRestingHR(for date: Date) async -> Double? {
        // Try today first, fall back to most recent ever (Watch measures once in morning)
        await fetchMostRecentQuantity(.restingHeartRate, unit: .count().unitDivided(by: .minute()))
    }

    func fetchHRV(for date: Date) async -> Double? {
        await fetchMostRecentQuantity(.heartRateVariabilitySDNN, unit: .secondUnit(with: .milli))
    }

    func fetchSteps(for date: Date) async -> Int? {
        // Today's steps — if nil try yesterday
        if let sum = await fetchSumQuantity(.stepCount, unit: .count(), for: date), sum > 0 {
            return Int(sum)
        }
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: date)!
        guard let sum = await fetchSumQuantity(.stepCount, unit: .count(), for: yesterday) else { return nil }
        return Int(sum)
    }

    func fetchActiveCalories(for date: Date) async -> Int? {
        if let sum = await fetchSumQuantity(.activeEnergyBurned, unit: .kilocalorie(), for: date), sum > 0 {
            return Int(sum)
        }
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: date)!
        guard let sum = await fetchSumQuantity(.activeEnergyBurned, unit: .kilocalorie(), for: yesterday) else { return nil }
        return Int(sum)
    }

    func fetchBasalCalories(for date: Date) async -> Int? {
        if let sum = await fetchSumQuantity(.basalEnergyBurned, unit: .kilocalorie(), for: date), sum > 0 {
            return Int(sum)
        }
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: date)!
        guard let sum = await fetchSumQuantity(.basalEnergyBurned, unit: .kilocalorie(), for: yesterday) else { return nil }
        return Int(sum)
    }

    func fetchLatestBodyWeight() async -> Double? {
        await fetchMostRecentQuantity(.bodyMass, unit: .gramUnit(with: .kilo))
    }

    func fetchLatestBodyFat() async -> Double? {
        guard let val = await fetchMostRecentQuantity(.bodyFatPercentage, unit: .percent()) else { return nil }
        // Renpho stores as fraction (0.15) not percentage (15) — handle both
        return val > 1.0 ? val : val * 100
    }

    func fetchLatestVO2Max() async -> Double? {
        let unit = HKUnit.literUnit(with: .milli).unitDivided(by: HKUnit.gramUnit(with: .kilo).unitMultiplied(by: .minute()))
        return await fetchMostRecentQuantity(.vo2Max, unit: unit)
    }

    func fetchSleepHours(for date: Date) async -> Double? {
        let calendar = Calendar.current
        // Look back 3 days to find most recent sleep session
        let start = calendar.date(byAdding: .day, value: -3, to: date)!
        let end = calendar.date(bySettingHour: 14, minute: 0, second: 0, of: date)!
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end)
        let sleepType = HKCategoryType(.sleepAnalysis)

        return await withCheckedContinuation { continuation in
            let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
            let query = HKSampleQuery(sampleType: sleepType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [sort]) { _, samples, _ in
                guard let samples = samples as? [HKCategorySample], !samples.isEmpty else {
                    continuation.resume(returning: nil)
                    return
                }
                // Group by night: find the most recent batch of samples
                let asleepValues: Set<Int> = [
                    HKCategoryValueSleepAnalysis.asleepCore.rawValue,
                    HKCategoryValueSleepAnalysis.asleepDeep.rawValue,
                    HKCategoryValueSleepAnalysis.asleepREM.rawValue,
                    HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue
                ]
                // Use the most recent sample's end date as reference night
                guard let latestEnd = samples.first?.endDate else {
                    continuation.resume(returning: nil)
                    return
                }
                let nightStart = calendar.date(byAdding: .hour, value: -16, to: latestEnd)!
                let nightSamples = samples.filter {
                    $0.endDate >= nightStart && asleepValues.contains($0.value)
                }
                let totalSeconds = nightSamples.reduce(0.0) {
                    $0 + $1.endDate.timeIntervalSince($1.startDate)
                }
                let hours = totalSeconds / 3600
                continuation.resume(returning: hours > 1 ? hours : nil)
            }
            self.store.execute(query)
        }
    }

    // MARK: - Private Helpers

    private func fetchLatestQuantity(_ identifier: HKQuantityTypeIdentifier, unit: HKUnit, for date: Date) async -> Double? {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: date)
        let end = calendar.date(byAdding: .day, value: 1, to: start)!
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end)
        let type = HKQuantityType(identifier)

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: type,
                predicate: predicate,
                limit: 1,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)]
            ) { _, samples, _ in
                let value = (samples?.first as? HKQuantitySample)?.quantity.doubleValue(for: unit)
                continuation.resume(returning: value)
            }
            store.execute(query)
        }
    }

    private func fetchMostRecentQuantity(_ identifier: HKQuantityTypeIdentifier, unit: HKUnit) async -> Double? {
        let type = HKQuantityType(identifier)
        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: type,
                predicate: nil,
                limit: 1,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)]
            ) { _, samples, _ in
                let value = (samples?.first as? HKQuantitySample)?.quantity.doubleValue(for: unit)
                continuation.resume(returning: value)
            }
            store.execute(query)
        }
    }

    private func fetchSumQuantity(_ identifier: HKQuantityTypeIdentifier, unit: HKUnit, for date: Date) async -> Double? {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: date)
        let end = calendar.date(byAdding: .day, value: 1, to: start)!
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end)
        let type = HKQuantityType(identifier)

        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: type,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, stats, _ in
                let value = stats?.sumQuantity()?.doubleValue(for: unit)
                continuation.resume(returning: value)
            }
            store.execute(query)
        }
    }
}
