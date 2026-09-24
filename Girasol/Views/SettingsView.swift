import SwiftUI
import HealthCore
import SunKit

/// fila de ajuste con el estilo de la pagina: rotulo, valor en cursiva y una linea fina debajo.
struct ChoiceRow<Value: Hashable>: View {
    let title: LocalizedStringKey
    let options: [(value: Value, label: String)]
    @Binding var selection: Value

    var body: some View {
        NavigationLink {
            OptionList(title: title, options: options, selection: $selection)
        } label: {
            SettingLabel(title: title, value: options.first { $0.value == selection }?.label ?? "")
        }
        .buttonStyle(.plain)
    }
}

struct SettingLabel: View {
    let title: LocalizedStringKey
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Caption(title)
            HStack {
                Text(value).font(.serif(14, italic: true)).foregroundStyle(Palette.ink).multilineTextAlignment(.leading)
                Spacer(minLength: 4)
                Text("›").font(.serif(14)).foregroundStyle(Palette.mid)
            }
            Hairline(opacity: 0.25).padding(.top, 3)
        }
        .contentShape(Rectangle())
    }
}

struct OptionList<Value: Hashable>: View {
    let title: LocalizedStringKey
    let options: [(value: Value, label: String)]
    @Binding var selection: Value
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Caption(title).padding(.bottom, 6)
                ForEach(options.indices, id: \.self) { i in
                    let o = options[i]
                    Button {
                        selection = o.value
                        dismiss()
                    } label: {
                        HStack(alignment: .firstTextBaseline) {
                            Text(o.label).font(.serif(13, italic: o.value == selection))
                                .foregroundStyle(Palette.ink).multilineTextAlignment(.leading)
                            Spacer(minLength: 4)
                            if o.value == selection { Text("✦").font(.serif(11)).foregroundStyle(Palette.ink) }
                        }
                        .padding(.vertical, 7)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    Hairline(opacity: 0.2)
                }
            }
            .padding(.horizontal, 6)
        }
        .paperBackground()
    }
}

/// numero editable con la corona.
struct NumberRow: View {
    let title: LocalizedStringKey
    @Binding var value: Int
    let range: ClosedRange<Int>
    let step: Int
    var unit = ""

    var body: some View {
        NavigationLink {
            NumberEditor(title: title, value: $value, range: range, step: step, unit: unit)
        } label: {
            SettingLabel(title: title, value: "\(value.formatted()) \(unit)".trimmingCharacters(in: .whitespaces))
        }
        .buttonStyle(.plain)
    }
}

struct NumberEditor: View {
    let title: LocalizedStringKey
    @Binding var value: Int
    let range: ClosedRange<Int>
    let step: Int
    let unit: String
    @State private var v = 0.0
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 8) {
            Caption(title)
            Text(Int(v).formatted()).font(.serif(38)).foregroundStyle(Palette.ink).minimumScaleFactor(0.6)
            Text(unit).font(.serif(13, italic: true)).foregroundStyle(Palette.mid)
            Caption("gira la corona")
            Button("listo") { value = Int(v); dismiss() }.buttonStyle(InkButtonStyle()).doubleTapPrimary()
        }
        .focusable()
        .digitalCrownRotation($v, from: Double(range.lowerBound), through: Double(range.upperBound), by: Double(step),
                              sensitivity: .medium, isContinuous: false, isHapticFeedbackEnabled: true)
        .onAppear { v = Double(min(range.upperBound, max(range.lowerBound, value))) }
        .onChange(of: v) { _, new in value = Int(new) }
        .paperBackground()
    }
}

private struct SettingsPage<Content: View>: View {
    let title: LocalizedStringKey
    @ViewBuilder let content: Content
    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                Caption(title)
                content
            }
            .padding(.horizontal, 8)
        }
        .paperBackground()
    }
}

enum SettingsSection: Hashable { case profile, goals, reminders, sun, look, motion, about }

struct SettingsView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 4) {
                Caption("ajustes")
                link(.profile, .heart, "perfil", "tu nombre y tus datos")
                link(.goals, .drop, "metas", "agua, comida, pasos")
                link(.reminders, .breath, "recordatorios", "agua durante el día")
                link(.sun, .sun, "sol", "piel, protector, alertas uv")
                link(.look, .sliders, "apariencia", "tema, unidades, háptico")
                link(.motion, .target, "movimiento", "sensibilidad de los juegos")
                link(.about, .leaf, "acerca de", "datos y avisos")
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 6)
        }
        .paperBackground()
    }

    private func link(_ s: SettingsSection, _ icon: IconKind, _ title: LocalizedStringKey, _ detail: LocalizedStringKey) -> some View {
        NavigationLink(value: s) { HomeRow(icon: icon, title: title, detail: detail) }
    }
}

