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
    func clear()
}

final class KeychainAuthTokenManager: AuthTokenManagerInterface {

    static let shared = KeychainAuthTokenManager()

    private let tokenKey = "com.flashcardapp.accessToken"
    private let userIdKey = "com.flashcardapp.userId"

    private init() {}

    var accessToken: String? {
        load(key: tokenKey)
    }

    var userId: String? {
        load(key: userIdKey)
    }

    func save(accessToken: String, userId: String) throws {
        try save(value: accessToken, key: tokenKey)
        try save(value: userId, key: userIdKey)
    }

    func clear() {
        delete(key: tokenKey)
        delete(key: userIdKey)
    }

    // MARK: - Private

    private func load(key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private func save(value: String, key: String) throws {
        guard let data = value.data(using: .utf8) else {
            throw AppError.authenticationFailed("Cannot encode token to UTF-8")
        }
        // Delete existing item first to avoid duplicate-key errors
        delete(key: key)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw AppError.authenticationFailed("Keychain write failed with status \(status)")
        }
    }

    private func delete(key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(query as CFDictionary)
    }
}