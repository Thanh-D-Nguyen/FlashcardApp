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
    func logoutSession() -> Single<Void>
    func getAppearance() -> String
    func setAppearance(_ value: String)
    func getNotificationEnabled() -> Bool
    func setNotificationEnabled(_ enabled: Bool)
    func getNotificationAuthorizationStatus() -> UNAuthorizationStatus
    func getSoundEnabled() -> Bool
    func setSoundEnabled(_ enabled: Bool)
}

extension SettingInteractorInterface {
    var authStateChanges: Observable<Void> { .empty() }
    func refreshCurrentUser() -> Single<Void> { .just(()) }
    func logoutSession() -> Single<Void> {
        .deferred { try self.logout(); return .just(()) }
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
    func logoutSession() -> Single<Void> { session.logout() }

    // MARK: - Appearance

    func getAppearance() -> String {
        preferences.appearance
    }

    func setAppearance(_ value: String) {
        preferences.appearance = value
    }

    // MARK: - Notifications

    func getNotificationEnabled() -> Bool {
        preferences.isNotificationEnabled
    }

    func setNotificationEnabled(_ enabled: Bool) {
        preferences.isNotificationEnabled = enabled
    }

    func getNotificationAuthorizationStatus() -> UNAuthorizationStatus {
        // Synchronous read is not available; presenter should check async if needed.
        // For section building we cache last known status in preferences.
        return preferences.notificationAuthorizationStatus
    }

    // MARK: - Sound

    func getSoundEnabled() -> Bool {
        preferences.isSoundEnabled
    }

    func setSoundEnabled(_ enabled: Bool) {
        preferences.isSoundEnabled = enabled
    }
}
