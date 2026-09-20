import Foundation

/// traduccion de los textos que generan los paquetes. los paquetes escriben en español (el idioma base); la app pone
/// aqui su traductor al arrancar. sin traductor (las pruebas) el texto sale tal cual.
public enum L10n {
    nonisolated(unsafe) public static var translate: (String) -> String = { $0 }

    /// `key` es el texto en español; con argumentos se usa como formato (`%d`, `%@`, `%%` para un % literal).
    public static func tr(_ key: String, _ args: CVarArg...) -> String {
        let text = translate(key)
        return args.isEmpty ? text : String(format: text, arguments: args)
    }
}
