import SwiftUI

struct PrivacyView: View {
    private let sections: [LocalizedStringKey] = [
        "privacy.updated", "privacy.local", "privacy.health", "privacy.weather",
        "privacy.widgets", "privacy.control", "privacy.support"
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                Caption("política de privacidad")
                ForEach(sections.indices, id: \.self) { index in
                    Text(sections[index]).fixedSize(horizontal: false, vertical: true)
                }
                Link("política de open-meteo", destination: URL(string: "https://open-meteo.com/en/terms")!)
                Link("contacto de privacidad", destination: URL(string: "mailto:kisnnerobando7@gmail.com")!)
            }
            .font(.serif(12)).foregroundStyle(Palette.ink).padding(.horizontal, 8)
        }
        .paperBackground()
    }
}
