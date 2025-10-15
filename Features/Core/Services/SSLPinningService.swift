//
//  SSLPinningService.swift
//  stashd
//
//  Created by Sean Lynch on 10/15/25.
//


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
    
    /// Pinned certificate hashes (SHA-256) for your domains
    /// These should be updated when certificates are renewed
    private let pinnedCertificates: [String: Set<String>] = [
        // OpenAI API
        "api.openai.com": [
            // Add OpenAI's certificate hash here
            // You'll get this by fetching the certificate
            "LExv0hWBuW1l0adcaSGOiLj5Xh0FRUmbVxfMWWQXbc0="
        ],
        
        // Firebase
        "firebasestorage.googleapis.com": [
            "542e59dvLJQqY9DZzWfn5YcvquPJBrH9v6OpWMe0ACg="
        ],
        "firestore.googleapis.com": [
            "+4WwZpRnPmgUxgBPPxd6sP1t2bfrbjJxzayQGnyVi+A="
        ],
        
        // Add your other API domains here
    ]
    
    // MARK: - Certificate Validation
    
    /// Validate server trust with certificate pinning
    func validateServerTrust(
        _ serverTrust: SecTrust,
        forHost host: String
    ) -> Bool {
        // Get pinned certificates for this host
        guard let pinnedHashes = pinnedCertificates[host] else {
            // No pinning configured for this host
            ErrorLoggingService.shared.logInfo(
                "No SSL pinning configured for host: \(host)",
                context: "SSL Pinning"
            )
            // Allow connection (but log it)
            return true
        }
        
        // Get certificate chain from server
        guard let certificates = getCertificates(from: serverTrust) else {
            ErrorLoggingService.shared.logInfo(
                "Failed to get certificates from server trust",
                context: "SSL Pinning"
            )
            return false
        }
        
        // Check if any certificate in the chain matches our pinned hashes
        for certificate in certificates {
            let hash = sha256(certificate: certificate)
            if pinnedHashes.contains(hash) {
                ErrorLoggingService.shared.logInfo(
                    "SSL certificate validated for \(host)",
                    context: "SSL Pinning"
                )
                return true
            }
        }
        
        // No matching certificate found
        ErrorLoggingService.shared.logInfo(
            "SSL pinning validation failed for \(host)",
            context: "SSL Pinning"
        )
        
        return false
    }
    
    // MARK: - Helper Methods
    
    /// Extract certificates from server trust
    private func getCertificates(from serverTrust: SecTrust) -> [SecCertificate]? {
        var certificates: [SecCertificate] = []
        
        // Get certificate count
        let certificateCount = SecTrustGetCertificateCount(serverTrust)
        
        // Extract each certificate
        for index in 0..<certificateCount {
            if let certificate = SecTrustGetCertificateAtIndex(serverTrust, index) {
                certificates.append(certificate)
            }
        }
        
        return certificates.isEmpty ? nil : certificates
    }
    
    /// Calculate SHA-256 hash of certificate
    private func sha256(certificate: SecCertificate) -> String {
        let data = SecCertificateCopyData(certificate) as Data
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
    
    // MARK: - Public Key Pinning (Alternative Method)
    
    /// Validate server trust using public key pinning
    func validateServerTrustWithPublicKey(
        _ serverTrust: SecTrust,
        forHost host: String
    ) -> Bool {
        // Get certificates
        guard let certificates = getCertificates(from: serverTrust) else {
            return false
        }
        
        // Extract public keys and validate
        for certificate in certificates {
            if let publicKey = getPublicKey(from: certificate) {
                let publicKeyHash = sha256(publicKey: publicKey)
                
                // Check against pinned public key hashes
                if let pinnedHashes = pinnedCertificates[host],
                   pinnedHashes.contains(publicKeyHash) {
                    return true
                }
            }
        }
        
        return false
    }
    
    /// Extract public key from certificate
    private func getPublicKey(from certificate: SecCertificate) -> SecKey? {
        var publicKey: SecKey?
        
        let policy = SecPolicyCreateBasicX509()
        var trust: SecTrust?
        
        let status = SecTrustCreateWithCertificates(
            certificate,
            policy,
            &trust
        )
        
        if status == errSecSuccess, let trust = trust {
            publicKey = SecTrustCopyKey(trust)
        }
        
        return publicKey
    }
    
    /// Calculate SHA-256 hash of public key
    private func sha256(publicKey: SecKey) -> String {
        var error: Unmanaged<CFError>?
        guard let publicKeyData = SecKeyCopyExternalRepresentation(publicKey, &error) as Data? else {
            return ""
        }
        
        let hash = SHA256.hash(data: publicKeyData)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
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

// MARK: - Certificate Hash Generator (Helper)

extension SSLPinningService {
    /// Generate certificate hash for a URL (use this during development)
    func getCertificateHash(for urlString: String) async throws -> String {
        guard let url = URL(string: urlString) else {
            throw SSLPinningError.invalidURL
        }
        
        let session = URLSession(configuration: .default)
        let (_, response) = try await session.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse,
              let serverTrust = httpResponse.value(forHTTPHeaderField: "Server-Trust") else {
            throw SSLPinningError.noServerTrust
        }
        
        // This is a simplified version - you'd need to extract the actual certificate
        return "CERTIFICATE_HASH"
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
