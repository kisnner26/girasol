import Foundation
import HealthKit
import HealthCore

struct OxygenReading: Identifiable, Equatable {
    let id = UUID()
    let percent: Double
    let date: Date
}

struct BodyInfo {
    var sex: Sex?
    var birthYear: Int?
    var heightCm: Double?
    var weightKg: Double?
}

struct TodayTotals {
    var waterMl = 0
    var foodKcal = 0.0
    var activeKcal = 0.0
    var steps = 0.0
    var mindfulMinutes = 0.0
}

struct HeartInfo {
    var latest: Double?
    var latestDate: Date?
    var resting: Double?
}

/// unico punto de acceso a healthkit: lectura de tu dia y escritura de agua, comida y respiracion.
final class HealthStore: @unchecked Sendable {
    static let shared = HealthStore()

    private let store = HKHealthStore()
    var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    private let water = HKQuantityType(.dietaryWater)
    private let energyIn = HKQuantityType(.dietaryEnergyConsumed)
    private let mindful = HKCategoryType(.mindfulSession)

    private var shareTypes: Set<HKSampleType> { [water, energyIn, mindful] }
    private var readTypes: Set<HKObjectType> {
        [water, energyIn, mindful,
         HKQuantityType(.timeInDaylight), HKQuantityType(.activeEnergyBurned), HKQuantityType(.stepCount),
         HKQuantityType(.heartRate), HKQuantityType(.restingHeartRate), HKQuantityType(.oxygenSaturation),
         HKQuantityType(.bodyMass), HKQuantityType(.height),
         HKCharacteristicType(.dateOfBirth), HKCharacteristicType(.biologicalSex)]
    }

    private let ml = HKUnit.literUnit(with: .milli)
    private let kcal = HKUnit.kilocalorie()
    private let bpm = HKUnit.count().unitDivided(by: .minute())

    func requestAccess() async {
        guard isAvailable else { return }
        try? await store.requestAuthorization(toShare: shareTypes, read: readTypes)
    }

    // MARK: lectura

    private func sum(_ type: HKQuantityType, _ unit: HKUnit, since start: Date) async -> Double {
        await withCheckedContinuation { c in
            let q = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: HKQuery.predicateForSamples(withStart: start, end: nil),
                                      options: .cumulativeSum) { _, stats, _ in
                c.resume(returning: stats?.sumQuantity()?.doubleValue(for: unit) ?? 0)
            }
            store.execute(q)
        }
    }

    private func recent(_ type: HKQuantityType, limit: Int = 1, since: Date? = nil) async -> [HKQuantitySample] {
        await withCheckedContinuation { c in
            let predicate = since.map { HKQuery.predicateForSamples(withStart: $0, end: nil) }
            let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
            let q = HKSampleQuery(sampleType: type, predicate: predicate, limit: limit, sortDescriptors: [sort]) { _, samples, _ in
                c.resume(returning: (samples as? [HKQuantitySample]) ?? [])
            }
            store.execute(q)
        }
    }

    func today(now: Date) async -> TodayTotals {
        guard isAvailable else { return TodayTotals() }
        let start = Calendar.current.startOfDay(for: now)
        async let w = sum(water, ml, since: start)
        async let f = sum(energyIn, kcal, since: start)
        async let a = sum(HKQuantityType(.activeEnergyBurned), kcal, since: start)
        async let s = sum(HKQuantityType(.stepCount), .count(), since: start)
        async let m = mindfulMinutes(since: start)
        return await TodayTotals(waterMl: Int(w.rounded()), foodKcal: f, activeKcal: a, steps: s, mindfulMinutes: m)
    }

    private func mindfulMinutes(since start: Date) async -> Double {
        await withCheckedContinuation { c in
            let q = HKSampleQuery(sampleType: mindful, predicate: HKQuery.predicateForSamples(withStart: start, end: nil),
                                  limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, _ in
                c.resume(returning: (samples ?? []).reduce(0) { $0 + $1.endDate.timeIntervalSince($1.startDate) / 60 })
            }
            store.execute(q)
        }
    }

    func heart() async -> HeartInfo {
        guard isAvailable else { return HeartInfo() }
        let day = Date().addingTimeInterval(-24 * 3600)
        let latest = await recent(HKQuantityType(.heartRate), since: day).first
        let resting = await recent(HKQuantityType(.restingHeartRate), since: Date().addingTimeInterval(-7 * 24 * 3600)).first
        return HeartInfo(latest: latest?.quantity.doubleValue(for: bpm), latestDate: latest?.endDate,
                         resting: resting?.quantity.doubleValue(for: bpm))
    }

    /// mediciones de oxigeno de las ultimas 48 h, la mas reciente primero.
    func oxygen() async -> [OxygenReading] {
        guard isAvailable else { return [] }
        let samples = await recent(HKQuantityType(.oxygenSaturation), limit: 40, since: Date().addingTimeInterval(-48 * 3600))
        return samples.map { OxygenReading(percent: $0.quantity.doubleValue(for: .percent()) * 100, date: $0.endDate) }
    }

    func body() async -> BodyInfo {
        guard isAvailable else { return BodyInfo() }
        var info = BodyInfo()
        if let comps = try? store.dateOfBirthComponents() { info.birthYear = comps.year }
        if let sex = try? store.biologicalSex().biologicalSex {
            switch sex {
            case .female: info.sex = .female
            case .male: info.sex = .male
            case .other: info.sex = .other
            default: break
            }
        }
        info.weightKg = await recent(HKQuantityType(.bodyMass)).first?.quantity.doubleValue(for: .gramUnit(with: .kilo))
        info.heightCm = await recent(HKQuantityType(.height)).first?.quantity.doubleValue(for: .meterUnit(with: .centi))
        return info
    }

    // MARK: escritura

    @discardableResult
    func addWater(ml amount: Int, at date: Date = Date()) async -> Bool {
        guard isAvailable, amount > 0 else { return false }
        let s = HKQuantitySample(type: water, quantity: HKQuantity(unit: ml, doubleValue: Double(amount)), start: date, end: date)
        return (try? await store.save(s)) != nil
    }

    @discardableResult
    func addFood(kcal amount: Double, at date: Date = Date()) async -> Bool {
        guard isAvailable, amount > 0 else { return false }
        let s = HKQuantitySample(type: energyIn, quantity: HKQuantity(unit: kcal, doubleValue: amount), start: date, end: date)
        return (try? await store.save(s)) != nil
    }

    @discardableResult
    func addMindful(start: Date, end: Date) async -> Bool {
        guard isAvailable, end > start else { return false }
        let s = HKCategorySample(type: mindful, value: HKCategoryValue.notApplicable.rawValue, start: start, end: end)
        return (try? await store.save(s)) != nil
    }

    /// borra el ultimo registro de agua o comida de hoy que hizo esta app (healthkit solo deja borrar lo propio).
    enum Kind { case water, food }
    @discardableResult
    func undoLast(_ kind: Kind) async -> Bool {
        guard isAvailable else { return false }
        let type: HKSampleType = kind == .water ? water : energyIn
        let start = Calendar.current.startOfDay(for: Date())
        let predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
            HKQuery.predicateForObjects(from: HKSource.default()), HKQuery.predicateForSamples(withStart: start, end: nil)])
        let sample: HKSample? = await withCheckedContinuation { c in
            let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
            let q = HKSampleQuery(sampleType: type, predicate: predicate, limit: 1, sortDescriptors: [sort]) { _, s, _ in c.resume(returning: s?.first) }
            store.execute(q)
        }
        guard let sample else { return false }
        return (try? await store.delete(sample)) != nil
    }
}
