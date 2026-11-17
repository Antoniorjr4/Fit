import Foundation

enum AppLanguage: String, CaseIterable, Identifiable {
    case portuguese = "pt-BR", english = "en", spanish = "es"
    case french = "fr", german = "de", italian = "it"
    var id: String { rawValue }
    var nativeName: String {
        switch self {
        case .portuguese: "Português (Brasil)"
        case .english: "English"
        case .spanish: "Español"
        case .french: "Français"
        case .german: "Deutsch"
        case .italian: "Italiano"
        }
    }
    var locale: Locale { Locale(identifier: rawValue) }
    static func recommended(for preferences: [String] = Locale.preferredLanguages) -> AppLanguage {
        for preference in preferences {
            let code = preference.replacingOccurrences(of: "_", with: "-").split(separator: "-").first.map(String.init)
            if code == "pt" { return .portuguese }
            if let language = allCases.first(where: { $0.rawValue == code }) { return language }
        }
        return .english
    }
    // Explicit resource selection lets the in-app choice take effect immediately.
    // No mutation of Apple's global language preferences or Bundle swizzling.
    private var bundle: Bundle {
        guard let path = Bundle.main.path(forResource: rawValue, ofType: "lproj"),
              let bundle = Bundle(path: path) else { return Bundle.main }
        return bundle
    }
    func text(_ key: String, _ arguments: CVarArg...) -> String { format(key, arguments) }
    func format(_ key: String, _ arguments: [CVarArg]) -> String {
        let fallback = Bundle.main.path(forResource: "en", ofType: "lproj")
            .flatMap(Bundle.init(path:))?.localizedString(forKey: key, value: key, table: nil) ?? key
        let template = bundle.localizedString(forKey: key, value: fallback, table: nil)
        return arguments.isEmpty ? template : String(format: template, locale: locale, arguments: arguments)
    }
}
