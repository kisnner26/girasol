import SwiftUI

struct HealthNotice: View {
    var body: some View {
        Text("información orientativa: uv, exposición y sueño no sustituyen el consejo médico. consulta a un profesional antes de tomar decisiones sobre tu salud.")
            .font(.serif(11, italic: true)).foregroundStyle(Palette.mid)
            .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
    }
}
