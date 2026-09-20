import Foundation
import HealthKit

/// minutos al aire libre que mide el sensor de luz del reloj (healthkit `timeInDaylight`).
struct DaylightService {
    struct Reading {
        var minutesByHour: [Date: Double]
        var lastSampleEnd: Date?
    }

    private let store = HKHealthStore()
    private let type = HKQuantityType(.timeInDaylight)

    /// hoy, por hora local. sin datos (o sin permiso) devuelve vacio: healthkit no distingue ambos casos.
    func today(now: Date) async -> Reading {
        guard HKHealthStore.isHealthDataAvailable() else { return Reading(minutesByHour: [:], lastSampleEnd: nil) }
        let start = Calendar.current.startOfDay(for: now)
        async let hourly = hourlyMinutes(from: start, to: now)
        async let last = lastSampleEnd(since: start)
        return Reading(minutesByHour: await hourly, lastSampleEnd: await last)
    }

    private func hourlyMinutes(from start: Date, to end: Date) async -> [Date: Double] {
        await withCheckedContinuation { c in
            let predicate = HKQuery.predicateForSamples(withStart: start, end: end)
            let q = HKStatisticsCollectionQuery(quantityType: type, quantitySamplePredicate: predicate, options: .cumulativeSum,
                                                anchorDate: start, intervalComponents: DateComponents(hour: 1))
            q.initialResultsHandler = { _, results, _ in
                var out: [Date: Double] = [:]
                results?.enumerateStatistics(from: start, to: end) { stat, _ in
                    if let m = stat.sumQuantity()?.doubleValue(for: .minute()), m > 0 { out[stat.startDate] = m }
                }
                c.resume(returning: out)
            }
            store.execute(q)
        }
    }

    private func lastSampleEnd(since start: Date) async -> Date? {
        await withCheckedContinuation { c in
            let predicate = HKQuery.predicateForSamples(withStart: start, end: nil)
            let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
            let q = HKSampleQuery(sampleType: type, predicate: predicate, limit: 1, sortDescriptors: [sort]) { _, samples, _ in
                c.resume(returning: samples?.first?.endDate)
            }
            store.execute(q)
        }
    }
}
