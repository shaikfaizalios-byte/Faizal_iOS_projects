import Foundation
import Security

/// Tokens and other secrets go in the Keychain, never UserDefaults — a plist
/// is readable from a device backup.
///
/// `kSecAttrAccessibleWhenUnlockedThisDeviceOnly` means the item is available
/// only while the device is unlocked and is *not* carried into an encrypted
/// backup or migrated to a new device. For a payment credential that is the
/// correct trade-off: losing the token on restore is better than the token
/// travelling somewhere you cannot see.
struct KeychainStore: SecureStore {
    enum KeychainError: Error, Equatable {
        case unexpectedStatus(OSStatus)
    }

    private let service: String

    init(service: String = "com.faizal.miniwallet") {
        self.service = service
    }

    func save(_ data: Data, for key: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]

        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]

        let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if updateStatus == errSecItemNotFound {
            let insertStatus = SecItemAdd(query.merging(attributes) { $1 } as CFDictionary, nil)
            guard insertStatus == errSecSuccess else {
                throw KeychainError.unexpectedStatus(insertStatus)
            }
            return
        }
        guard updateStatus == errSecSuccess else {
            throw KeychainError.unexpectedStatus(updateStatus)
        }
    }

    func read(key: String) throws -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        switch status {
        case errSecSuccess:
            return item as? Data
        case errSecItemNotFound:
            return nil
        default:
            throw KeychainError.unexpectedStatus(status)
        }
    }

    func delete(key: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unexpectedStatus(status)
        }
    }
}
