import Foundation

enum L10n {
    static var locale: Locale {
        let identifier = localizedBundle.preferredLocalizations.first
            ?? Bundle.main.preferredLocalizations.first
            ?? Locale.current.identifier
        return Locale(identifier: identifier)
    }

    static func text(_ key: String) -> String {
        localizedBundle.localizedString(forKey: key, value: key, table: nil)
    }

    static func format(_ key: String, _ arguments: CVarArg...) -> String {
        String(format: text(key), locale: locale, arguments: arguments)
    }

    private static var localizedBundle: Bundle {
        if Bundle.main.url(forResource: "Localizable", withExtension: "strings") != nil {
            return .main
        }
        return .module
    }
}
