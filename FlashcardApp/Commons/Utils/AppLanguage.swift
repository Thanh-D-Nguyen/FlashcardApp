//
//  AppLanguage.swift
//  FlashcardApp
//
//  The three UI languages the app ships: Vietnamese, English, Japanese. The language is chosen by iOS
//  (Settings ▸ FlashcardApp ▸ Language, or the system language) and resolved by the bundle; this type only
//  mirrors that choice for things the bundle cannot do, such as picking the matching backend text and
//  formatting numbers. UI strings live in `Localizable.xcstrings`.
//

import Foundation

enum AppLanguage: String, CaseIterable {
    case vietnamese = "vi"
    case english = "en"
    case japanese = "ja"

    /// Language the running app is localized into, after iOS has matched the user's preferences to the
    /// app's localizations. Falls back to English, the development language.
    static var current: AppLanguage { resolve(Bundle.main.preferredLocalizations) }

    /// First preferred localization that is one of ours ("ja-JP" counts as "ja"); English otherwise.
    static func resolve(_ preferred: [String]) -> AppLanguage {
        for identifier in preferred {
            let code = identifier.split(whereSeparator: { $0 == "-" || $0 == "_" }).first.map(String.init) ?? identifier
            if let language = AppLanguage(rawValue: code.lowercased()) { return language }
        }
        return .english
    }

    /// Locale for numbers and dates: follows the app language, not the device region, so a Japanese UI
    /// never shows Vietnamese digit grouping.
    var locale: Locale { Locale(identifier: rawValue) }

    /// Name of the language in that language; deliberately not translated (the picker convention).
    var nativeName: String {
        switch self {
        case .vietnamese: return "Tiếng Việt"
        case .english: return "English"
        case .japanese: return "日本語"
        }
    }
}