struct SettingsDetail: View {
    let section: SettingsSection
    @Environment(HealthModel.self) private var health
    @Environment(AppModel.self) private var sun
    private let appearance = Appearance.shared

    var body: some View {
        @Bindable var store = health.profiles
        @Bindable var settings = sun.settings
        @Bindable var appearance = appearance
        @Bindable var language = LanguageSettings.shared
        switch section {
        case .profile:
            SettingsPage(title: "perfil") {
                NameField(name: $store.profile.name)
                ChoiceRow(title: "sexo", options: Sex.allCases.map { ($0, $0.title) }, selection: $store.profile.sex)
                NumberRow(title: "año de nacimiento", value: Binding(get: { store.profile.birthYear ?? 1995 }, set: { store.profile.birthYear = $0 }),
                          range: 1930...2015, step: 1)
                NumberRow(title: "estatura", value: Binding(get: { Int(store.profile.heightCm ?? 170) }, set: { store.profile.heightCm = Double($0) }),
                          range: 100...230, step: 1, unit: "cm")
                NumberRow(title: "peso", value: Binding(get: { Int(store.profile.weightKg ?? 70) }, set: { store.profile.weightKg = Double($0) }),
                          range: 25...250, step: 1, unit: "kg")
                ChoiceRow(title: "actividad", options: ActivityLevel.allCases.map { ($0, $0.title) }, selection: $store.profile.activity)
                ChoiceRow(title: "objetivo", options: Objective.allCases.map { ($0, $0.title) }, selection: $store.profile.objective)
                Button("leer de Salud") { Task { await health.requestAccess(); await health.importBody() } }.buttonStyle(InkButtonStyle())
            }
        case .goals:
            SettingsPage(title: "metas") {
                NumberRow(title: "meta de agua", value: $store.profile.waterGoalMl, range: 500...6000, step: 50, unit: "ml")
                Button("sugerida: \(health.suggestedWaterGoal()) ml") { store.profile.waterGoalMl = health.suggestedWaterGoal() }
                    .buttonStyle(QuietButtonStyle())
                NumberRow(title: "tamaño del vaso", value: $store.profile.glassMl, range: 100...1000, step: 50, unit: "ml")
                NumberRow(title: "meta de comida", value: $store.profile.kcalGoal, range: 800...6000, step: 50, unit: "kcal")
                if let k = health.suggestedKcalGoal() {
                    Button("sugerida: \(k) kcal") { store.profile.kcalGoal = k }.buttonStyle(QuietButtonStyle())
                } else {
                    Text("completa peso, estatura y año en tu perfil para una sugerencia").font(.serif(10, italic: true)).foregroundStyle(Palette.mid)
                }
                Toggle(isOn: $store.profile.addActivityToKcal) { Caption("sumar mi actividad") }.tint(Palette.moss)
                NumberRow(title: "meta de pasos", value: $store.profile.stepGoal, range: 1000...40000, step: 500, unit: loc("pasos"))
                NumberRow(title: "meta de calma", value: $store.profile.mindfulGoalMinutes, range: 0...60, step: 1, unit: loc("min"))
                Text("cuenta para la racha; 0 la desactiva.").font(.serif(10, italic: true)).foregroundStyle(Palette.mid)
            }
        case .reminders:
            SettingsPage(title: "recordatorios") {
                Toggle(isOn: $store.profile.waterReminders) { Caption("beber agua") }.tint(Palette.moss)
                NumberRow(title: "cada", value: $store.profile.reminderEveryHours, range: 1...6, step: 1, unit: "h")
                NumberRow(title: "despiertas a las", value: $store.profile.wakeHour, range: 4...12, step: 1, unit: "h")
                NumberRow(title: "duermes a las", value: $store.profile.sleepHour, range: 18...23, step: 1, unit: "h")
                Text("solo avisa si aún no llegas a tu meta.").font(.serif(10, italic: true)).foregroundStyle(Palette.mid)
                Toggle(isOn: $store.profile.postureReminders) { Caption("estirar al estar sentado") }.tint(Palette.moss)
                NumberRow(title: "avisar tras", value: $store.profile.sedentaryThresholdHours, range: 1...6, step: 1, unit: "h")
            }
            .onChange(of: store.profile) { Task { await health.scheduleWaterReminders() } }
        case .sun:
            SettingsPage(title: "sol") {
                ChoiceRow(title: "piel", options: SkinType.allCases.map { ($0, "\($0.title) · \($0.detail)") }, selection: $settings.skin)
                ChoiceRow(title: "protector", options: Sunscreen.options.map { ($0, $0.title) }, selection: $settings.sunscreen)
                Toggle(isOn: $settings.alertsEnabled) { Caption("alertas de uv") }.tint(Palette.moss)
                Toggle(isOn: $settings.reapplyReminders) { Caption("reaplicar protector") }.tint(Palette.moss)
                Button("actualizar el clima") { Task { await sun.refresh() } }.buttonStyle(InkButtonStyle())
            }
            .onChange(of: settings.skin) { Task { await sun.settingsChanged() } }
            .onChange(of: settings.sunscreen) { Task { await sun.settingsChanged() } }
            .onChange(of: settings.alertsEnabled) { Task { await sun.settingsChanged() } }
            .onChange(of: settings.reapplyReminders) { Task { await sun.settingsChanged() } }
        case .look:
            SettingsPage(title: "apariencia") {
                ChoiceRow(title: "idioma", options: LanguageChoice.allCases.map { ($0, languageTitle($0)) }, selection: $language.choice)
                ChoiceRow(title: "tema", options: ThemeChoice.allCases.map { ($0, $0.title) }, selection: $appearance.choice)
                ChoiceRow(title: "líquidos", options: VolumeUnit.allCases.map { ($0, $0.title) }, selection: $store.profile.volumeUnit)
                ChoiceRow(title: "temperatura", options: TemperatureUnit.allCases.map { ($0, $0.title) }, selection: $store.profile.temperatureUnit)
                Toggle(isOn: $store.profile.haptics) { Caption("háptico") }.tint(Palette.moss)
                Toggle(isOn: $store.profile.sounds) { Caption("sonidos de juegos") }.tint(Palette.moss)
            }
        case .motion:
            MotionSettingsPage()
        case .about:
            SettingsPage(title: "acerca de") {
                Text("girasol").font(.serif(20, italic: true)).foregroundStyle(Palette.ink)
                Caption("versión \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "")")
                Text("clima y uv: Open-Meteo.com (cc by 4.0). exposición: el sensor de luz de tu reloj. salud: la app Salud, en tu dispositivo.")
                    .font(.serif(10, italic: true)).foregroundStyle(Palette.mid).multilineTextAlignment(.center)
                Text("girasol no es un dispositivo médico. los cálculos son aproximados y no sustituyen a un profesional.")
                    .font(.serif(10, italic: true)).foregroundStyle(Palette.mid).multilineTextAlignment(.center)
                Text("✦").font(.serif(12)).foregroundStyle(Palette.faint)
            }
        }
    }
}

