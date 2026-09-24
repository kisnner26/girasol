import Foundation
import Localization

/// una hora del reloj segun la categoria "de pie" de Salud: si te pusiste de pie al menos un minuto o seguiste sentado.
public struct StandHour: Equatable, Sendable {
    public var hourStart: Date
    public var stood: Bool
    public init(hourStart: Date, stood: Bool) { self.hourStart = hourStart; self.stood = stood }
}

/// avisa a estirar cuando llevas mucho rato sin ponerte de pie.
public enum Posture {
    /// horas seguidas sentado hasta ahora, contando hacia atras desde la hora en curso. se detiene en la primera hora
    /// de pie o en la primera hora sin dato (para no inventar sedentarismo antes de que Salud tuviera registros).
    public static func consecutiveSedentaryHours(_ hours: [StandHour], now: Date, calendar: Calendar = .current) -> Int {
        let byHour = Dictionary(hours.map { (calendar.dateInterval(of: .hour, for: $0.hourStart)?.start ?? $0.hourStart, $0.stood) },
                                uniquingKeysWith: { a, b in a || b })
        var cursor = calendar.dateInterval(of: .hour, for: now)?.start ?? now
        var count = 0
        while let stood = byHour[cursor], !stood {
            count += 1
            guard let prev = calendar.date(byAdding: .hour, value: -1, to: cursor) else { break }
            cursor = prev
        }
        return count
    }

    /// una sola vez por bloque de `thresholdHours` horas seguidas sentado (2 h por defecto).
    public static func shouldRemind(consecutiveHours: Int, thresholdHours: Int = 2) -> Bool {
        thresholdHours > 0 && consecutiveHours > 0 && consecutiveHours % thresholdHours == 0
    }

    public static func title() -> String { L10n.tr("hora de estirar") }

    public static func body(hours: Int) -> String {
        hours == 1 ? L10n.tr("llevas 1 hora sentado. levántate y estira cuello y muñecas.")
                   : L10n.tr("llevas %d horas sentado. levántate y estira cuello y muñecas.", hours)
    }
}
