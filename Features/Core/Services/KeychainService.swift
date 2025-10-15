//
//  KeychainService.swift
//  stashd
//
//  Created by Sean Lynch
//

// File: Core/Services/KeychainService.swift

import Foundation
import Security

enum KeychainError: LocalizedError {
    case saveFailed(OSStatus)
    case loadFailed(OSStatus)
    case deleteFailed(OSStatus)
    case notFound
    case invalidData
    
    var errorDescription: String? {
        switch self {
        case .saveFailed(let status):
            return "Failed to save to Keychain (status: \(status))"
        case .loadFailed(let status):
            return "Failed to load from Keychain (status: \(status))"
        case .deleteFailed(let status):
            return "Failed to delete from Keychain (status: \(status))"
        case .notFound:
            return "Item not found in Keychain"
        case .invalidData:
            return "Invalid data format"
        }
    }
}

final class KeychainService {
    static let shared = KeychainService()
    
    private init() {}
    
    // MARK: - Save Data
    
    func save(_ data: Data, for key: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]
        
        // Delete any existing item first
        SecItemDelete(query as CFDictionary)
        
        // Add new item
        let status = SecItemAdd(query as CFDictionary, nil)
        
        guard status == errSecSuccess else {
            // ✅ NEW: Log errors
            ErrorLoggingService.shared.logError(
                KeychainError.saveFailed(status),
                context: "Keychain save",
                additionalInfo: ["key": key, "status": "\(status)"]
            )
            throw KeychainError.saveFailed(status)
        }
        
        // ✅ NEW: Log success
        ErrorLoggingService.shared.logInfo(
            "Saved value to Keychain",
            context: "Keychain"
        )
    }
    
    // ✅ NEW: Convenience method for saving strings
    func save(_ value: String, for key: String) throws {
        guard let data = value.data(using: .utf8) else {
            throw KeychainError.invalidData
        }
        try save(data, for: key)
    }
    
    // MARK: - Load Data
    
    func load(for key: String) throws -> Data {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess else {
            if status == errSecItemNotFound {
                throw KeychainError.notFound
            }
            // ✅ NEW: Log errors
            ErrorLoggingService.shared.logError(
                KeychainError.loadFailed(status),
                context: "Keychain load",
                additionalInfo: ["key": key, "status": "\(status)"]
            )
            throw KeychainError.loadFailed(status)
        }
        
        guard let data = result as? Data else {
            throw KeychainError.invalidData
        }
        
        return data
    }
    
    // ✅ NEW: Convenience method for loading strings
    func loadString(for key: String) throws -> String {
        let data = try load(for: key)
        guard let string = String(data: data, encoding: .utf8) else {
            throw KeychainError.invalidData
        }
        return string
    }
    
    // MARK: - Delete Data
    
    func delete(for key: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        
        guard status == errSecSuccess || status == errSecItemNotFound else {
            // ✅ NEW: Log errors
            ErrorLoggingService.shared.logError(
                KeychainError.deleteFailed(status),
                context: "Keychain delete",
                additionalInfo: ["key": key, "status": "\(status)"]
            )
            throw KeychainError.deleteFailed(status)
        }
        
        // ✅ NEW: Log success
        ErrorLoggingService.shared.logInfo(
            "Deleted value from Keychain",
            context: "Keychain"
        )
    }
    
    // MARK: - Check Existence
    
    func exists(for key: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: false
        ]
        
        let status = SecItemCopyMatching(query as CFDictionary, nil)
        return status == errSecSuccess
    }
    
    // MARK: - Clear All
    
    func clearAll() throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        
        guard status == errSecSuccess || status == errSecItemNotFound else {
            // ✅ NEW: Log errors
            ErrorLoggingService.shared.logError(
                KeychainError.deleteFailed(status),
                context: "Keychain clear all"
            )
            throw KeychainError.deleteFailed(status)
        }
        
        // ✅ NEW: Log success
        ErrorLoggingService.shared.logInfo(
            "Cleared all Keychain values",
            context: "Keychain"
        )
    }
}

// ✅ NEW: Predefined Keys
extension KeychainService {
    enum Key {
        static let firebaseUserID = "com.stashd.firebaseUserID"
        static let firebaseIDToken = "com.stashd.firebaseIDToken"
        static let firebaseRefreshToken = "com.stashd.firebaseRefreshToken"
        static let lastAuthDate = "com.stashd.lastAuthDate"
    }
}
