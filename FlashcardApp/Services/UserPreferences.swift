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
    var isNotificationEnabled: Bool { get set }
    var notificationAuthorizationStatus: UNAuthorizationStatus { get set }
    var isSoundEnabled: Bool { get set }
}

final class UserDefaultsPreferences: UserPreferencesInterface {

    static let shared = UserDefaultsPreferences()

    private let defaults = UserDefaults.standard

    private enum Keys {
        static let appearance = "com.flashcardapp.settings.appearance"
        static let notification = "com.flashcardapp.settings.notification"
        static let notificationAuthStatus = "com.flashcardapp.settings.notificationAuthStatus"
        static let sound = "com.flashcardapp.settings.sound"
    }

    private init() {}

    var appearance: String {
        get { defaults.string(forKey: Keys.appearance) ?? AppearanceOption.system.rawValue }
        set { defaults.set(newValue, forKey: Keys.appearance) }
    }

    var isNotificationEnabled: Bool {
        get { defaults.bool(forKey: Keys.notification) }
        set { defaults.set(newValue, forKey: Keys.notification) }
    }

    var notificationAuthorizationStatus: UNAuthorizationStatus {
        get {
            let raw = defaults.integer(forKey: Keys.notificationAuthStatus)
            return UNAuthorizationStatus(rawValue: raw) ?? .notDetermined
        }
        set { defaults.set(newValue.rawValue, forKey: Keys.notificationAuthStatus) }
    }

    var isSoundEnabled: Bool {
        get { defaults.bool(forKey: Keys.sound) }
        set { defaults.set(newValue, forKey: Keys.sound) }
    }
}