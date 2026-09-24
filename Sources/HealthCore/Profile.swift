import Foundation
import Localization

public enum Sex: String, Codable, CaseIterable, Sendable {
    case female, male, other
    public var title: String { switch self { case .female: L10n.tr("mujer"); case .male: L10n.tr("hombre"); case .other: L10n.tr("prefiero no decir") } }
}

public enum Objective: String, Codable, CaseIterable, Sendable {
    case lose, maintain, gain
    public var title: String { switch self { case .lose: L10n.tr("bajar de peso"); case .maintain: L10n.tr("mantener"); case .gain: L10n.tr("subir de peso") } }
}

public enum ActivityLevel: String, Codable, CaseIterable, Sendable {
    case sedentary, light, moderate, active, veryActive
    public var factor: Double { switch self { case .sedentary: 1.2; case .light: 1.375; case .moderate: 1.55; case .active: 1.725; case .veryActive: 1.9 } }
    public var title: String {
        switch self {
        case .sedentary: L10n.tr("sedentario")
        case .light: L10n.tr("ligero")
        case .moderate: L10n.tr("moderado")
        case .active: L10n.tr("activo")
        case .veryActive: L10n.tr("muy activo")
        }
    }
}

public enum VolumeUnit: String, Codable, CaseIterable, Sendable {
    case ml, oz
    public var title: String { self == .ml ? L10n.tr("mililitros") : L10n.tr("onzas") }
    /// texto de un volumen en ml en la unidad elegida.
    public func text(ml: Int) -> String {
        switch self {
        case .ml: return "\(ml) ml"
        case .oz: return String(format: "%.0f oz", Double(ml) / 29.5735)
        }
    }
}

public enum TemperatureUnit: String, Codable, CaseIterable, Sendable {
    case celsius, fahrenheit
    public var title: String { self == .celsius ? "°C" : "°F" }
    public func text(celsius c: Double) -> String {
        switch self {
        case .celsius: return "\(Int(c.rounded()))°"
        case .fahrenheit: return "\(Int((c * 9 / 5 + 32).rounded()))°"
        }
    }
}

/// todo lo que el usuario personaliza. se guarda como json.
public struct Profile: Codable, Equatable, Sendable {
    public var name = ""
    public var sex = Sex.other
    public var birthYear: Int?
    public var heightCm: Double?
    public var weightKg: Double?
    public var activity = ActivityLevel.light
    public var objective = Objective.maintain

    public var waterGoalMl = 2000
    public var glassMl = 250
    public var kcalGoal = 2000
    public var addActivityToKcal = false
    public var stepGoal = 8000

    public var volumeUnit = VolumeUnit.ml
    public var temperatureUnit = TemperatureUnit.celsius

    public var waterReminders = true
    public var reminderEveryHours = 2
    public var wakeHour = 8
    public var sleepHour = 21

    public var breathingPattern = "calm"
    public var breathingMinutes = 1
    public var sounds = true
    public var haptics = true
    public var onboarded = false

    /// minutos de respiracion/mindfulness que cuentan para la racha del dia; 0 desactiva ese requisito.
    public var mindfulGoalMinutes = 5

    public var postureReminders = true
    /// horas seguidas sentado antes de avisar a estirar.
    public var sedentaryThresholdHours = 2

    public var focusPattern = "classic"
    public var focusMinutes = 30

    public init() {}

    private enum CodingKeys: String, CodingKey {
        case name, sex, birthYear, heightCm, weightKg, activity, objective, waterGoalMl, glassMl, kcalGoal, addActivityToKcal, stepGoal
        case volumeUnit, temperatureUnit, waterReminders, reminderEveryHours, wakeHour, sleepHour
        case breathingPattern, breathingMinutes, sounds, haptics, onboarded, mindfulGoalMinutes
        case postureReminders, sedentaryThresholdHours, focusPattern, focusMinutes
    }

