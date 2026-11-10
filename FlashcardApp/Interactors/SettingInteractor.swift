//
//  SettingInteractor.swift
//  FlashcardApp
//
//  Created by タイン・グエン on 2023/02/19.
//

import Foundation
import RxSwift
import UserNotifications

protocol SettingInteractorInterface: AnyObject {
    func getCurrentUser() -> SocialUserEntity?
    func logout() throws
    var authStateChanges: Observable<Void> { get }
    func refreshCurrentUser() -> Single<Void>
    func logoutSession() -> Single<LogoutResult>
    func deleteAccountSession() -> Single<Void>
    func getAppearance() -> String
    func setAppearance(_ value: String)
    /// Stores a `LanguageOption` raw value and switches the app's strings to it immediately.
    func getLanguage() -> String
    func setLanguage(_ value: String)
    func getNotificationEnabled() -> Bool
    func setNotificationEnabled(_ enabled: Bool)
    func getReminderHour() -> Int
    func setReminderHour(_ hour: Int)
    func scheduleDailyReminder(hour: Int, completion: @escaping (Error?) -> Void)
    func cancelDailyReminder()
    func getNotificationAuthorizationStatus() -> UNAuthorizationStatus
    /// Keeps the cached system answer in step with what the permission prompt just returned.
    func setNotificationAuthorizationStatus(_ status: UNAuthorizationStatus)
    /// Shows the system prompt (once per install); `completion` runs on the main thread.
    func requestNotificationPermission(completion: @escaping (Bool) -> Void)
    func getSoundEnabled() -> Bool
    func setSoundEnabled(_ enabled: Bool)
}

extension SettingInteractorInterface {
    var authStateChanges: Observable<Void> { .empty() }
    func refreshCurrentUser() -> Single<Void> { .just(()) }
    func logoutSession() -> Single<LogoutResult> {
        .deferred { try self.logout(); return .just(.revoked) }
    }
}

final class SettingInteractor: SettingInteractorInterface {

    private let session: AuthSession
    private let preferences: UserPreferencesInterface

    init(preferences: UserPreferencesInterface = UserDefaultsPreferences.shared,
         session: AuthSession = .shared) {
        self.session = session
        self.preferences = preferences
    }

    // MARK: - Auth

    func getCurrentUser() -> SocialUserEntity? {
        session.currentUser
    }

    func logout() throws {
        try session.clear()
    }

    var authStateChanges: Observable<Void> { session.authStateChanges }
    func refreshCurrentUser() -> Single<Void> { session.refresh() }
    func logoutSession() -> Single<LogoutResult> { session.logout() }
    func deleteAccountSession() -> Single<Void> { session.deleteAccount() }

    // MARK: - Appearance

    func getAppearance() -> String {
        preferences.appearance
    }

    func setAppearance(_ value: String) {
        preferences.appearance = value
    }

    // MARK: - Language

    func getLanguage() -> String {
        preferences.language
    }

    func setLanguage(_ value: String) {
        preferences.language = value
        AppLocalization.activate(LanguageOption.resolve(value))
        DailyStudyReminder.restoreIfNeeded(preferences: preferences)
    }

    // MARK: - Notifications

    func getNotificationEnabled() -> Bool {
        preferences.isNotificationEnabled
    }

    func setNotificationEnabled(_ enabled: Bool) {
        preferences.isNotificationEnabled = enabled
    }

    func getReminderHour() -> Int { preferences.reminderHour }

    func setReminderHour(_ hour: Int) { preferences.reminderHour = hour }

    func scheduleDailyReminder(hour: Int, completion: @escaping (Error?) -> Void) {
        DailyStudyReminder.schedule(hour: hour, soundEnabled: preferences.isSoundEnabled, completion: completion)
    }

    func cancelDailyReminder() { DailyStudyReminder.cancel() }

    func getNotificationAuthorizationStatus() -> UNAuthorizationStatus {
        // Synchronous read is not available; presenter should check async if needed.
        // For section building we cache last known status in preferences.
        return preferences.notificationAuthorizationStatus
    }

