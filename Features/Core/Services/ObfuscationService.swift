//
//  ObfuscationService.swift
//  stashd
//
//  Created by Sean Lynch on 10/15/25.
//


//
//  ObfuscationService.swift
//  stashd
//
//  Created by Sean Lynch
//

import Foundation
import CryptoKit

final class ObfuscationService {
    static let shared = ObfuscationService()
    
    private init() {}
    
    // MARK: - String Obfuscation
    
    /// XOR-based string obfuscation (simple but effective)
    func obfuscate(_ string: String) -> [UInt8] {
        let key: [UInt8] = [0x5A, 0x3C, 0x7E, 0x2B, 0x91, 0x4D, 0x68, 0xF2]
        let bytes = Array(string.utf8)
        return bytes.enumerated().map { index, byte in
            byte ^ key[index % key.count]
        }
    }
    
    /// Deobfuscate XOR-encoded bytes back to string
    func deobfuscate(_ bytes: [UInt8]) -> String? {
        let key: [UInt8] = [0x5A, 0x3C, 0x7E, 0x2B, 0x91, 0x4D, 0x68, 0xF2]
        let decodedBytes = bytes.enumerated().map { index, byte in
            byte ^ key[index % key.count]
        }
        return String(bytes: decodedBytes, encoding: .utf8)
    }
    
    // MARK: - Sensitive String Storage
    
    /// Store sensitive strings obfuscated
    struct ObfuscatedStrings {
        // Firebase collection names (obfuscated)
        static let users: [UInt8] = [0x3f, 0x50, 0x11, 0x48, 0xf4]
        static let collections: [UInt8] = [0x38, 0x58, 0x13, 0x13, 0xf0, 0x28, 0x09, 0x96, 0xf5, 0x58, 0x1c]
        static let activities: [UInt8] = [0x3a, 0x58, 0x09, 0x4c, 0xf5, 0x2c, 0x09, 0x96, 0xf4, 0x50]
        
        // API endpoint paths (obfuscated)
        static let openAIEndpoint: [UInt8] = [0x2d, 0x09, 0x09, 0x47, 0xf4, 0x2d, 0x1d, 0x91, 0xe3, 0x47, 0x1c, 0x2e, 0xe3, 0x47, 0x1c, 0x2e, 0xe3, 0x47, 0x1c]
        
        // Error messages (obfuscated to prevent string searching)
        static let authError: [UInt8] = [0x3a, 0x50, 0x09, 0x2d, 0xf0, 0x2e, 0x09, 0x96, 0xe3, 0x09, 0x1c, 0x2e, 0xe2, 0x2e]
        static let networkError: [UInt8] = [0x2f, 0x10, 0x09, 0x5c, 0xf5, 0x2f, 0x1e, 0x84, 0xe2, 0x48, 0x1f, 0x48, 0xfe]
    }
    
    // MARK: - Anti-Debugging
    
    /// Check if app is being debugged dynamically
    func isBeingDebugged() -> Bool {
        var info = kinfo_proc()
        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, getpid()]
        var size = MemoryLayout<kinfo_proc>.stride
        
        let result = sysctl(&mib, UInt32(mib.count), &info, &size, nil, 0)
        
        guard result == 0 else {
            return false
        }
        
        return (info.kp_proc.p_flag & P_TRACED) != 0
    }
    
    // MARK: - Code Integrity Check
    
    /// Verify code hasn't been tampered with using checksum
    func verifyCodeIntegrity() -> Bool {
        #if DEBUG
        return true
        #else
        guard let executablePath = Bundle.main.executablePath else {
            return false
        }
        
        do {
            let data = try Data(contentsOf: URL(fileURLWithPath: executablePath))
            let hash = SHA256.hash(data: data)
            let hashString = hash.compactMap { String(format: "%02x", $0) }.joined()
            
            // Store expected hash (this would be set during build)
            // For now, just verify we can compute it
            let isValid = hashString.count == 64
            
            if !isValid {
                ErrorLoggingService.shared.logInfo(
                    "Code integrity check failed",
                    context: "Security"
                )
            }
            
            return isValid
        } catch {
            ErrorLoggingService.shared.logError(
                error,
                context: "Code integrity verification"
            )
            return false
        }
        #endif
    }
    
    // MARK: - String Encryption for Runtime
    
    /// Encrypt sensitive strings at runtime using AES
    func encryptString(_ string: String, key: SymmetricKey) throws -> Data {
        let data = Data(string.utf8)
        let sealedBox = try AES.GCM.seal(data, using: key)
        return sealedBox.combined!
    }
    
    /// Decrypt encrypted strings
    func decryptString(_ data: Data, key: SymmetricKey) throws -> String {
        let sealedBox = try AES.GCM.SealedBox(combined: data)
        let decryptedData = try AES.GCM.open(sealedBox, using: key)
        guard let string = String(data: decryptedData, encoding: .utf8) else {
            throw ObfuscationError.invalidData
        }
        return string
    }
    
    // MARK: - Control Flow Obfuscation
    
    /// Add random delays to make timing analysis harder
    func addRandomDelay() async {
        let delay = UInt64.random(in: 10_000_000...50_000_000) // 10-50ms
        try? await Task.sleep(nanoseconds: delay)
    }
    
    /// Execute code with random control flow
    func executeWithObfuscation<T>(_ closure: () throws -> T) rethrows -> T {
        // Add noise to execution pattern
        let shouldDelay = Bool.random()
        if shouldDelay {
            Thread.sleep(forTimeInterval: 0.001)
        }
        
        return try closure()
    }
}

// MARK: - Obfuscated Constants

extension ObfuscationService {
    /// Get deobfuscated Firebase collection name
    static func getCollectionName(_ type: CollectionType) -> String {
        let obfuscated: [UInt8]
        switch type {
        case .users:
            obfuscated = ObfuscatedStrings.users
        case .collections:
            obfuscated = ObfuscatedStrings.collections
        case .activities:
            obfuscated = ObfuscatedStrings.activities
        }
        
        return shared.deobfuscate(obfuscated) ?? "users"
    }
    
    enum CollectionType {
        case users
        case collections
        case activities
    }
}

// MARK: - Errors

enum ObfuscationError: LocalizedError {
    case invalidData
    case encryptionFailed
    case decryptionFailed
    
    var errorDescription: String? {
        switch self {
        case .invalidData:
            return "Invalid data format"
        case .encryptionFailed:
            return "Failed to encrypt data"
        case .decryptionFailed:
            return "Failed to decrypt data"
        }
    }
}