import SwiftUI
import HealthCore

enum IconKind { case sun, drop, leaf, heart, breath, target, sliders }

/// iconos de trazo fino en una cuadricula de 24: mismo lenguaje que los dibujos botanicos.
struct LineIcon: View {
    let kind: IconKind

    var body: some View {
        Canvas { ctx, size in
            let s = min(size.width, size.height)
            ctx.translateBy(x: (size.width - s) / 2, y: (size.height - s) / 2)
            ctx.scaleBy(x: s / 24, y: s / 24)
            let style = StrokeStyle(lineWidth: 1.3, lineCap: .round, lineJoin: .round)
            let ink = GraphicsContext.Shading.color(Palette.ink)
            func circle(_ x: CGFloat, _ y: CGFloat, _ r: CGFloat) -> Path { Path(ellipseIn: CGRect(x: x - r, y: y - r, width: 2 * r, height: 2 * r)) }

            switch kind {
            case .sun:
                ctx.stroke(circle(12, 12, 4), with: ink, style: style)
                for k in 0..<8 {
                    let a = CGFloat(k) * .pi / 4
                    var p = Path()
                    p.move(to: CGPoint(x: 12 + 7 * cos(a), y: 12 + 7 * sin(a)))
                    p.addLine(to: CGPoint(x: 12 + 10 * cos(a), y: 12 + 10 * sin(a)))
                    ctx.stroke(p, with: ink, style: style)
                }
            case .drop:
                var p = Path()
                p.move(to: CGPoint(x: 12, y: 3))
                p.addCurve(to: CGPoint(x: 5, y: 15.5), control1: CGPoint(x: 12, y: 3), control2: CGPoint(x: 5, y: 11))
                p.addCurve(to: CGPoint(x: 12, y: 22), control1: CGPoint(x: 5, y: 19.4), control2: CGPoint(x: 8.1, y: 22))
                p.addCurve(to: CGPoint(x: 19, y: 15.5), control1: CGPoint(x: 15.9, y: 22), control2: CGPoint(x: 19, y: 19.4))
                p.addCurve(to: CGPoint(x: 12, y: 3), control1: CGPoint(x: 19, y: 11), control2: CGPoint(x: 12, y: 3))
                ctx.stroke(p, with: ink, style: style)
            case .leaf:
                var p = Path()
                p.move(to: CGPoint(x: 5, y: 19))
                p.addCurve(to: CGPoint(x: 20, y: 4), control1: CGPoint(x: 5, y: 9), control2: CGPoint(x: 11, y: 4))
                p.addCurve(to: CGPoint(x: 5, y: 19), control1: CGPoint(x: 20, y: 13), control2: CGPoint(x: 15, y: 19))
                var vein = Path()
                vein.move(to: CGPoint(x: 5, y: 19)); vein.addLine(to: CGPoint(x: 14, y: 10))
                ctx.stroke(p, with: ink, style: style)
                ctx.stroke(vein, with: ink, style: style)
            case .heart:
                var p = Path()
                p.move(to: CGPoint(x: 12, y: 20))
                p.addCurve(to: CGPoint(x: 6.5, y: 6.5), control1: CGPoint(x: 4, y: 14), control2: CGPoint(x: 3, y: 9))
                p.addCurve(to: CGPoint(x: 12, y: 8), control1: CGPoint(x: 9, y: 4.8), control2: CGPoint(x: 11.3, y: 6))
                p.addCurve(to: CGPoint(x: 17.5, y: 6.5), control1: CGPoint(x: 12.7, y: 6), control2: CGPoint(x: 15, y: 4.8))
                p.addCurve(to: CGPoint(x: 12, y: 20), control1: CGPoint(x: 21, y: 9), control2: CGPoint(x: 20, y: 14))
                ctx.stroke(p, with: ink, style: style)
            case .breath:
                ctx.stroke(circle(12, 12, 9), with: ink, style: style)
                ctx.stroke(circle(12, 12, 4.5), with: ink, style: style)
                ctx.fill(circle(12, 12, 1), with: ink)
            case .target:
                ctx.stroke(circle(12, 12, 9), with: ink, style: style)
                ctx.stroke(circle(12, 12, 5), with: ink, style: style)
                ctx.fill(circle(12, 12, 1.4), with: ink)
                for (a, b) in [((12.0, 1.0), (12.0, 4.0)), ((12.0, 20.0), (12.0, 23.0)), ((1.0, 12.0), (4.0, 12.0)), ((20.0, 12.0), (23.0, 12.0))] {
                    var p = Path(); p.move(to: CGPoint(x: a.0, y: a.1)); p.addLine(to: CGPoint(x: b.0, y: b.1))
                    ctx.stroke(p, with: ink, style: style)
                }
            case .sliders:
                for (y, x) in [(6.0, 9.0), (12.0, 15.0), (18.0, 8.0)] {
                    var p = Path(); p.move(to: CGPoint(x: 4, y: y)); p.addLine(to: CGPoint(x: 20, y: y))
                    ctx.stroke(p, with: ink, style: style)
                    ctx.fill(circle(x, y, 2.3), with: GraphicsContext.Shading.color(Palette.paper))
                    ctx.stroke(circle(x, y, 2.3), with: ink, style: style)
                }
            }
        }
        .accessibilityHidden(true)
    }
}

