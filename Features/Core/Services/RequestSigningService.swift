//
//  RequestSigningService.swift
//  stashd
//
//  Created by Sean Lynch on 10/15/25.
//


//
//  RequestSigningService.swift
//  stashd
//
//  Created by Sean Lynch
//

import Foundation
import CryptoKit

final class RequestSigningService {
    static let shared = RequestSigningService()
    
    private init() {}
    
    // MARK: - Request Signing
    
    /// Sign a network request with HMAC-SHA256
    func signRequest(
        _ request: inout URLRequest,
        withSecret secret: String
    ) throws {
        // Get request body
        let bodyData = request.httpBody ?? Data()
        
        // Get timestamp
        let timestamp = String(Int(Date().timeIntervalSince1970))
        
        // Get request method and path
        guard let url = request.url,
              let method = request.httpMethod else {
            throw RequestSigningError.invalidRequest
        }
        
        let path = url.path
        
        // Create signature base string
        let signatureBase = "\(method)\n\(path)\n\(timestamp)\n\(bodyData.base64EncodedString())"
        
        // Calculate HMAC-SHA256 signature
        let signature = calculateHMAC(message: signatureBase, secret: secret)
        
        // Add headers
        request.setValue(timestamp, forHTTPHeaderField: "X-Timestamp")
        request.setValue(signature, forHTTPHeaderField: "X-Signature")
        
        ErrorLoggingService.shared.logInfo(
            "Signed request to \(path)",
            context: "Request Signing"
        )
    }
    
    // MARK: - Response Validation
    
    /// Validate response signature
    func validateResponse(
        _ response: HTTPURLResponse,
        data: Data,
        withSecret secret: String
    ) throws -> Bool {
        // Get signature from response headers
        guard let receivedSignature = response.value(forHTTPHeaderField: "X-Signature"),
              let timestamp = response.value(forHTTPHeaderField: "X-Timestamp") else {
            // No signature - this is optional for now
            return true
        }
        
        // Check timestamp freshness (within 5 minutes)
        guard let timestampInt = Int(timestamp),
              let requestTime = TimeInterval(exactly: timestampInt) else {
            throw RequestSigningError.invalidTimestamp
        }
        
        let currentTime = Date().timeIntervalSince1970
        let timeDiff = abs(currentTime - requestTime)
        
        guard timeDiff < 300 else { // 5 minutes
            throw RequestSigningError.timestampExpired
        }
        
        // Verify signature
        guard let url = response.url else {
            throw RequestSigningError.invalidResponse
        }
        
        let path = url.path
        let signatureBase = "GET\n\(path)\n\(timestamp)\n\(data.base64EncodedString())"
        let expectedSignature = calculateHMAC(message: signatureBase, secret: secret)
        
        guard receivedSignature == expectedSignature else {
            ErrorLoggingService.shared.logInfo(
                "Response signature validation failed",
                context: "Request Signing"
            )
            throw RequestSigningError.signatureInvalid
        }
        
        ErrorLoggingService.shared.logInfo(
            "Response signature validated",
            context: "Request Signing"
        )
        
        return true
    }
    
    // MARK: - HMAC Calculation
    
    private func calculateHMAC(message: String, secret: String) -> String {
        let key = SymmetricKey(data: Data(secret.utf8))
        let messageData = Data(message.utf8)
        
        let authenticationCode = HMAC<SHA256>.authenticationCode(
            for: messageData,
            using: key
        )
        
        return Data(authenticationCode).base64EncodedString()
    }
    
    // MARK: - Nonce Generation
    
    /// Generate a cryptographic nonce for request uniqueness
    func generateNonce() -> String {
        let nonce = UUID().uuidString + String(Date().timeIntervalSince1970)
        return nonce.data(using: .utf8)?.base64EncodedString() ?? UUID().uuidString
    }
    
    // MARK: - Replay Attack Prevention
    
    private var usedNonces: Set<String> = []
    private let nonceExpirationTime: TimeInterval = 300 // 5 minutes
    
    /// Check if a nonce has been used (prevents replay attacks)
    func validateNonce(_ nonce: String) -> Bool {
        guard !usedNonces.contains(nonce) else {
            ErrorLoggingService.shared.logInfo(
                "Replay attack detected - nonce already used",
                context: "Request Signing"
            )
            return false
        }
        
        usedNonces.insert(nonce)
        
        // Clean up old nonces periodically
        if usedNonces.count > 1000 {
            usedNonces.removeAll()
        }
        
        return true
    }
}

// MARK: - Errors

enum RequestSigningError: LocalizedError {
    case invalidRequest
    case invalidResponse
    case invalidTimestamp
    case timestampExpired
    case signatureInvalid
    case nonceMissing
    case nonceAlreadyUsed
    
    var errorDescription: String? {
        switch self {
        case .invalidRequest:
            return "Invalid request for signing"
        case .invalidResponse:
            return "Invalid response for validation"
        case .invalidTimestamp:
            return "Invalid timestamp in request/response"
        case .timestampExpired:
            return "Request/response timestamp is too old"
        case .signatureInvalid:
            return "Signature validation failed"
        case .nonceMissing:
            return "Nonce is missing from request"
        case .nonceAlreadyUsed:
            return "Nonce has already been used (replay attack)"
        }
    }
}

// MARK: - Request Extensions

extension URLRequest {
    /// Add request signing to this request
    mutating func sign(withSecret secret: String) throws {
        try RequestSigningService.shared.signRequest(&self, withSecret: secret)
    }
    
    /// Add a nonce to this request
    mutating func addNonce() {
        let nonce = RequestSigningService.shared.generateNonce()
        setValue(nonce, forHTTPHeaderField: "X-Nonce")
    }
}
