import Foundation
import Security

// MARK: - KeychainHelper

public final class KeychainHelper: Sendable {
    public static let shared = KeychainHelper()
    private let service = "no.william.mural"

    private init() {}

    // MARK: - Account enum

    public enum Account: String, CaseIterable, Sendable {
        case owner
        case custom
        case openai
        case anthropic
        case google
        case groq
        case deepseek
        case mistral
        case openrouter
        case vps
    }

    // MARK: - Read

    public func read(for account: Account) -> String? {
        var query = brandedQuery(for: account)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    // MARK: - HasKey

    public func hasKey(for account: Account) -> Bool { read(for: account) != nil }

    // MARK: - Save

    public func save(_ key: String, for account: Account) throws {
        let value = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { throw KeychainError.empty }
        let data = Data(value.utf8)
        let query = brandedQuery(for: account)
        let status = SecItemUpdate(query as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        if status == errSecItemNotFound {
            var addQuery = query
            addQuery[kSecValueData as String] = data
            addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
            guard SecItemAdd(addQuery as CFDictionary, nil) == errSecSuccess else { throw KeychainError.save }
        } else if status != errSecSuccess {
            throw KeychainError.save
        }
    }

    // MARK: - Delete

    public func delete(for account: Account) throws {
        let status = SecItemDelete(brandedQuery(for: account) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else { throw KeychainError.delete }
    }

    // MARK: - Migration from Legacy JSON / CredentialStore

    public func migrateLegacyKeys(from rawKeys: [Account: String]) {
        for (account, key) in rawKeys {
            let clean = key.trimmingCharacters(in: .whitespacesAndNewlines)
            if !clean.isEmpty && !hasKey(for: account) {
                try? save(clean, for: account)
            }
        }
    }

    // MARK: - Internal

    private func brandedQuery(for account: Account) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account.rawValue,
            kSecAttrSynchronizable as String: false
        ]
    }
}

// MARK: - Errors

enum KeychainError: LocalizedError {
    case empty
    case save
    case delete
    var errorDescription: String? {
        switch self {
        case .empty: return "La clé ne peut pas être vide."
        case .save: return "Impossible de stocker la clé dans le Keychain."
        case .delete: return "Impossible de supprimer la clé du Keychain."
        }
    }
}
