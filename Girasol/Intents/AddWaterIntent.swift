import AppIntents

/// "un vaso de agua": se puede asignar al boton de accion del Apple Watch Ultra desde Ajustes > Boton de accion > Atajo.
struct AddWaterIntent: AppIntent {
    static let title: LocalizedStringResource = "Registrar un vaso de agua"
    static let description = IntentDescription("Suma un vaso de agua a tu registro de Salud.")
    static let openAppWhenRun = false

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let glass = ProfileStore.load().glassMl
        let ok = await HealthStore.shared.addWater(ml: glass)
        return .result(dialog: ok ? "Listo: \(glass) ml de agua." : "No pude guardar el agua. Revisa el permiso de Salud.")
    }
}

struct GirasolShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: AddWaterIntent(),
                    phrases: ["Registrar agua en \(.applicationName)", "Un vaso de agua en \(.applicationName)"],
                    shortTitle: "vaso de agua", systemImageName: "drop")
    }
}