    /// tolera datos guardados por versiones anteriores: lo que falte queda con su valor por defecto.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = Profile()
        name = try c.decodeIfPresent(String.self, forKey: .name) ?? d.name
        sex = try c.decodeIfPresent(Sex.self, forKey: .sex) ?? d.sex
        birthYear = try c.decodeIfPresent(Int.self, forKey: .birthYear)
        heightCm = try c.decodeIfPresent(Double.self, forKey: .heightCm)
        weightKg = try c.decodeIfPresent(Double.self, forKey: .weightKg)
        activity = try c.decodeIfPresent(ActivityLevel.self, forKey: .activity) ?? d.activity
        objective = try c.decodeIfPresent(Objective.self, forKey: .objective) ?? d.objective
        waterGoalMl = try c.decodeIfPresent(Int.self, forKey: .waterGoalMl) ?? d.waterGoalMl
        glassMl = try c.decodeIfPresent(Int.self, forKey: .glassMl) ?? d.glassMl
        kcalGoal = try c.decodeIfPresent(Int.self, forKey: .kcalGoal) ?? d.kcalGoal
        addActivityToKcal = try c.decodeIfPresent(Bool.self, forKey: .addActivityToKcal) ?? d.addActivityToKcal
        stepGoal = try c.decodeIfPresent(Int.self, forKey: .stepGoal) ?? d.stepGoal
        volumeUnit = try c.decodeIfPresent(VolumeUnit.self, forKey: .volumeUnit) ?? d.volumeUnit
        temperatureUnit = try c.decodeIfPresent(TemperatureUnit.self, forKey: .temperatureUnit) ?? d.temperatureUnit
        waterReminders = try c.decodeIfPresent(Bool.self, forKey: .waterReminders) ?? d.waterReminders
        reminderEveryHours = try c.decodeIfPresent(Int.self, forKey: .reminderEveryHours) ?? d.reminderEveryHours
        wakeHour = try c.decodeIfPresent(Int.self, forKey: .wakeHour) ?? d.wakeHour
        sleepHour = try c.decodeIfPresent(Int.self, forKey: .sleepHour) ?? d.sleepHour
        breathingPattern = try c.decodeIfPresent(String.self, forKey: .breathingPattern) ?? d.breathingPattern
        breathingMinutes = try c.decodeIfPresent(Int.self, forKey: .breathingMinutes) ?? d.breathingMinutes
        sounds = try c.decodeIfPresent(Bool.self, forKey: .sounds) ?? d.sounds
        haptics = try c.decodeIfPresent(Bool.self, forKey: .haptics) ?? d.haptics
        onboarded = try c.decodeIfPresent(Bool.self, forKey: .onboarded) ?? d.onboarded
        mindfulGoalMinutes = try c.decodeIfPresent(Int.self, forKey: .mindfulGoalMinutes) ?? d.mindfulGoalMinutes
        postureReminders = try c.decodeIfPresent(Bool.self, forKey: .postureReminders) ?? d.postureReminders
        sedentaryThresholdHours = try c.decodeIfPresent(Int.self, forKey: .sedentaryThresholdHours) ?? d.sedentaryThresholdHours
        focusPattern = try c.decodeIfPresent(String.self, forKey: .focusPattern) ?? d.focusPattern
        focusMinutes = try c.decodeIfPresent(Int.self, forKey: .focusMinutes) ?? d.focusMinutes
    }

    /// nombre listo para mostrar: sin espacios de sobra y con tope de largo.
    public var displayName: String {
        String(name.trimmingCharacters(in: .whitespacesAndNewlines).prefix(20))
    }

    /// deja todos los valores en rangos razonables, venga lo que venga de disco o del usuario.
    public func sanitized() -> Profile {
        var p = self
        p.name = displayName
        p.waterGoalMl = min(6000, max(500, waterGoalMl))
        p.glassMl = min(1000, max(100, glassMl))
        p.kcalGoal = min(6000, max(800, kcalGoal))
        p.stepGoal = min(40000, max(1000, stepGoal))
        p.reminderEveryHours = min(6, max(1, reminderEveryHours))
        p.wakeHour = min(12, max(4, wakeHour))
        p.sleepHour = min(23, max(p.wakeHour + 6, sleepHour))
        p.breathingMinutes = min(5, max(1, breathingMinutes))
        p.mindfulGoalMinutes = min(60, max(0, mindfulGoalMinutes))
        p.sedentaryThresholdHours = min(6, max(1, sedentaryThresholdHours))
        p.focusMinutes = min(120, max(10, focusMinutes))
        if let h = heightCm { p.heightCm = min(230, max(100, h)) }
        if let w = weightKg { p.weightKg = min(250, max(25, w)) }
        return p
    }
}

public enum Greeting {
    public static func text(hour: Int, name: String) -> String {
        let base: String
        switch hour {
        case 5..<12: base = L10n.tr("buenos días")
        case 12..<19: base = L10n.tr("buenas tardes")
        default: base = L10n.tr("buenas noches")
        }
        let n = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return n.isEmpty ? base : "\(base), \(n)"
    }
}
