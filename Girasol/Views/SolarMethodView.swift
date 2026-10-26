import SwiftUI

struct SolarMethodView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                Caption("cómo se estima")
                Text("estimación ambiental: uv del pronóstico × 1,5 × minutos con luz diurna = j/m². dividimos entre 100 para mostrar sed.")
                Text("el reloj no mide uv en la piel. sombra, ropa, orientación, nubes, medicamentos y datos incompletos pueden cambiar tu exposición real. el spf no aumenta un tiempo seguro ni reduce retroactivamente esta estimación.")
                HealthNotice()
                Link("oms: índice uv y protección", destination: URL(string: "https://www.who.int/news-room/fact-sheets/detail/ultraviolet-radiation")!)
                Link("cie: dosis eritemática estándar", destination: URL(string: "https://cie.co.at/publications/standard-erythema-dose-review")!)
                Link("fda: protector solar", destination: URL(string: "https://www.fda.gov/drugs/understanding-over-counter-medicines/sunscreen-how-help-protect-your-skin-sun")!)
                Link("knmi: cálculo del índice uv", destination: URL(string: "https://temis.pmc.knmi.cloud/uvradiation/product/uvi-uvd.html")!)
            }
            .font(.serif(12)).foregroundStyle(Palette.ink).padding(.horizontal, 8)
        }
        .paperBackground()
    }
}
