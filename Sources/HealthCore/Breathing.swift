import Foundation
import Localization

public struct BreathingPattern: Sendable, Equatable {
    public let id: String
    public let title: String
    public let detail: String
    public let inhale: Double
    public let holdIn: Double
    public let exhale: Double
    public let holdOut: Double

    public var cycle: Double { inhale + holdIn + exhale + holdOut }

    public static let all: [BreathingPattern] = [
        .init(id: "calm", title: L10n.tr("suave"), detail: L10n.tr("inhala 4 · exhala 6"), inhale: 4, holdIn: 0, exhale: 6, holdOut: 0),
        .init(id: "box", title: L10n.tr("caja"), detail: "4 · 4 · 4 · 4", inhale: 4, holdIn: 4, exhale: 4, holdOut: 4),
        .init(id: "sleep", title: L10n.tr("para dormir"), detail: "4 · 7 · 8", inhale: 4, holdIn: 7, exhale: 8, holdOut: 0),
    ]

    public static func pattern(id: String) -> BreathingPattern {
        all.first { $0.id == id } ?? all[0]
    }
}

public enum BreathPhase: Sendable, Equatable {
    case inhale, holdIn, exhale, holdOut

    public var label: String {
        switch self { case .inhale: L10n.tr("inhala"); case .holdIn: L10n.tr("sostén"); case .exhale: L10n.tr("exhala"); case .holdOut: L10n.tr("pausa") }
    }
}

public enum HapticKind: Sendable, Equatable { case inhaleStart, exhaleStart, tick, hold, end }

public struct HapticEvent: Sendable, Equatable {
    public let time: Double
    public let kind: HapticKind
}

/// una sesion de respiracion: cuantos ciclos caben en los minutos pedidos, en que fase va y cuando vibrar.
public struct BreathingSession: Sendable {
    public let pattern: BreathingPattern
    public let cycles: Int

    public struct Moment: Sendable, Equatable {
        public let phase: BreathPhase
        public let phaseProgress: Double   // 0...1 dentro de la fase
        public let cycleIndex: Int
        public let remaining: Double
        public let scale: Double           // 0 = pulmones vacios, 1 = llenos; para animar la flor
    }

    /// se redondea a ciclos completos (minimo uno) para no cortar una respiracion a la mitad.
    public init(pattern: BreathingPattern, minutes: Int) {
        self.pattern = pattern
        cycles = max(1, Int((Double(minutes) * 60 / pattern.cycle).rounded()))
    }

    public var duration: Double { Double(cycles) * pattern.cycle }

    private static func ease(_ t: Double) -> Double { t * t * (3 - 2 * t) }

    public func moment(at t: Double) -> Moment? {
        guard t >= 0, t < duration else { return nil }
        let p = pattern
        let cycleIndex = Int(t / p.cycle)
        var local = t - Double(cycleIndex) * p.cycle
        let remaining = duration - t

        func make(_ phase: BreathPhase, _ length: Double, _ scale: (Double) -> Double) -> Moment {
            let prog = length > 0 ? local / length : 0
            return Moment(phase: phase, phaseProgress: prog, cycleIndex: cycleIndex, remaining: remaining, scale: scale(prog))
        }
        if local < p.inhale { return make(.inhale, p.inhale) { Self.ease($0) } }
        local -= p.inhale
        if local < p.holdIn { return make(.holdIn, p.holdIn) { _ in 1 } }
        local -= p.holdIn
        if local < p.exhale { return make(.exhale, p.exhale) { 1 - Self.ease($0) } }
        local -= p.exhale
        return make(.holdOut, p.holdOut) { _ in 0 }
    }

    /// vibraciones: un golpe al empezar cada fase y un toque suave por segundo mientras inhalas o exhalas.
    public func haptics() -> [HapticEvent] {
        var events: [HapticEvent] = []
        let p = pattern
        for c in 0..<cycles {
            var t = Double(c) * p.cycle
            events.append(.init(time: t, kind: .inhaleStart))
            var k = 1.0
            while k < p.inhale { events.append(.init(time: t + k, kind: .tick)); k += 1 }
            t += p.inhale
            if p.holdIn > 0 { events.append(.init(time: t, kind: .hold)); t += p.holdIn }
            events.append(.init(time: t, kind: .exhaleStart))
            k = 1
            while k < p.exhale { events.append(.init(time: t + k, kind: .tick)); k += 1 }
            t += p.exhale
            if p.holdOut > 0 { events.append(.init(time: t, kind: .hold)) }
        }
        events.append(.init(time: duration, kind: .end))
        return events
    }
}
