//
//  UserPreferences.swift
//  FlashcardApp
//
//  Created by Claude on 2026/09/07.
//

import Foundation
import UserNotifications

protocol UserPreferencesInterface: AnyObject {
    var appearance: String { get set }
    /// `LanguageOption` raw value: "system" or a language code.
    var language: String { get set }
    var isNotificationEnabled: Bool { get set }
    var reminderHour: Int { get set }
    var notificationAuthorizationStatus: UNAuthorizationStatus { get set }
    var isSoundEnabled: Bool { get set }
}

final class UserDefaultsPreferences: UserPreferencesInterface {

    static let shared = UserDefaultsPreferences()

    private let defaults = UserDefaults.standard

    private enum Keys {
        static let appearance = "com.flashcardapp.settings.appearance"
        static let language = "com.flashcardapp.settings.language"
        static let notification = "com.flashcardapp.settings.notification"
        static let reminderHour = "com.flashcardapp.settings.reminderHour"
        static let notificationAuthStatus = "com.flashcardapp.settings.notificationAuthStatus"
        static let sound = "com.flashcardapp.settings.sound"
        /// The key iOS itself reads for the app's language list at launch.
        static let appleLanguages = "AppleLanguages"
    }

    private init() {}

    var appearance: String {
        get { defaults.string(forKey: Keys.appearance) ?? AppearanceOption.system.rawValue }
        set { defaults.set(newValue, forKey: Keys.appearance) }
    }

    var language: String {
        get { defaults.string(forKey: Keys.language) ?? LanguageOption.system.rawValue }
        set {
            let option = LanguageOption.resolve(newValue)
            defaults.set(option.rawValue, forKey: Keys.language)
            // The bundle's language is fixed when the app launches, so this takes effect on the next launch.
            if let languages = option.appleLanguages {
                defaults.set(languages, forKey: Keys.appleLanguages)
            } else {
                defaults.removeObject(forKey: Keys.appleLanguages)
            }
        }
    }

    var isNotificationEnabled: Bool {
        get { defaults.bool(forKey: Keys.notification) }
        set { defaults.set(newValue, forKey: Keys.notification) }
    }

    var reminderHour: Int {
        get {
            guard let stored = defaults.object(forKey: Keys.reminderHour) as? Int,
                  (0..<24).contains(stored) else { return 20 }
            return stored
        }
        set { if (0..<24).contains(newValue) { defaults.set(newValue, forKey: Keys.reminderHour) } }
    }

    var notificationAuthorizationStatus: UNAuthorizationStatus {
        get {
            let raw = defaults.integer(forKey: Keys.notificationAuthStatus)
            return UNAuthorizationStatus(rawValue: raw) ?? .notDetermined
        }
        set { defaults.set(newValue.rawValue, forKey: Keys.notificationAuthStatus) }
    }

    var isSoundEnabled: Bool {
        get { defaults.object(forKey: Keys.sound) == nil || defaults.bool(forKey: Keys.sound) }
        set { defaults.set(newValue, forKey: Keys.sound) }
    }
}
