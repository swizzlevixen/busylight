import Foundation
import Security

enum KeychainHelper {

    // MARK: - Test Support

    #if DEBUG
    /// When non-nil, all operations use this in-memory dictionary instead of
    /// the system keychain.  Set to `[:]` in test setUp, `nil` in tearDown.
    nonisolated(unsafe) static var testStore: [String: String]?
    #endif

    // MARK: - Public API

    static func save(key: String, value: String) {
        #if DEBUG
        if testStore != nil {
            if value.isEmpty { testStore?.removeValue(forKey: key) }
            else { testStore?[key] = value }
            return
        }
        #endif

        guard let data = value.data(using: .utf8) else { return }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
        ]

        // Delete existing item first
        SecItemDelete(query as CFDictionary)

        // Don't store empty values
        guard !value.isEmpty else { return }

        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlocked,
        ]

        SecItemAdd(addQuery as CFDictionary, nil)
    }

    static func load(key: String) -> String? {
        #if DEBUG
        if testStore != nil {
            return testStore?[key]
        }
        #endif

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
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

    static func delete(key: String) {
        #if DEBUG
        if testStore != nil {
            testStore?.removeValue(forKey: key)
            return
        }
        #endif

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
        ]

        SecItemDelete(query as CFDictionary)
    }

    static func update(key: String, value: String) {
        #if DEBUG
        if testStore != nil {
            if value.isEmpty { testStore?.removeValue(forKey: key) }
            else { testStore?[key] = value }
            return
        }
        #endif

        guard let data = value.data(using: .utf8) else { return }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
        ]

        let attributes: [String: Any] = [
            kSecValueData as String: data,
        ]

        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)

        if status == errSecItemNotFound {
            save(key: key, value: value)
        }
    }
}
