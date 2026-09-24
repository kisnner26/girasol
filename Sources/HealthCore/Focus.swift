import Foundation
import Localization

/// un patron de trabajo/descanso, al estilo pomodoro.
public struct FocusPattern: Sendable, Equatable {
    public let id: String
    public let title: String
    public let detail: String
    public let workMinutes: Double
    public let breakMinutes: Double

    public var cycleMinutes: Double { workMinutes + breakMinutes }

    public static let all: [FocusPattern] = [
        .init(id: "classic", title: L10n.tr("clásico"), detail: "25 · 5", workMinutes: 25, breakMinutes: 5),
        .init(id: "short", title: L10n.tr("corto"), detail: "15 · 3", workMinutes: 15, breakMinutes: 3),
        .init(id: "long", title: L10n.tr("largo"), detail: "50 · 10", workMinutes: 50, breakMinutes: 10),
    ]

    public static func pattern(id: String) -> FocusPattern {
        all.first { $0.id == id } ?? all[0]
    }
}

public enum FocusPhase: Sendable, Equatable {
    case work, rest
    public var label: String { switch self { case .work: L10n.tr("concéntrate"); case .rest: L10n.tr("descansa") } }
}

public enum FocusHapticKind: Sendable, Equatable { case workStart, restStart, end }

public struct FocusHapticEvent: Sendable, Equatable {
    public let time: Double
    public let kind: FocusHapticKind
}

/// una sesion de concentracion: cuantos ciclos trabajo+descanso caben en los minutos pedidos.
public struct FocusSession: Sendable {
    public let pattern: FocusPattern
    public let cycles: Int

    public struct Moment: Sendable, Equatable {
        public let phase: FocusPhase
        public let phaseProgress: Double   // 0...1 dentro de la fase
        public let cycleIndex: Int
        public let remaining: Double
    }

    /// se redondea a ciclos completos (minimo uno) para no cortar un bloque de trabajo a la mitad.
    public init(pattern: FocusPattern, minutes: Int) {
        self.pattern = pattern
        cycles = max(1, Int((Double(minutes) / pattern.cycleMinutes).rounded()))
    }

    public var duration: Double { Double(cycles) * pattern.cycleMinutes * 60 }

    public func moment(at t: Double) -> Moment? {
        guard t >= 0, t < duration else { return nil }
        let cycleLength = pattern.cycleMinutes * 60
        let cycleIndex = Int(t / cycleLength)
        var local = t - Double(cycleIndex) * cycleLength
        let remaining = duration - t
        let workSec = pattern.workMinutes * 60
        if local < workSec {
            return Moment(phase: .work, phaseProgress: workSec > 0 ? local / workSec : 0, cycleIndex: cycleIndex, remaining: remaining)
        }
        local -= workSec
        let restSec = pattern.breakMinutes * 60
        return Moment(phase: .rest, phaseProgress: restSec > 0 ? local / restSec : 0, cycleIndex: cycleIndex, remaining: remaining)
    }

    /// un golpe al empezar cada bloque de trabajo y otro al empezar el descanso.
    public func haptics() -> [FocusHapticEvent] {
        var events: [FocusHapticEvent] = []
        let workSec = pattern.workMinutes * 60, restSec = pattern.breakMinutes * 60
        for c in 0..<cycles {
            let base = Double(c) * (workSec + restSec)
            events.append(.init(time: base, kind: .workStart))
            if restSec > 0 { events.append(.init(time: base + workSec, kind: .restStart)) }
        }
        events.append(.init(time: duration, kind: .end))
        return events
    }
}
