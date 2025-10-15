//
//  BiometricAuthService.swift
//  stashd
//
//  Created by Sean Lynch on 10/15/25.
//


//
//  BiometricAuthService.swift
//  stashd
//
//  Created by Sean Lynch
//

import Foundation
import LocalAuthentication

@MainActor
final class BiometricAuthService {
    static let shared = BiometricAuthService()
    
    private init() {}
    
    // MARK: - Biometric Availability
    
    /// Check if biometric authentication is available
    func isBiometricAvailable() -> (available: Bool, biometryType: LABiometryType, error: BiometricError?) {
        let context = LAContext()
        var error: NSError?
        
        let canEvaluate = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
        
        if let error = error {
            let biometricError = mapError(error)
            ErrorLoggingService.shared.logInfo(
                "Biometric auth not available: \(biometricError.localizedDescription)",
                context: "Biometric Auth"
            )
            return (false, .none, biometricError)
        }
        
        return (canEvaluate, context.biometryType, nil)
    }
    
    // MARK: - Authentication
    
    /// Authenticate user with biometrics
    func authenticate(reason: String) async -> Result<Bool, BiometricError> {
        let context = LAContext()
        context.localizedCancelTitle = "Cancel"
        context.localizedFallbackTitle = "Use Passcode"
        
        // Check if biometrics are available
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            if let error = error {
                let biometricError = mapError(error)
                ErrorLoggingService.shared.logInfo(
                    "Biometric auth failed: \(biometricError.localizedDescription)",
                    context: "Biometric Auth"
                )
                return .failure(biometricError)
            }
            return .failure(.notAvailable)
        }
        
        // Perform authentication
        do {
            let success = try await context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: reason
            )
            
            if success {
                ErrorLoggingService.shared.logInfo(
                    "Biometric authentication succeeded",
                    context: "Biometric Auth"
                )
                return .success(true)
            } else {
                return .failure(.authenticationFailed)
            }
        } catch let error as LAError {
            let biometricError = mapLAError(error)
            ErrorLoggingService.shared.logInfo(
                "Biometric auth error: \(biometricError.localizedDescription)",
                context: "Biometric Auth"
            )
            return .failure(biometricError)
        } catch {
            ErrorLoggingService.shared.logError(
                error,
                context: "Biometric authentication"
            )
            return .failure(.unknown)
        }
    }
    
    /// Authenticate with fallback to passcode
    func authenticateWithFallback(reason: String) async -> Result<Bool, BiometricError> {
        let context = LAContext()
        context.localizedCancelTitle = "Cancel"
        
        // This policy allows fallback to device passcode
        do {
            let success = try await context.evaluatePolicy(
                .deviceOwnerAuthentication, // Note: Without "WithBiometrics"
                localizedReason: reason
            )
            
            if success {
                ErrorLoggingService.shared.logInfo(
                    "Authentication succeeded (biometric or passcode)",
                    context: "Biometric Auth"
                )
                return .success(true)
            } else {
                return .failure(.authenticationFailed)
            }
        } catch let error as LAError {
            let biometricError = mapLAError(error)
            ErrorLoggingService.shared.logInfo(
                "Authentication error: \(biometricError.localizedDescription)",
                context: "Biometric Auth"
            )
            return .failure(biometricError)
        } catch {
            ErrorLoggingService.shared.logError(
                error,
                context: "Authentication"
            )
            return .failure(.unknown)
        }
    }
    
    // MARK: - Helper Methods
    
    /// Get user-friendly biometric type name
    func getBiometricTypeName() -> String {
        let (available, biometryType, _) = isBiometricAvailable()
        
        guard available else {
            return "Biometrics"
        }
        
        switch biometryType {
        case .faceID:
            return "Face ID"
        case .touchID:
            return "Touch ID"
        case .opticID:
            return "Optic ID"
        case .none:
            return "Biometrics"
        @unknown default:
            return "Biometrics"
        }
    }
    
    // MARK: - Error Mapping
    
    private func mapError(_ error: NSError) -> BiometricError {
        guard let laError = error as? LAError else {
            return .unknown
        }
        return mapLAError(laError)
    }
    
    private func mapLAError(_ error: LAError) -> BiometricError {
        switch error.code {
        case .biometryNotAvailable:
            return .notAvailable
        case .biometryNotEnrolled:
            return .notEnrolled
        case .biometryLockout:
            return .lockout
        case .userCancel:
            return .userCancelled
        case .userFallback:
            return .userFallback
        case .systemCancel:
            return .systemCancelled
        case .passcodeNotSet:
            return .passcodeNotSet
        case .authenticationFailed:
            return .authenticationFailed
        default:
            return .unknown
        }
    }
}

// MARK: - Biometric Error

enum BiometricError: LocalizedError {
    case notAvailable
    case notEnrolled
    case lockout
    case userCancelled
    case userFallback
    case systemCancelled
    case passcodeNotSet
    case authenticationFailed
    case unknown
    
    var errorDescription: String? {
        switch self {
        case .notAvailable:
            return "Biometric authentication is not available on this device"
        case .notEnrolled:
            return "No biometric data is enrolled. Please set up Face ID or Touch ID in Settings"
        case .lockout:
            return "Biometric authentication is locked. Please try again later or use your passcode"
        case .userCancelled:
            return "Authentication was cancelled"
        case .userFallback:
            return "User chose to use passcode instead"
        case .systemCancelled:
            return "Authentication was cancelled by the system"
        case .passcodeNotSet:
            return "Device passcode is not set"
        case .authenticationFailed:
            return "Authentication failed"
        case .unknown:
            return "An unknown error occurred"
        }
    }
    
    var isRecoverable: Bool {
        switch self {
        case .userCancelled, .userFallback, .authenticationFailed:
            return true
        default:
            return false
        }
    }
}