    func setNotificationAuthorizationStatus(_ status: UNAuthorizationStatus) {
        preferences.notificationAuthorizationStatus = status
    }

    func requestNotificationPermission(completion: @escaping (Bool) -> Void) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, _ in
            DispatchQueue.main.async { completion(granted) }
        }
    }

    // MARK: - Sound

    func getSoundEnabled() -> Bool {
        preferences.isSoundEnabled
    }

    func setSoundEnabled(_ enabled: Bool) {
        preferences.isSoundEnabled = enabled
    }
}

// Local reminders survive app termination. The stable ID prevents duplicates and protects other notifications.
enum DailyStudyReminder {
    static let identifier = "com.flashcardapp.study.dailyReminder"
    static let openReviewNotification = Notification.Name("DailyStudyReminder.openReview")
    private static var shouldOpenReview = false

    static func requestOpenReview(center: NotificationCenter = .default) {
        shouldOpenReview = true
        center.post(name: openReviewNotification, object: nil)
    }

    static func consumeOpenReview() -> Bool {
        guard shouldOpenReview else { return false }
        shouldOpenReview = false
        return true
    }

    static func makeRequest(hour: Int, soundEnabled: Bool) -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        content.title = NSLocalizedString("Time to study Japanese", comment: "Daily study reminder title")
        content.body = NSLocalizedString("A few minutes of review today will help you remember more.", comment: "Daily study reminder message")
        if soundEnabled { content.sound = .default }
        let trigger = UNCalendarNotificationTrigger(dateMatching: DateComponents(hour: hour, minute: 0), repeats: true)
        return UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
    }

    static func needsRescheduling(existing: UNNotificationRequest?, hour: Int, soundEnabled: Bool) -> Bool {
        guard let existing,
              existing.identifier == identifier,
              let trigger = existing.trigger as? UNCalendarNotificationTrigger else { return true }
        let desired = makeRequest(hour: hour, soundEnabled: soundEnabled)
        return !trigger.repeats || trigger.dateComponents.hour != hour || trigger.dateComponents.minute != 0
            || existing.content.title != desired.content.title
            || existing.content.body != desired.content.body
            || (existing.content.sound == nil) != (desired.content.sound == nil)
    }

    static func schedule(hour: Int, soundEnabled: Bool, completion: @escaping (Error?) -> Void) {
        UNUserNotificationCenter.current().add(makeRequest(hour: hour, soundEnabled: soundEnabled)) { error in
            DispatchQueue.main.async { completion(error) }
        }
    }

    static func cancel() {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
        center.removeDeliveredNotifications(withIdentifiers: [identifier])
    }

    static func canSchedule(enabled: Bool, authorization: UNAuthorizationStatus) -> Bool {
        enabled && [.authorized, .provisional, .ephemeral].contains(authorization)
    }

    static func restoreIfNeeded(preferences: UserPreferencesInterface = UserDefaultsPreferences.shared) {
        guard preferences.isNotificationEnabled else {
            cancel()
            return
        }
        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { settings in
            preferences.notificationAuthorizationStatus = settings.authorizationStatus
            guard canSchedule(enabled: preferences.isNotificationEnabled,
                              authorization: settings.authorizationStatus) else {
                cancel()
                return
            }
            center.getPendingNotificationRequests { requests in
                DispatchQueue.main.async {
                    guard canSchedule(enabled: preferences.isNotificationEnabled,
                                      authorization: preferences.notificationAuthorizationStatus) else {
                        cancel()
                        return
                    }
                    let hour = preferences.reminderHour
                    let soundEnabled = preferences.isSoundEnabled
                    guard needsRescheduling(existing: requests.first(where: { $0.identifier == identifier }),
                                            hour: hour, soundEnabled: soundEnabled) else { return }
                    schedule(hour: hour, soundEnabled: soundEnabled) { error in
                        if let error { NSLog("Could not restore daily study reminder: %@", error.localizedDescription) }
                        if !preferences.isNotificationEnabled { cancel() }
                    }
                }
            }
        }
    }
}
