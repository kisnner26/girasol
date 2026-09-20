import AVFoundation
import Foundation
import WatchKit

/// haptico del reloj, respetando el ajuste del usuario.
enum Haptics {
    nonisolated(unsafe) static var enabled = true

    static func play(_ type: WKHapticType) {
        guard enabled else { return }
        WKInterfaceDevice.current().play(type)
    }
}

/// efectos de sonido sintetizados al vuelo (sin archivos). varios reproductores en rotacion para poder
/// superponer, por ejemplo, el silbido del swing y el golpe de la pelota.
final class Sfx: @unchecked Sendable {
    static let shared = Sfx()
    enum Sound: CaseIterable { case pew, bang, whoosh, thunk, bounce, swish, pok, ding, buzz, pop, hit, empty, reload }

    var enabled = true
    private let engine = AVAudioEngine()
    private var players: [AVAudioPlayerNode] = []
    private var next = 0
    private let format = AVAudioFormat(standardFormatWithSampleRate: 22050, channels: 1)!
    private var buffers: [Sound: AVAudioPCMBuffer] = [:]
    private var ready = false

    private init() {
        for _ in 0..<4 {
            let p = AVAudioPlayerNode()
            engine.attach(p)
            engine.connect(p, to: engine.mainMixerNode, format: format)
            players.append(p)
        }
        for s in Sound.allCases { buffers[s] = Self.render(s, format: format) }
    }

    func play(_ sound: Sound) {
        guard enabled, let buffer = buffers[sound] else { return }
        if !ready {
            try? AVAudioSession.sharedInstance().setCategory(.ambient)
            try? AVAudioSession.sharedInstance().setActive(true)
            ready = (try? engine.start()) != nil
        }
        guard ready else { return }
        let p = players[next]
        next = (next + 1) % players.count
        p.scheduleBuffer(buffer, at: nil, options: .interrupts)
        if !p.isPlaying { p.play() }
    }

    // MARK: sintesis

    /// genera `duration` segundos; `gen` recibe el tiempo y un estado de fase que puede acumular.
    private static func synth(_ duration: Double, _ format: AVAudioFormat, _ gen: (Double, inout Double, inout Float) -> Float) -> AVAudioPCMBuffer {
        let rate = format.sampleRate
        let frames = AVAudioFrameCount(duration * rate)
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames)!
        buffer.frameLength = frames
        let out = buffer.floatChannelData![0]
        var phase = 0.0
        var filter: Float = 0
        for i in 0..<Int(frames) {
            out[i] = max(-1, min(1, gen(Double(i) / rate, &phase, &filter))) * 0.6
        }
        return buffer
    }

    private static func noise() -> Float { Float.random(in: -1...1) }

    private static func render(_ sound: Sound, format: AVAudioFormat) -> AVAudioPCMBuffer {
        let rate = format.sampleRate
        switch sound {
        case .pew:      // laser "biubiu": barrido agudo que cae, con un segundo armonico
            return synth(0.24, format) { t, ph, _ in
                let f = 2600 * exp(-t * 11) + 260
                ph += 2 * .pi * f / rate
                return (sinf(Float(ph)) * 0.8 + sinf(Float(ph * 2)) * 0.25) * expf(Float(-t * 9)) * min(1, Float(t * 900))
            }
        case .bang:     // disparo: chasquido de ruido + golpe grave
            return synth(0.32, format) { t, ph, lp in
                ph += 2 * .pi * (110 - 55 * t) / rate
                lp += (noise() - lp) * 0.45
                return lp * expf(Float(-t * 26)) * 1.4 + sinf(Float(ph)) * expf(Float(-t * 16)) * 0.9 + noise() * expf(Float(-t * 220)) * 0.8
            }
        case .whoosh:   // silbido del brazo: ruido filtrado que sube y baja
            return synth(0.32, format) { t, _, lp in
                let a = Float(0.08 + 0.5 * sin(.pi * t / 0.32))
                lp += (noise() - lp) * a
                return lp * Float(sin(.pi * t / 0.32)) * 1.6
            }
        case .thunk:    // dardo clavado
            return synth(0.16, format) { t, ph, _ in
                ph += 2 * .pi * (170 - 500 * t) / rate
                return sinf(Float(ph)) * expf(Float(-t * 34)) + noise() * expf(Float(-t * 400)) * 0.7
            }
        case .bounce:   // pelota contra el aro / suelo
            return synth(0.2, format) { t, ph, _ in
                ph += 2 * .pi * (230 - 400 * t) / rate
                return sinf(Float(ph)) * expf(Float(-t * 13)) + sinf(Float(ph * 2.7)) * expf(Float(-t * 25)) * 0.3
            }
        case .swish:    // red: ruido suave con ataque rapido
            return synth(0.38, format) { t, _, lp in
                lp += (noise() - lp) * 0.35
                return lp * expf(Float(-t * 8)) * min(1, Float(t * 120)) * 1.5
            }
        case .pok:      // pelota de tenis contra la raqueta
            return synth(0.11, format) { t, ph, _ in
                ph += 2 * .pi * (1250 - 5200 * t) / rate
                return sinf(Float(ph)) * expf(Float(-t * 38)) + noise() * expf(Float(-t * 260)) * 0.5
            }
        case .ding:     // punto
            return synth(0.34, format) { t, _, _ in
                (sinf(Float(2 * .pi * 1046 * t)) + sinf(Float(2 * .pi * 1568 * t)) * 0.6) * expf(Float(-t * 9)) * 0.7
            }
        case .buzz:     // fallo
            return synth(0.26, format) { t, _, _ in
                let sq: Float = sinf(Float(2 * .pi * 120 * t)) > 0 ? 1 : -1
                return sq * expf(Float(-t * 7)) * 0.55
            }
        case .pop:
            return synth(0.07, format) { t, ph, _ in
                ph += 2 * .pi * (700 - 5000 * t) / rate
                return sinf(Float(ph)) * expf(Float(-t * 55))
            }
        case .hit:
            return synth(0.12, format) { t, _, _ in
                (sinf(Float(2 * .pi * 880 * t)) + sinf(Float(2 * .pi * 1320 * t))) * 0.5 * expf(Float(-t * 22))
            }
        case .empty:    // gatillo sin balas
            return synth(0.06, format) { t, _, _ in sinf(Float(2 * .pi * 260 * t)) * expf(Float(-t * 70)) + noise() * expf(Float(-t * 300)) * 0.4 }
        case .reload:
            return synth(0.12, format) { t, ph, _ in
                ph += 2 * .pi * (400 + 2200 * t) / rate
                return sinf(Float(ph)) * expf(Float(-t * 18))
            }
        }
    }
}
