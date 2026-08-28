import Foundation

/// The app's supported UI languages, for content that lives in Swift rather than
/// `Localizable.xcstrings` (writing prompts, demo diary text).
///
/// `Localizable.xcstrings` covers every user-facing label; this only exists where a
/// whole *table* of copy has to be picked at runtime.
enum AppLanguage: String, CaseIterable {
    case en, ja, ko, zhHans, zhHant, es

    /// Resolved from the bundle's chosen localization, so it always matches the
    /// language the UI is actually rendering in — `Locale.current` can report a
    /// region language the bundle has no strings for.
    static var current: AppLanguage {
        let identifier = Bundle.main.preferredLocalizations.first
            ?? Locale.preferredLanguages.first
            ?? "en"
        return from(identifier)
    }

    static func from(_ identifier: String) -> AppLanguage {
        let locale = Locale(identifier: identifier)
        guard let code = locale.language.languageCode?.identifier else { return .en }
        switch code {
        case "ja": return .ja
        case "ko": return .ko
        case "es": return .es
        case "zh":
            // Hant for TW/HK/MO even when the script subtag is absent (e.g. "zh-TW").
            if let script = locale.language.script?.identifier {
                return script == "Hant" ? .zhHant : .zhHans
            }
            return ["TW", "HK", "MO"].contains(locale.region?.identifier ?? "") ? .zhHant : .zhHans
        default: return .en
        }
    }

    /// Picks this language's entry out of a copy table, falling back to English.
    func pick<T>(_ table: [AppLanguage: T]) -> T {
        table[self] ?? table[.en]!
    }

    /// URL prefix of this language's pages on smartkiitos.com (English lives at the root).
    var sitePrefix: String {
        switch self {
        case .en: return ""
        case .zhHans: return "/zh"
        case .zhHant: return "/zh-Hant"
        case .ja: return "/ja"
        case .ko: return "/ko"
        case .es: return "/es"
        }
    }

    /// A NoDiary page on smartkiitos.com in the current UI language.
    /// `path` is the part after the locale prefix, e.g. `"/nodiary/privacy/"`.
    static func siteURL(_ path: String) -> URL {
        URL(string: "https://smartkiitos.com" + current.sitePrefix + path)!
    }
}
