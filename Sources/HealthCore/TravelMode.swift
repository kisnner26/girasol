import Foundation

/// detecta un salto grande de zona horaria (un viaje real) a partir del desfase utc del lugar donde estas,
/// y como correr los horarios de sueño ese mismo numero de horas.
public enum TravelMode {
    /// diferencia en horas completas entre dos desfases utc (en segundos).
    public static func hourShift(fromOffsetSeconds: Int, toOffsetSeconds: Int) -> Int {
        Int((Double(toOffsetSeconds - fromOffsetSeconds) / 3600).rounded())
    }

    /// un cambio de 1 h (horario de verano) no cuenta como viaje; a partir de 2 h si.
    public static func isTravel(hourShift: Int) -> Bool {
        abs(hourShift) >= 2
    }

    /// desplaza una hora del dia el mismo numero de horas que el viaje, dando la vuelta al reloj de 24 h.
    public static func shiftedHour(_ hour: Int, by shift: Int) -> Int {
        ((hour + shift) % 24 + 24) % 24
    }
}
