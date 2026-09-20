import Foundation

public enum Nutrition {
    /// tasa metabolica basal (mifflin-st jeor). "otro" usa el promedio de las dos constantes.
    public static func bmr(sex: Sex, weightKg: Double, heightCm: Double, age: Int) -> Double {
        let base = 10 * weightKg + 6.25 * heightCm - 5 * Double(age)
        switch sex {
        case .male: return base + 5
        case .female: return base - 161
        case .other: return base - 78
        }
    }

    /// meta orientativa de kcal al dia; nil si faltan peso, estatura o año de nacimiento.
    public static func suggestedGoal(_ p: Profile, year: Int) -> Int? {
        guard let w = p.weightKg, let h = p.heightCm, let born = p.birthYear else { return nil }
        let age = max(10, year - born)
        var kcal = bmr(sex: p.sex, weightKg: w, heightCm: h, age: age) * p.activity.factor
        switch p.objective {
        case .lose: kcal -= 500
        case .maintain: break
        case .gain: kcal += 300
        }
        kcal = min(4500, max(1200, kcal))
        return Int((kcal / 50).rounded()) * 50
    }

    public static func fraction(consumed: Double, goal: Int) -> Double {
        consumed / Double(max(1, goal))
    }

    /// kcal que te quedan; con `addActivity`, la energia activa quemada amplia la meta.
    public static func remaining(goal: Int, consumed: Double, active: Double, addActivity: Bool) -> Int {
        Int((Double(goal) + (addActivity ? active : 0) - consumed).rounded())
    }
}
