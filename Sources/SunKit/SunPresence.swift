import Foundation

/// si el sensor de luz del reloj (healthkit `timeInDaylight`) te tiene ahora mismo al sol o a la sombra.
public enum SunPresence: Equatable, Sendable {
    case direct, shade, unknown

    /// `lastSampleEnd` es el final del ultimo tramo que el sensor registro al aire libre; sin ese dato no se sabe nada.
    /// dentro de `freshWithin` desde entonces se asume que sigues al sol; mas viejo, que ya te moviste a la sombra.
    public static func now(lastSampleEnd: Date?, at now: Date, freshWithin: TimeInterval = 20 * 60) -> SunPresence {
        guard let lastSampleEnd else { return .unknown }
        return now.timeIntervalSince(lastSampleEnd) < freshWithin ? .direct : .shade
    }
}
