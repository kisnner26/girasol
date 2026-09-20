import SwiftUI
import SunKit

/// paleta de la pagina de las flores. `ink` es el color de trazo y texto y `paper` el fondo; en el tema
/// noche se intercambian, con tonos mas claros para los avisos para que se lean sobre negro.
enum Palette {
    private static var night: Bool { Appearance.shared.choice == .night }

    private static func hex(_ v: UInt32) -> Color {
        Color(red: Double((v >> 16) & 0xFF) / 255, green: Double((v >> 8) & 0xFF) / 255, blue: Double(v & 0xFF) / 255)
    }

    static var ink: Color { night ? hex(0xF5F0E8) : hex(0x1A1208) }
    static var paper: Color { night ? hex(0x14100A) : hex(0xF5F0E8) }
    static var paperDark: Color { night ? hex(0x2A2218) : hex(0xE8E0D0) }
    static var mid: Color { night ? hex(0xC8BFAA) : hex(0x5A4A30) }
    static var faint: Color { night ? hex(0x5A4A30) : hex(0xC8BFAA) }
    static var moss: Color { night ? hex(0x9DB89A) : hex(0x2A3A2A) }
    static var olive: Color { night ? hex(0xD2C47A) : hex(0x4A4A2A) }
    static var rose: Color { night ? hex(0xE58E84) : hex(0x7A1A1A) }

    static func color(for level: AdviceLevel) -> Color {
        switch level {
        case .ok: moss
        case .care: olive
        case .avoid, .stay: rose
        }
    }
}

extension Font {
    static func serif(_ size: CGFloat, italic: Bool = false) -> Font {
        let f = Font.system(size: size, weight: .regular, design: .serif)
        return italic ? f.italic() : f
    }
}

/// rotulo en mayusculas espaciadas, como las etiquetas de la pagina.
struct Caption: View {
    private let text: Text
    var color: Color = Palette.mid
    init(_ key: LocalizedStringKey, color: Color = Palette.mid) { text = Text(key); self.color = color }
    /// para textos que ya vienen resueltos (numeros, horas, traducciones hechas en otro sitio).
    init(verbatim: String, color: Color = Palette.mid) { text = Text(verbatim: verbatim); self.color = color }

    var body: some View {
        text.textCase(.uppercase)
            .font(.system(size: 9, weight: .regular, design: .serif))
            .tracking(1.6)
            .foregroundStyle(color)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
    }
}

struct Hairline: View {
    var opacity = 0.35
    var body: some View {
        Rectangle().fill(Palette.ink.opacity(opacity)).frame(height: 0.5)
    }
}

extension Double {
    /// "1.6", "10", sin ceros de sobra.
    var uvText: String { self >= 10 ? String(Int(self.rounded())) : String(format: "%.1f", self) }
}

func minutesText(_ m: Double) -> String {
    let n = Int(m.rounded())
    if n >= 120 { return "\(n / 60) h \(n % 60 == 0 ? "" : "\(n % 60) min")".trimmingCharacters(in: .whitespaces) }
    return "\(n) min"
}
