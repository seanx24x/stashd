//
//  DataEncryptionService.swift
//  stashd
//
//  Created by Sean Lynch on 10/15/25.
//


//
//  DataEncryptionService.swift
//  stashd
//
//  Created by Sean Lynch
//

import Foundation
import CryptoKit

final class DataEncryptionService {
    static let shared = DataEncryptionService()
    
    private init() {}
    
    // MARK: - Encryption Key Management
    
    /// Get or create encryption key (stored in Keychain)
    private func getEncryptionKey() throws -> SymmetricKey {
        let keyIdentifier = "com.stashd.encryptionKey"
        
        // Try to load existing key
        if let existingKey = try? KeychainService.shared.load(for: keyIdentifier) {
            return SymmetricKey(data: existingKey)
        }
        
        // Create new key
        let newKey = SymmetricKey(size: .bits256)
        let keyData = newKey.withUnsafeBytes { Data($0) }
        
        // Store in Keychain
        try KeychainService.shared.save(keyData, for: keyIdentifier)
        
        ErrorLoggingService.shared.logInfo(
            "Created new encryption key",
            context: "Data Encryption"
        )
        
        return newKey
    }
    
    // MARK: - Encryption
    
    /// Encrypt string data
    func encrypt(_ string: String) throws -> String {
        guard !string.isEmpty else {
            return string
        }
        
        let key = try getEncryptionKey()
        let data = Data(string.utf8)
        
        let sealedBox = try AES.GCM.seal(data, using: key)
        
        guard let combined = sealedBox.combined else {
            throw EncryptionError.encryptionFailed
        }
        
        // Return as base64 string
        return combined.base64EncodedString()
    }
    
    /// Encrypt optional string data
    func encrypt(_ string: String?) throws -> String? {
        guard let string = string else {
            return nil
        }
        return try encrypt(string)
    }
    
    /// Encrypt data
    func encrypt(_ data: Data) throws -> Data {
        let key = try getEncryptionKey()
        let sealedBox = try AES.GCM.seal(data, using: key)
        
        guard let combined = sealedBox.combined else {
            throw EncryptionError.encryptionFailed
        }
        
        return combined
    }
    
    // MARK: - Decryption
    
    /// Decrypt string data
    func decrypt(_ encryptedString: String) throws -> String {
        guard !encryptedString.isEmpty else {
            return encryptedString
        }
        
        let key = try getEncryptionKey()
        
        guard let data = Data(base64Encoded: encryptedString) else {
            throw EncryptionError.invalidData
        }
        
        let sealedBox = try AES.GCM.SealedBox(combined: data)
        let decryptedData = try AES.GCM.open(sealedBox, using: key)
        
        guard let string = String(data: decryptedData, encoding: .utf8) else {
            throw EncryptionError.invalidData
        }
        
        return string
    }
    
    /// Decrypt optional string data
    func decrypt(_ encryptedString: String?) throws -> String? {
        guard let encryptedString = encryptedString else {
            return nil
        }
        return try decrypt(encryptedString)
    }
    
    /// Decrypt data
    func decrypt(_ encryptedData: Data) throws -> Data {
        let key = try getEncryptionKey()
        let sealedBox = try AES.GCM.SealedBox(combined: encryptedData)
        return try AES.GCM.open(sealedBox, using: key)
    }
    
    // MARK: - Convenience Methods
    
    /// Check if string appears to be encrypted (base64 format)
    func isEncrypted(_ string: String) -> Bool {
        // Check if it's valid base64 and reasonable length for encrypted data
        guard let data = Data(base64Encoded: string),
              data.count >= 28 else { // AES-GCM minimum size
            return false
        }
        return true
    }
    
    /// Encrypt Decimal values
    func encrypt(_ decimal: Decimal) throws -> String {
        let string = "\(decimal)"
        return try encrypt(string)
    }
    
    /// Decrypt to Decimal
    func decryptToDecimal(_ encryptedString: String) throws -> Decimal {
        let string = try decrypt(encryptedString)
        guard let decimal = Decimal(string: string) else {
            throw EncryptionError.invalidData
        }
        return decimal
    }
}

// MARK: - Errors

enum DataEncryptionError: LocalizedError {  // ✅ Changed from EncryptionError
    case encryptionFailed
    case decryptionFailed
    case invalidData
    case keyNotFound
    
    var errorDescription: String? {
        switch self {
        case .encryptionFailed:
            return "Failed to encrypt data"
        case .decryptionFailed:
            return "Failed to decrypt data"
        case .invalidData:
            return "Invalid data format"
        case .keyNotFound:
            return "Encryption key not found"
        }
    }
}

// MARK: - Secure String Property Wrapper

/// Property wrapper for automatic encryption/decryption
@propertyWrapper
struct Encrypted {
    private var encryptedValue: String?
    
    var wrappedValue: String? {
        get {
            guard let encrypted = encryptedValue else {
                return nil
            }
            return try? DataEncryptionService.shared.decrypt(encrypted)
        }
        set {
            encryptedValue = try? DataEncryptionService.shared.encrypt(newValue)
        }
    }
    
    init(wrappedValue: String?) {
        self.encryptedValue = try? DataEncryptionService.shared.encrypt(wrappedValue)
    }
}