/// anillo fino de progreso.
struct Ring: View {
    let fraction: Double
    let tint: Color
    var width: CGFloat = 4

    var body: some View {
        ZStack {
            Circle().stroke(Palette.faint, lineWidth: 0.7)
            Circle().trim(from: 0, to: min(1, max(0, fraction)))
                .stroke(tint, style: StrokeStyle(lineWidth: width, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
    }
}

/// fila de una lista: icono, rotulo en mayusculas, detalle en cursiva y una linea fina debajo.
struct HomeRow: View {
    let icon: IconKind
    let title: LocalizedStringKey
    let detail: LocalizedStringKey

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                LineIcon(kind: icon).frame(width: 22, height: 22)
                VStack(alignment: .leading, spacing: 2) {
                    Caption(title)
                    Text(detail).font(.serif(13, italic: true)).foregroundStyle(Palette.ink)
                        .lineLimit(2).multilineTextAlignment(.leading)
                }
                Spacer(minLength: 2)
                Text("›").font(.serif(15)).foregroundStyle(Palette.mid)
            }
            .padding(.vertical, 8)
            Hairline(opacity: 0.2)
        }
        .contentShape(Rectangle())
    }
}

extension View {
    /// el doble toque del Apple Watch (watchOS 11+) activa este boton sin tocar la pantalla.
    @ViewBuilder func doubleTapPrimary() -> some View {
        if #available(watchOS 11.0, *) { self.handGestureShortcut(.primaryAction) } else { self }
    }

    func paperBackground() -> some View { containerBackground(Palette.paper, for: .navigation) }
}

/// boton de texto discreto (deshacer, cancelar).
struct QuietButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.serif(11, italic: true))
            .foregroundStyle(configuration.isPressed ? Palette.ink : Palette.mid)
            .underline()
    }
}

func hourMinute(_ date: Date) -> String {
    var style = Date.FormatStyle(date: .omitted, time: .shortened)
    style.locale = Lang.locale
    return date.formatted(style)
}

func numberText(_ v: Double) -> String { Int(v.rounded()).formatted() }


/// campo de nombre con el estilo de la pagina: abre la entrada de texto del sistema (teclado, dictado o garabato)
/// sin dibujar la pildora oscura del TextField normal.
struct NameField: View {
    @Binding var name: String
    var title: LocalizedStringKey = "tu nombre"

    var body: some View {
        TextFieldLink(prompt: Text("¿cómo te llamas?")) {
            VStack(alignment: .leading, spacing: 3) {
                Caption(title)
                HStack {
                    (name.isEmpty ? Text("toca para escribir") : Text(verbatim: name))
                        .font(.serif(16, italic: true))
                        .foregroundStyle(name.isEmpty ? Palette.mid : Palette.ink)
                    Spacer(minLength: 4)
                    Text("✎").font(.serif(14)).foregroundStyle(Palette.mid)
                }
                Hairline(opacity: 0.35).padding(.top, 3)
            }
            .contentShape(Rectangle())
        } onSubmit: { name = $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        .buttonStyle(.plain)
    }
}
