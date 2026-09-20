import Foundation
import HealthCore
import SunKit
import WidgetKit

/// le pasa a las complicaciones lo ultimo que sabe la app y les pide que se redibujen.
enum WidgetSync {
    static func weather(_ w: WeatherSnapshot) {
        WidgetSnapshot.update {
            $0.uv = w.hours.map { .init(start: $0.start, uvi: $0.uvIndex) }
            $0.apparentC = w.current.apparentTemperature
        }
        WidgetCenter.shared.reloadAllTimelines()
    }

    /// las complicaciones viven en otro proceso: se les dice que idioma usar.
    static func language(_ code: String) {
        WidgetSnapshot.update { $0.language = code }
        WidgetCenter.shared.reloadAllTimelines()
    }

    static func totals(_ t: TodayTotals, profile p: Profile, kcalRemaining: Int) {
        WidgetSnapshot.update {
            $0.waterMl = t.waterMl
            $0.waterGoal = p.waterGoalMl
            $0.kcalRemaining = kcalRemaining
            $0.kcalGoal = p.kcalGoal
            $0.steps = Int(t.steps)
            $0.stepGoal = p.stepGoal
        }
        WidgetCenter.shared.reloadAllTimelines()
    }
}
