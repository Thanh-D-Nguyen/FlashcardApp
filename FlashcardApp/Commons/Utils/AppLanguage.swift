//
//  AppLanguage.swift
//  FlashcardApp
//
//  The three UI languages the app ships: Vietnamese, English, Japanese. At launch the bundle resolves the
//  language from the system language, or from the choice the user made in Settings (`LanguageOption`, written
//  to `AppleLanguages`). A change made while the app runs goes through `AppLocalization`, which switches the
//  strings at once. This type mirrors the active language for things the bundle cannot do, such as picking
//  the matching backend text and formatting numbers. UI strings live in `Localizable.xcstrings`.
//

import Foundation
import ObjectiveC

enum AppLanguage: String, CaseIterable {
    case vietnamese = "vi"
    case english = "en"
    case japanese = "ja"

    /// Language the app is showing now: the one chosen in this run, else the one iOS resolved at launch
    /// (after matching the user's preferences to the app's localizations). Falls back to English.
    static var current: AppLanguage {
        AppLocalization.activeLanguage ?? resolve(Bundle.main.preferredLocalizations)
    }

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

/// The language picked in Settings. `system` follows the device language; a language option pins the app
/// to that language from the next launch on, because iOS resolves the bundle's localization at launch.
enum LanguageOption: String, CaseIterable {
    case system = "system"
    case vietnamese = "vi"
    case english = "en"
    case japanese = "ja"

    /// Stored preference → option; anything unrecognised means "follow the system".
    static func resolve(_ stored: String) -> LanguageOption {
        LanguageOption(rawValue: stored) ?? .system
    }

    /// The language this option pins; nil for `system`.
    var appLanguage: AppLanguage? { AppLanguage(rawValue: rawValue) }

    /// Value for `AppleLanguages`; nil removes the override so iOS chooses the language again.
    var appleLanguages: [String]? {
        self == .system ? nil : [rawValue]
    }

    var title: String {
        switch self {
        case .system: return NSLocalizedString("System", comment: "Language option that follows the device language")
        case .vietnamese: return AppLanguage.vietnamese.nativeName
        case .english: return AppLanguage.english.nativeName
        case .japanese: return AppLanguage.japanese.nativeName
        }
    }
}

/// Switches the strings the app reads while it runs. The bundle fixes its localization at launch, so the
/// switch changes the class of `Bundle.main` to one that reads strings from the chosen `.lproj`; the
/// `NSLocalizedString` calls go through that method, so screens rebuilt afterwards show the new language.
enum AppLocalization {

    /// Language chosen in this run; nil until the user changes it, when the launch-time language applies.
    private(set) static var activeLanguage: AppLanguage?

    /// Strings for the active language; nil means the launch-time localization is used.
    fileprivate static var languageBundle: Bundle?

    /// Makes `option` the language of every string read from now on. Call it alongside writing
    /// `LanguageOption.appleLanguages`, which keeps the choice for the next launch.
    static func activate(_ option: LanguageOption) {
        let language = option.appLanguage ?? systemLanguage
        if !(Bundle.main is LocalizedMainBundle) {
            object_setClass(Bundle.main, LocalizedMainBundle.self)
        }
        activeLanguage = language
        languageBundle = Bundle.main.path(forResource: language.rawValue, ofType: "lproj").flatMap(Bundle.init(path:))
    }

    /// Back to the launch-time language. Tests use it to leave the process as they found it.
    static func reset() {
        activeLanguage = nil
        languageBundle = nil
    }

    /// The language iOS picks for this device, ignoring the in-app choice. The device list is read from the
    /// defaults, which already reflect the removal of the app's own override; `Locale.preferredLanguages` is
    /// not used because it can keep the list it had earlier in the same process.
    private static var systemLanguage: AppLanguage {
        let devicePreferences = UserDefaults.standard.stringArray(forKey: "AppleLanguages") ?? Locale.preferredLanguages
        return AppLanguage.resolve(Bundle.preferredLocalizations(from: Bundle.main.localizations, forPreferences: devicePreferences))
    }
}

/// `Bundle.main` after `AppLocalization.activate`: the same bundle, with strings taken from the active language.
private final class LocalizedMainBundle: Bundle, @unchecked Sendable {

    override func localizedString(forKey key: String, value: String?, table tableName: String?) -> String {
        guard let languageBundle = AppLocalization.languageBundle else {
            return super.localizedString(forKey: key, value: value, table: tableName)
        }
        return languageBundle.localizedString(forKey: key, value: value, table: tableName)
    }
}
