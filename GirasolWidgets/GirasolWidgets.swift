import SwiftUI
import WidgetKit

@main
struct GirasolWidgets: WidgetBundle {
    var body: some Widget {
        UVWidget()
        WaterWidget()
        FoodWidget()
    }
}

// MARK: - datos

struct DayEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot
    var uvi: Double? { snapshot.uvi(at: date) }
    var locale: Locale { snapshot.language.map(Locale.init(identifier:)) ?? .autoupdatingCurrent }
}

/// una entrada cada 30 min con el uv de la curva guardada: la complicacion cambia sola sin que la app corra.
struct DayProvider: TimelineProvider {
    func placeholder(in context: Context) -> DayEntry {
        var s = WidgetSnapshot()
        s.uv = (6...19).map { .init(start: Calendar.current.date(bySettingHour: $0, minute: 0, second: 0, of: Date())!, uvi: max(0, 8 - abs(Double($0) - 13) * 1.4)) }
        s.waterMl = 1200
        s.kcalRemaining = 900
        return DayEntry(date: Date(), snapshot: s)
    }

    func getSnapshot(in context: Context, completion: @escaping (DayEntry) -> Void) {
        let s = WidgetSnapshot.load()
        completion(s.hasForecast(at: Date()) || !context.isPreview ? DayEntry(date: Date(), snapshot: s) : placeholder(in: context))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<DayEntry>) -> Void) {
        let s = WidgetSnapshot.load()
        let now = Date()
        let horizon = now.addingTimeInterval(12 * 3600)
        var dates = (0...24).map { now.addingTimeInterval(Double($0) * 1800) }
        // incluye cada cambio de cobertura: no mantener el ultimo valor hasta el siguiente intervalo.
        dates += s.uv.flatMap { [$0.start, $0.start.addingTimeInterval(3600)] }
            .filter { $0 > now && $0 < horizon }
        let entries = Set(dates).sorted().map { DayEntry(date: $0, snapshot: s) }
        completion(Timeline(entries: entries, policy: .after(now.addingTimeInterval(12 * 3600))))
    }
}

// MARK: - uv

struct UVWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "girasol.uv", provider: DayProvider()) { entry in
            UVWidgetView(entry: entry).containerBackground(.fill.tertiary, for: .widget).environment(\.locale, entry.locale)
        }
        .configurationDisplayName("UV")
        .description("el índice uv de ahora y la hora del pico.")
        .supportedFamilies([.accessoryCircular, .accessoryCorner, .accessoryRectangular, .accessoryInline])
    }
}

private func uvName(_ uvi: Double) -> LocalizedStringKey {
    switch uvi {
    case ..<3: "uv bajo"
    case ..<6: "uv moderado"
    case ..<8: "uv alto"
    case ..<11: "uv muy alto"
    default: "uv extremo"
    }
}

private func hourText(_ date: Date, _ locale: Locale) -> String {
    var s = Date.FormatStyle(date: .omitted, time: .shortened)
    s.locale = locale
    return date.formatted(s)
}

struct UVWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: DayEntry

    var body: some View {
        if let uvi = entry.uvi {
            switch family {
            case .accessoryCorner:
                Text(String(format: "%.0f", uvi))
                    .font(.system(size: 22, weight: .semibold, design: .serif))
                    .widgetLabel {
                        Gauge(value: min(11, uvi), in: 0...11) { Text("UV") }
                            .gaugeStyle(.accessoryLinearCapacity)
                    }
            case .accessoryRectangular:
                VStack(alignment: .leading, spacing: 2) {
                    HStack(alignment: .firstTextBaseline) {
                        Text("UV").font(.system(.caption2, design: .serif)).textCase(.uppercase)
                        Text(String(format: "%.1f", uvi))
                            .font(.system(.title3, design: .serif).weight(.semibold))
                        Spacer()
                        Text(uvName(uvi)).font(.system(.caption2, design: .serif).italic())
                    }
                    Gauge(value: min(11, uvi), in: 0...11) { EmptyView() }.gaugeStyle(.accessoryLinearCapacity)
                    if let p = entry.snapshot.peak {
                        Text("pico \(hourText(p.start, entry.locale))").font(.system(.caption2, design: .serif))
                    } else {
                        Text("abre girasol para cargar el clima").font(.system(.caption2, design: .serif).italic())
                    }
                }
            case .accessoryInline:
                Text("UV \(String(format: "%.0f", uvi)) · \(entry.snapshot.waterMl) ml")
            default:
                Gauge(value: min(11, uvi), in: 0...11) {
                    Text("UV")
                } currentValueLabel: {
                    Text(String(format: "%.0f", uvi)).font(.system(.title3, design: .serif).weight(.semibold))
                }
                .gaugeStyle(.accessoryCircular)
            }
        } else {
            VStack(alignment: .leading, spacing: 2) {
                Text("uv sin datos").font(.system(.caption, design: .serif))
                if family == .accessoryRectangular {
                    Text("abre girasol para cargar el clima").font(.system(.caption2, design: .serif))
                }
            }
        }
    }

}

// MARK: - agua

struct WaterWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "girasol.water", provider: DayProvider()) { entry in
            RingWidgetView(fraction: entry.snapshot.waterFraction, symbol: "drop", primary: "\(entry.snapshot.waterMl)", unit: "ml",
                           detail: "de \(entry.snapshot.waterGoal) ml").containerBackground(.fill.tertiary, for: .widget).environment(\.locale, entry.locale)
        }
        .configurationDisplayName("agua")
        .description("cuánto has bebido hoy respecto a tu meta.")
        .supportedFamilies([.accessoryCircular, .accessoryCorner, .accessoryRectangular, .accessoryInline])
    }
}

// MARK: - comida

struct FoodWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "girasol.food", provider: DayProvider()) { entry in
            RingWidgetView(fraction: entry.snapshot.kcalFraction, symbol: "fork.knife", primary: "\(max(0, entry.snapshot.kcalRemaining))", unit: "kcal",
                           detail: "te quedan hoy").containerBackground(.fill.tertiary, for: .widget).environment(\.locale, entry.locale)
        }
        .configurationDisplayName("comida")
        .description("las calorías que te quedan hoy.")
        .supportedFamilies([.accessoryCircular, .accessoryCorner, .accessoryRectangular, .accessoryInline])
    }
}

struct RingWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let fraction: Double
    let symbol: String
    let primary: String
    let unit: String
    let detail: LocalizedStringKey

    var body: some View {
        switch family {
        case .accessoryCorner:
            Image(systemName: symbol).font(.title3).widgetLabel {
                Gauge(value: fraction) { Text(unit) }.gaugeStyle(.accessoryLinearCapacity)
            }
        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Image(systemName: symbol).font(.caption)
                    Text(primary).font(.system(.title3, design: .serif).weight(.semibold))
                    Text(unit).font(.system(.caption2, design: .serif).italic())
                }
                Gauge(value: fraction) { EmptyView() }.gaugeStyle(.accessoryLinearCapacity)
                Text(detail).font(.system(.caption2, design: .serif))
            }
        case .accessoryInline:
            Text("\(primary) \(unit)")
        default:
            Gauge(value: fraction) {
                Image(systemName: symbol)
            } currentValueLabel: {
                Text(primary).font(.system(size: 13, weight: .semibold, design: .serif)).minimumScaleFactor(0.6)
            }
            .gaugeStyle(.accessoryCircular)
        }
    }
}
