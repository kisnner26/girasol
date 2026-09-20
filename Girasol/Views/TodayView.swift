import SwiftUI
import SunKit

struct TodayView: View {
    @Environment(AppModel.self) private var model

    private let first = 6, last = 19

    var body: some View {
        ScrollView {
            if let w = model.weather {
                var cal = Calendar(identifier: .gregorian)
                let _ = cal.timeZone = w.timeZone
                let currentHour = cal.component(.hour, from: model.now)
                let byHour = Dictionary(uniqueKeysWithValues: w.hours.map { (cal.component(.hour, from: $0.start), $0.uvIndex) })

                VStack(spacing: 6) {
                    Caption("uv de hoy")
                    HStack(alignment: .bottom, spacing: 3) {
                        ForEach(first...last, id: \.self) { h in
                            let uv = byHour[h] ?? 0
                            VStack(spacing: 3) {
                                Rectangle()
                                    .fill(h < currentHour ? Palette.mid.opacity(0.55) : Palette.ink)
                                    .frame(width: 5, height: max(1, CGFloat(min(uv, 12)) / 12 * 64))
                                Text(h % 3 == 0 ? "\(h)" : "")
                                    .font(.system(size: 8, design: .serif)).foregroundStyle(Palette.mid)
                                    .frame(height: 9).fixedSize()
                                Circle().fill(h == currentHour ? Palette.rose : .clear).frame(width: 3, height: 3)
                            }
                            .frame(width: 8)
                        }
                    }
                    .frame(height: 96, alignment: .bottom)
                    Hairline()

                    if let o = model.outlook {
                        Text(summary(o)).font(.serif(13, italic: true)).foregroundStyle(Palette.ink)
                            .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
                        Caption("pico \(o.peakUVI.uvText) a las \(o.peakHour) h")
                    }
                }
                .padding(.horizontal, 4)
            } else {
                EmptyState()
            }
        }
        .containerBackground(Palette.paper, for: .tabView)
    }

    private func summary(_ o: DayOutlook) -> String {
        if let h = o.high { return "evita de \(h.startHour) a \(h.endHour) h" }
        if let m = o.moderate { return "uv moderado de \(m.startHour) a \(m.endHour) h" }
        return "uv bajo todo el día"
    }
}