/// sensibilidad y calibraciones de los juegos de movimiento.
struct MotionSettingsPage: View {
    private let motion = MotionSettings.shared
    @State private var sensitivity = MotionSettings.shared.sensitivity
    @State private var meter = MotionSettings.shared.showMeter
    @State private var touch = MotionSettings.shared.touchMode
    @State private var cleared = false

    var body: some View {
        SettingsPage(title: "movimiento") {
            NumberRow(title: "sensibilidad", value: Binding(get: { Int((sensitivity * 10).rounded()) }, set: { sensitivity = Double($0) / 10; motion.sensitivity = sensitivity }),
                      range: 6...16, step: 1, unit: "/10")
            Text("más alto = el gesto se detecta con menos fuerza.").font(.serif(10, italic: true)).foregroundStyle(Palette.mid)
            Toggle(isOn: $meter) { Caption("medidor de movimiento") }.tint(Palette.moss)
                .onChange(of: meter) { motion.showMeter = meter }
            Toggle(isOn: $touch) { Caption("jugar tocando") }.tint(Palette.moss)
                .onChange(of: touch) { motion.touchMode = touch }
            NavigationLink(value: Route.calibrate) { SettingLabel(title: "puntería", value: motion.mapping == nil ? "sin calibrar" : "calibrada") }
                .buttonStyle(.plain)
            Button(cleared ? "fuerza reiniciada" : "reiniciar fuerza") {
                motion.basketPower.reset(); motion.dartsPower.reset(); cleared = true; Haptics.play(.click)
            }.buttonStyle(QuietButtonStyle())
        }
    }
}

/// los idiomas se nombran en su propio idioma; solo "sistema" se traduce.
private func languageTitle(_ c: LanguageChoice) -> String {
    switch c {
    case .system: loc("sistema")
    case .es: "español"
    case .en: "english"
    }
}
