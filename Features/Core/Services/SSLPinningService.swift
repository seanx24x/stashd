//
//  SSLPinningService.swift
//  stashd
//
//  Created by Sean Lynch
//

import Foundation
import CryptoKit

final class SSLPinningService: NSObject {
    static let shared = SSLPinningService()
    
    private override init() {}
    
    // MARK: - Certificate Pinning Configuration
    
    /// Pinned certificate hashes (SHA-256 in Base64) for your domains
    private let pinnedCertificates: [String: Set<String>] = [
        // OpenAI API - Base64 encoded SHA-256 of public key
        "api.openai.com": [
            "UsIYNqs3xXZTDzui2XKnR/f9keoCoDrNak4Q0z/vQiQ="
        ],
        
        // Firebase Storage
        "firebasestorage.googleapis.com": [
            "542e59dvLJQqY9DZzWfn5YcvquPJBrH9v6OpWMe0ACg="
        ],
        
        // Firestore
        "firestore.googleapis.com": [
            "+4WwZpRnPmgUxgBPPxd6sP1t2bfrbjJxzayQGnyVi+A="
        ],
    ]
    
    // MARK: - Certificate Validation
    
    /// Validate server trust with certificate pinning
    func validateServerTrust(
        _ serverTrust: SecTrust,
        forHost host: String
    ) -> Bool {
        // Get pinned certificates for this host
        guard let pinnedHashes = pinnedCertificates[host] else {
            // No pinning configured for this host - allow connection
            ErrorLoggingService.shared.logInfo(
                "No SSL pinning configured for host: \(host) - allowing connection",
                context: "SSL Pinning"
            )
            return true
        }
        
        // Extract public keys from server trust and compare
        guard let serverPublicKey = getPublicKey(from: serverTrust) else {
            ErrorLoggingService.shared.logInfo(
                "Failed to extract public key from server trust for \(host)",
                context: "SSL Pinning"
            )
            
            // ✅ NEW: Log security event
            SecurityMonitoringService.shared.logEvent(
                .sslPinningFailed,
                details: ["host": host, "reason": "no_public_key"]
            )
            return false
        }
        
        // Get hash of server's public key
        let serverKeyHash = sha256Base64(publicKey: serverPublicKey)
        
        // Check if server's key matches any pinned keys
        if pinnedHashes.contains(serverKeyHash) {
            ErrorLoggingService.shared.logInfo(
                "SSL certificate validated for \(host)",
                context: "SSL Pinning"
            )
            
            // ✅ NEW: Log security event
            SecurityMonitoringService.shared.logEvent(
                .sslPinningSuccess,
                details: ["host": host]
            )
            return true
        }
        
        // No match found
        ErrorLoggingService.shared.logInfo(
            "SSL pinning validation failed for \(host)",
            context: "SSL Pinning"
        )
        
        // ✅ NEW: Log security event
        SecurityMonitoringService.shared.logEvent(
            .sslPinningFailed,
            details: [
                "host": host,
                "reason": "hash_mismatch",
                "expected": Array(pinnedHashes).joined(separator: ", "),
                "got": serverKeyHash
            ]
        )
        
        return false
    }
    
    // MARK: - Helper Methods
    
    /// Extract public key from server trust
    private func getPublicKey(from serverTrust: SecTrust) -> SecKey? {
        // Get the certificate from the trust
        guard let certificate = SecTrustCopyCertificateChain(serverTrust) as? [SecCertificate],
              let firstCert = certificate.first else {
            return nil
        }
        
        // Extract public key from certificate
        return SecCertificateCopyKey(firstCert)
    }
    
    /// Calculate SHA-256 hash of public key in Base64 format
    private func sha256Base64(publicKey: SecKey) -> String {
        var error: Unmanaged<CFError>?
        guard let publicKeyData = SecKeyCopyExternalRepresentation(publicKey, &error) as Data? else {
            return ""
        }
        
        let hash = SHA256.hash(data: publicKeyData)
        let hashData = Data(hash)
        return hashData.base64EncodedString()
    }
}

// MARK: - URL Session Delegate for SSL Pinning

class SSLPinningDelegate: NSObject, URLSessionDelegate {
    
    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        // Only handle server trust authentication
        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
              let serverTrust = challenge.protectionSpace.serverTrust,
              let host = challenge.protectionSpace.host as String? else {
            completionHandler(.performDefaultHandling, nil)
            return
        }
        
        // Validate certificate
        if SSLPinningService.shared.validateServerTrust(serverTrust, forHost: host) {
            // Certificate is valid - allow connection
            let credential = URLCredential(trust: serverTrust)
            completionHandler(.useCredential, credential)
        } else {
            // Certificate validation failed - reject connection
            ErrorLoggingService.shared.logInfo(
                "SSL pinning failed for \(host) - connection rejected",
                context: "SSL Pinning"
            )
            completionHandler(.cancelAuthenticationChallenge, nil)
        }
    }
}

enum SSLPinningError: LocalizedError {
    case invalidURL
    case noServerTrust
    case certificateNotFound
    case validationFailed
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL provided"
        case .noServerTrust:
            return "No server trust available"
        case .certificateNotFound:
            return "Certificate not found"
        case .validationFailed:
            return "Certificate validation failed"
        }
    }
}
