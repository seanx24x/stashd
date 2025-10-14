//
//  EncryptionError.swift
//  stashd
//
//  Created by Sean Lynch on 10/14/25.
//


//
//  EncryptionService.swift
//  stashd
//
//  Created by Sean Lynch
//

// File: Core/Services/EncryptionService.swift

import Foundation
import CryptoKit

enum EncryptionError: LocalizedError {
    case encryptionFailed
    case decryptionFailed
    case invalidData
    case keyGenerationFailed
    
    var errorDescription: String? {
        switch self {
        case .encryptionFailed:
            return "Failed to encrypt data"
        case .decryptionFailed:
            return "Failed to decrypt data"
        case .invalidData:
            return "Invalid data format"
        case .keyGenerationFailed:
            return "Failed to generate encryption key"
        }
    }
}

final class EncryptionService {
    static let shared = EncryptionService()
    
    private let keychain = KeychainService.shared
    private let encryptionKeyIdentifier = "app.stashd.encryption.key"
    
    private init() {}
    
    // MARK: - Get or Create Encryption Key
    
    private func getEncryptionKey() throws -> SymmetricKey {
        // Try to load existing key from Keychain
        if let keyData = try? keychain.load(for: encryptionKeyIdentifier) {
            return SymmetricKey(data: keyData)
        }
        
        // Generate new key if none exists
        let newKey = SymmetricKey(size: .bits256)
        let keyData = newKey.withUnsafeBytes { Data($0) }
        
        do {
            try keychain.save(keyData, for: encryptionKeyIdentifier)
            print("🔑 Generated new encryption key")
            return newKey
        } catch {
            throw EncryptionError.keyGenerationFailed
        }
    }
    
    // MARK: - Encrypt String
    
    func encrypt(_ string: String) throws -> Data {
        guard let data = string.data(using: .utf8) else {
            throw EncryptionError.invalidData
        }
        
        return try encrypt(data)
    }
    
    // MARK: - Encrypt Data
    
    func encrypt(_ data: Data) throws -> Data {
        let key = try getEncryptionKey()
        
        do {
            let sealedBox = try AES.GCM.seal(data, using: key)
            
            guard let combined = sealedBox.combined else {
                throw EncryptionError.encryptionFailed
            }
            
            return combined
        } catch {
            throw EncryptionError.encryptionFailed
        }
    }
    
    // MARK: - Decrypt to String
    
    func decryptToString(_ data: Data) throws -> String {
        let decryptedData = try decrypt(data)
        
        guard let string = String(data: decryptedData, encoding: .utf8) else {
            throw EncryptionError.invalidData
        }
        
        return string
    }
    
    // MARK: - Decrypt Data
    
    func decrypt(_ data: Data) throws -> Data {
        let key = try getEncryptionKey()
        
        do {
            let sealedBox = try AES.GCM.SealedBox(combined: data)
            let decryptedData = try AES.GCM.open(sealedBox, using: key)
            return decryptedData
        } catch {
            throw EncryptionError.decryptionFailed
        }
    }
    
    // MARK: - Encrypt Decimal (for currency values)
    
    func encryptDecimal(_ decimal: Decimal) throws -> Data {
        let string = NSDecimalNumber(decimal: decimal).stringValue
        return try encrypt(string)
    }
    
    // MARK: - Decrypt to Decimal
    
    func decryptToDecimal(_ data: Data) throws -> Decimal {
        let string = try decryptToString(data)
        
        guard let decimal = Decimal(string: string) else {
            throw EncryptionError.invalidData
        }
        
        return decimal
    }
    
    // MARK: - Rotate Encryption Key (for advanced use)
    
    func rotateEncryptionKey() throws {
        // Delete old key
        try? keychain.delete(for: encryptionKeyIdentifier)
        
        // Generate new key
        _ = try getEncryptionKey()
        
        print("🔄 Encryption key rotated")
    }
}
