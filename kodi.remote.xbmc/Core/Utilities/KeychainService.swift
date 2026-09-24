//
//  KeychainService.swift
//  Kommand
//
//  Secure password storage using the iOS Security framework.
//  Uses kSecAttrAccessGroup for App Group Keychain sharing
//  between the main app and Live Activity extension.
//

import Foundation
import os
import Security

nonisolated enum KeychainService {
    private static let serviceName = "kommand-kodi-host"
    private static let accessGroup = "group.decent.mid.range.kommand"
    private static let log = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "kommand",
        category: "keychain"
    )

    // MARK: - Public API

    static func getPassword(for hostId: UUID) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: hostId.uuidString,
            kSecAttrAccessGroup as String: accessGroup,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        if status == errSecSuccess, let data = result as? Data {
            return String(data: data, encoding: .utf8)
        }

        // errSecItemNotFound is the normal "no password configured" case — don't log it.
        // Anything else (permission denied, interaction not allowed, corrupt entry) is
        // a real problem that masquerades as "wrong password" at the auth layer.
        if status != errSecItemNotFound {
            log.error("getPassword failed with OSStatus \(status) for host \(hostId.uuidString, privacy: .public)")
        }
        return nil
    }

    /// Stores a password without deleting an existing value first.
    ///
    /// Returning the operation result lets migration retain its legacy copy when
    /// Keychain is temporarily unavailable or the app is mis-entitled.
    @discardableResult
    static func setPassword(_ password: String, for hostId: UUID) -> Bool {
        guard let data = password.data(using: .utf8) else { return false }

        let itemQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: hostId.uuidString,
            kSecAttrAccessGroup as String: accessGroup
        ]

        let updateAttributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]

        var status = SecItemUpdate(
            itemQuery as CFDictionary,
            updateAttributes as CFDictionary
        )

        if status == errSecItemNotFound {
            var newItem = itemQuery
            updateAttributes.forEach { newItem[$0.key] = $0.value }
            status = SecItemAdd(newItem as CFDictionary, nil)
        }

        if status != errSecSuccess {
            log.error("setPassword failed with OSStatus \(status) for host \(hostId.uuidString, privacy: .public)")
            return false
        }

        return true
    }

    static func deletePassword(for hostId: UUID) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: hostId.uuidString,
            kSecAttrAccessGroup as String: accessGroup
        ]

        let status = SecItemDelete(query as CFDictionary)
        // errSecItemNotFound on delete is normal (e.g. host had no saved password).
        if status != errSecSuccess && status != errSecItemNotFound {
            log.error("deletePassword failed with OSStatus \(status) for host \(hostId.uuidString, privacy: .public)")
        }
    }

    // MARK: - Migration

    /// Migrates passwords from UserDefaults to Keychain (one-time operation)
    static func migrateFromUserDefaults(hostIds: [UUID]) {
        let defaults = UserDefaults.standard
        let migrationKey = "keychain_migration_complete"

        guard !defaults.bool(forKey: migrationKey) else { return }

        var migrationSucceeded = true

        for hostId in hostIds {
            let key = "password_\(hostId.uuidString)"
            if let password = defaults.string(forKey: key), !password.isEmpty {
                if setPassword(password, for: hostId) {
                    defaults.removeObject(forKey: key)
                } else {
                    migrationSucceeded = false
                }
            }
        }

        if migrationSucceeded {
            defaults.set(true, forKey: migrationKey)
        }
    }
}
