import Foundation
import Localization

/// ritmo de trabajo: minutos de enfoque, descanso corto y descanso largo cada cierto numero de rondas.
public struct FocusPlan: Sendable, Equatable, Codable {
    public let id: String
    public let focusMinutes: Int
    public let breakMinutes: Int
    public let longBreakMinutes: Int
    public let roundsBeforeLongBreak: Int

    public static let all: [FocusPlan] = [
        .init(id: "classic", focusMinutes: 25, breakMinutes: 5, longBreakMinutes: 15, roundsBeforeLongBreak: 4),
        .init(id: "deep", focusMinutes: 50, breakMinutes: 10, longBreakMinutes: 20, roundsBeforeLongBreak: 2),
        .init(id: "quick", focusMinutes: 15, breakMinutes: 3, longBreakMinutes: 10, roundsBeforeLongBreak: 4),
    ]

    public static func plan(id: String) -> FocusPlan { all.first { $0.id == id } ?? all[0] }

    public var title: String {
        switch id { case "deep": L10n.tr("profundo"); case "quick": L10n.tr("rápido"); default: L10n.tr("clásico") }
    }

    public var detail: String { "\(focusMinutes) · \(breakMinutes)" }
}

public enum FocusPhase: String, Sendable, Equatable, Codable {
    case focus, shortBreak, longBreak

    public var isBreak: Bool { self != .focus }

    public var label: String {
        switch self { case .focus: L10n.tr("enfoque"); case .shortBreak: L10n.tr("descanso"); case .longBreak: L10n.tr("descanso largo") }
    }
}

/// una sesion de enfoque: solo guarda cuando empezo y cuanto estuvo en pausa, el resto se calcula para cualquier instante.
/// asi sobrevive a que la app se cierre o el reloj duerma: basta con volver a preguntar "como va esto a las X".
public struct FocusSession: Sendable, Equatable, Codable {
    public let plan: FocusPlan
    public private(set) var start: Date
    public private(set) var pausedAt: Date?
    public private(set) var pausedTotal: TimeInterval

    public init(plan: FocusPlan, start: Date) {
        self.plan = plan
        self.start = start
        self.pausedAt = nil
        self.pausedTotal = 0
    }

    public struct Moment: Sendable, Equatable {
        public let phase: FocusPhase
        /// ronda de enfoque en curso o recien terminada, desde 1
        public let round: Int
        public let remaining: TimeInterval
        public let duration: TimeInterval
        /// rondas de enfoque ya completas en toda la sesion
        public let completedRounds: Int
        public var progress: Double { duration > 0 ? min(1, max(0, 1 - remaining / duration)) : 0 }
    }

    public struct Transition: Sendable, Equatable {
        public let date: Date
        public let phase: FocusPhase
        public let round: Int
    }

    public var isPaused: Bool { pausedAt != nil }

    private var cycle: [(phase: FocusPhase, seconds: TimeInterval)] {
        let n = max(1, plan.roundsBeforeLongBreak)
        var out: [(FocusPhase, TimeInterval)] = []
        for i in 1...n {
            out.append((.focus, TimeInterval(plan.focusMinutes * 60)))
            out.append(i < n ? (.shortBreak, TimeInterval(plan.breakMinutes * 60)) : (.longBreak, TimeInterval(plan.longBreakMinutes * 60)))
        }
        return out
    }

    public func elapsed(at date: Date) -> TimeInterval {
        max(0, (pausedAt ?? date).timeIntervalSince(start) - pausedTotal)
    }

    public func moment(at date: Date) -> Moment {
        let cycle = cycle
        let cycleLength = cycle.reduce(0) { $0 + $1.seconds }
        let t = elapsed(at: date)
        let cycles = Int(t / cycleLength)
        var local = t - Double(cycles) * cycleLength
        let perCycle = cycle.filter { $0.phase == .focus }.count
        var focusSeen = 0
        for (index, item) in cycle.enumerated() {
            if local < item.seconds || index == cycle.count - 1 {
                let before = cycles * perCycle + focusSeen
                let isFocus = item.phase == .focus
                return Moment(phase: item.phase, round: isFocus ? before + 1 : before,
                              remaining: max(0, item.seconds - local), duration: item.seconds, completedRounds: before)
            }
            local -= item.seconds
            if item.phase == .focus { focusSeen += 1 }
        }
        fatalError("el ciclo nunca esta vacio")
    }

    public func pausing(at date: Date) -> FocusSession {
        guard pausedAt == nil else { return self }
        var copy = self
        copy.pausedAt = date
        return copy
    }

    public func resuming(at date: Date) -> FocusSession {
        guard let pausedAt else { return self }
        var copy = self
        copy.pausedTotal += max(0, date.timeIntervalSince(pausedAt))
        copy.pausedAt = nil
        return copy
    }

    /// termina la fase actual ahora mismo y pasa a la siguiente
    public func skipping(at date: Date) -> FocusSession {
        var copy = self
        copy.start = start.addingTimeInterval(-moment(at: date).remaining)
        return copy
    }

    /// proximos cambios de fase desde `date`, para programar avisos; vacio si esta en pausa
    public func upcomingTransitions(from date: Date, count: Int) -> [Transition] {
        guard !isPaused, count > 0 else { return [] }
        var out: [Transition] = []
        var boundary = date
        var m = moment(at: date)
        for _ in 0..<count {
            boundary = boundary.addingTimeInterval(m.remaining)
            // se mira medio segundo despues del limite para caer ya dentro de la fase siguiente
            let next = moment(at: boundary.addingTimeInterval(0.5))
            out.append(Transition(date: boundary, phase: next.phase, round: next.round))
            // el resto de la fase siguiente cuenta desde el limite exacto, no desde esos 0.5 s
            m = Moment(phase: next.phase, round: next.round, remaining: next.remaining + 0.5, duration: next.duration, completedRounds: next.completedRounds)
        }
        return out
    }
}
