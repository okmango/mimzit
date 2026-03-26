import Foundation
import Security

/// Minimal Keychain wrapper for secure credential storage.
///
/// Uses the Security framework directly with no external dependencies.
/// All operations are synchronous and thread-safe (Security framework handles this).
///
/// ## Usage
/// ```swift
/// try KeychainService.save(key: "openai_api_key", value: apiKey)
/// let key = KeychainService.load(key: "openai_api_key")
/// KeychainService.delete(key: "openai_api_key")
/// ```
///
/// Adapted from carufus_whozit/Whozit/Services/KeychainService.swift.
/// Only change: service identifier updated from "com.okmango.whozit" to "com.okmango.mimzit".
enum KeychainService {

    private static let service = "com.okmango.mimzit"

    /// Saves a string value to Keychain.
    ///
    /// Uses delete-then-add pattern for simplicity (vs conditional update).
    /// - Parameters:
    ///   - key: The account identifier for the Keychain item
    ///   - value: The string value to store
    /// - Throws: `KeychainError.saveFailed` if the operation fails
    static func save(key: String, value: String) throws {
        let data = Data(value.utf8)

        // Delete existing item first (update pattern)
        delete(key: key)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.saveFailed(status)
        }
    }

    /// Loads a string value from Keychain.
    ///
    /// - Parameter key: The account identifier for the Keychain item
    /// - Returns: The stored string, or nil if not found
    static func load(key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let string = String(data: data, encoding: .utf8) else {
            return nil
        }
        return string
    }

    /// Deletes a Keychain item.
    ///
    /// Silently succeeds if item doesn't exist.
    /// - Parameter key: The account identifier for the Keychain item
    static func delete(key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(query as CFDictionary)
    }
}

enum KeychainError: LocalizedError {
    case saveFailed(OSStatus)

    var errorDescription: String? {
        switch self {
        case .saveFailed(let status):
            return "Keychain save failed with status: \(status)"
        }
    }
}
