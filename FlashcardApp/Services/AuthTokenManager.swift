//
//  AuthTokenManager.swift
//  FlashcardApp
//
//  Created by Claude on 2026/09/07.
//

import Foundation
import Security

protocol AuthTokenManagerInterface: AnyObject {
    var accessToken: String? { get }
    var userId: String? { get }
    func save(accessToken: String, userId: String) throws
    func clear() throws
}

final class KeychainAuthTokenManager: AuthTokenManagerInterface {

    static let shared = KeychainAuthTokenManager()

    /// Token and user id live in one Keychain item so a crash or failed write can never pair one account's
    /// token with another account's id.
    private struct StoredSession: Codable {
        let accessToken: String
        let userId: String
    }

    private let sessionKey: String
    // Two separate items held the session before the single-item format; still read, replaced on the next save.
    private let legacyTokenKey: String
    private let legacyUserIdKey: String

    init(namespace: String = "com.flashcardapp") {
        sessionKey = "\(namespace).session"
        legacyTokenKey = "\(namespace).accessToken"
        legacyUserIdKey = "\(namespace).userId"
    }

    var accessToken: String? { storedSession?.accessToken }

    var userId: String? { storedSession?.userId }

    func save(accessToken: String, userId: String) throws {
        let data = try JSONEncoder().encode(StoredSession(accessToken: accessToken, userId: userId))
        let query = itemQuery(key: sessionKey)
        // Replace in place: the previous session stays intact if the write fails.
        var status = SecItemUpdate(query as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        if status == errSecItemNotFound {
            let attributes = query.merging([
                kSecValueData as String: data,
                kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            ]) { $1 }
            status = SecItemAdd(attributes as CFDictionary, nil)
        }
        guard status == errSecSuccess else {
            throw AppError.authenticationFailed("Keychain write failed with status \(status)")
        }
        delete(key: legacyTokenKey)
        delete(key: legacyUserIdKey)
    }

    func clear() throws {
        let statuses = [delete(key: sessionKey), delete(key: legacyTokenKey), delete(key: legacyUserIdKey)]
        guard statuses.allSatisfy({ $0 == errSecSuccess || $0 == errSecItemNotFound }) else {
            throw NativeAuthError.storageFailed
        }
    }

    // MARK: - Private

    private var storedSession: StoredSession? {
        if let data = load(key: sessionKey),
           let session = try? JSONDecoder().decode(StoredSession.self, from: data) {
            return session
        }
        guard let token = load(key: legacyTokenKey).flatMap({ String(data: $0, encoding: .utf8) }),
              let userId = load(key: legacyUserIdKey).flatMap({ String(data: $0, encoding: .utf8) }) else { return nil }
        return StoredSession(accessToken: token, userId: userId)
    }

    private func itemQuery(key: String) -> [String: Any] {
        [kSecClass as String: kSecClassGenericPassword, kSecAttrAccount as String: key]
    }

    private func load(key: String) -> Data? {
        let query = itemQuery(key: key).merging([
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]) { $1 }
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess else { return nil }
        return result as? Data
    }

    @discardableResult
    private func delete(key: String) -> OSStatus {
        SecItemDelete(itemQuery(key: key) as CFDictionary)
    }
}
