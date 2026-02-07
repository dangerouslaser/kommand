//
//  KeychainService.swift
//  Kommand
//
//  Secure password storage using the iOS Security framework.
//  Uses kSecAttrAccessGroup for App Group Keychain sharing
//  between the main app and Live Activity extension.
//

import Foundation
import Security

nonisolated enum KeychainService {
    private static let serviceName = "kommand-kodi-host"
    private static let accessGroup = "group.decent.mid.range.kommand"

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

        guard status == errSecSuccess, let data = result as? Data else {
            return nil
        }

        return String(data: data, encoding: .utf8)
    }

    static func setPassword(_ password: String, for hostId: UUID) {
        guard let data = password.data(using: .utf8) else { return }

        // Delete existing item first (update is more complex and this is simpler)
        deletePassword(for: hostId)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: hostId.uuidString,
            kSecAttrAccessGroup as String: accessGroup,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]

        SecItemAdd(query as CFDictionary, nil)
    }

    static func deletePassword(for hostId: UUID) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: hostId.uuidString,
            kSecAttrAccessGroup as String: accessGroup
        ]

        SecItemDelete(query as CFDictionary)
    }

    // MARK: - Migration

    /// Migrates passwords from UserDefaults to Keychain (one-time operation)
    static func migrateFromUserDefaults(hostIds: [UUID]) {
        let defaults = UserDefaults.standard
        let migrationKey = "keychain_migration_complete"

        guard !defaults.bool(forKey: migrationKey) else { return }

        for hostId in hostIds {
            let key = "password_\(hostId.uuidString)"
            if let password = defaults.string(forKey: key), !password.isEmpty {
                setPassword(password, for: hostId)
                defaults.removeObject(forKey: key)
            }
        }

        defaults.set(true, forKey: migrationKey)
    }
}
