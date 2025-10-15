//
//  SecurityMonitoringService.swift
//  stashd
//
//  Created by Sean Lynch on 10/15/25.
//

import Foundation

@MainActor
final class SecurityMonitoringService {
    static let shared = SecurityMonitoringService()
    
    private init() {
        startMonitoring()
    }
    
    // MARK: - Security Events Tracking
    
    private var securityEvents: [SecurityEvent] = []
    private let maxStoredEvents = 100
    
    // MARK: - Monitoring
    
    func startMonitoring() {
        ErrorLoggingService.shared.logInfo(
            "Security monitoring started",
            context: "Security Monitoring"
        )
    }
    
    // MARK: - Event Logging
    
    /// Log a security event
    func logEvent(_ type: SecurityEventType, details: [String: Any]? = nil) {
        let event = SecurityEvent(
            type: type,
            timestamp: Date(),
            details: details
        )
        
        securityEvents.append(event)
        
        // Keep only recent events
        if securityEvents.count > maxStoredEvents {
            securityEvents.removeFirst(securityEvents.count - maxStoredEvents)
        }
        
        // Log to error service
        ErrorLoggingService.shared.logInfo(
            "Security event: \(type.rawValue)",
            context: "Security Monitoring"
        )
        
        // Check if event requires immediate attention
        if type.isHighSeverity {
            handleHighSeverityEvent(event)
        }
        
        // Check for patterns
        checkForSuspiciousPatterns()
    }
    
    // MARK: - Threat Detection
    
    private func checkForSuspiciousPatterns() {
        // Check for multiple failed authentications
        let recentFailedAuths = securityEvents.filter { event in
            event.type == .authenticationFailed &&
            event.timestamp.timeIntervalSinceNow > -300 // Last 5 minutes
        }
        
        if recentFailedAuths.count >= 5 {
            logEvent(.suspiciousActivity, details: [
                "pattern": "Multiple authentication failures",
                "count": recentFailedAuths.count
            ])
        }
        
        // Check for rapid API calls (potential abuse)
        let recentAPICalls = securityEvents.filter { event in
            event.type == .apiRateLimitHit &&
            event.timestamp.timeIntervalSinceNow > -60 // Last minute
        }
        
        if recentAPICalls.count >= 3 {
            logEvent(.suspiciousActivity, details: [
                "pattern": "Excessive API rate limit hits",
                "count": recentAPICalls.count
            ])
        }
        
        // Check for validation failures (potential injection attempts)
        let recentValidationFailures = securityEvents.filter { event in
            event.type == .validationFailed &&
            event.timestamp.timeIntervalSinceNow > -300 // Last 5 minutes
        }
        
        if recentValidationFailures.count >= 10 {
            logEvent(.suspiciousActivity, details: [
                "pattern": "Multiple validation failures",
                "count": recentValidationFailures.count
            ])
        }
    }
    
    // MARK: - High Severity Event Handling
    
    private func handleHighSeverityEvent(_ event: SecurityEvent) {
        ErrorLoggingService.shared.logError(
            SecurityError.highSeverityEvent(event.type),
            context: "Security Monitoring - HIGH SEVERITY"
        )
        
        // In production, you might:
        // - Send push notification to admin
        // - Send alert to monitoring service (Sentry, Firebase Crashlytics)
        // - Lock down certain features temporarily
        // - Require re-authentication
    }
    
    // MARK: - Statistics
    
    /// Get security statistics
    func getSecurityStats() -> SecurityStats {
        let last24Hours = securityEvents.filter { event in
            event.timestamp.timeIntervalSinceNow > -86400
        }
        
        let eventTypeCounts = Dictionary(grouping: last24Hours) { $0.type }
            .mapValues { $0.count }
        
        return SecurityStats(
            totalEvents: securityEvents.count,
            eventsLast24Hours: last24Hours.count,
            eventsByType: eventTypeCounts,
            highSeverityEvents: securityEvents.filter { $0.type.isHighSeverity }.count
        )
    }
    
    /// Get recent security events
    func getRecentEvents(limit: Int = 20) -> [SecurityEvent] {
        Array(securityEvents.suffix(limit).reversed())
    }
    
    // MARK: - Reset
    
    /// Clear all security events (for testing)
    func clearEvents() {
        securityEvents.removeAll()
        ErrorLoggingService.shared.logInfo(
            "Security events cleared",
            context: "Security Monitoring"
        )
    }
}

// MARK: - Security Event

struct SecurityEvent {
    let id = UUID()
    let type: SecurityEventType
    let timestamp: Date
    let details: [String: Any]?
}

// MARK: - Security Event Types

enum SecurityEventType: String, Codable {
    // Authentication
    case authenticationSuccess = "auth_success"
    case authenticationFailed = "auth_failed"
    case biometricAuthUsed = "biometric_auth"
    case biometricAuthFailed = "biometric_failed"
    
    // Authorization
    case unauthorizedAccess = "unauthorized_access"
    case permissionDenied = "permission_denied"
    
    // Data Security
    case dataEncrypted = "data_encrypted"
    case dataDecrypted = "data_decrypted"
    case sensitiveDataAccessed = "sensitive_data_accessed"
    
    // Network Security
    case sslPinningFailed = "ssl_pinning_failed"
    case sslPinningSuccess = "ssl_pinning_success"
    case apiRateLimitHit = "rate_limit_hit"
    case suspiciousNetworkActivity = "suspicious_network"
    
    // Input Validation
    case validationFailed = "validation_failed"
    case sanitizationApplied = "sanitization_applied"
    case injectionAttempt = "injection_attempt"
    
    // Device Security
    case jailbreakDetected = "jailbreak_detected"
    case debuggerDetected = "debugger_detected"
    case appTampered = "app_tampered"
    
    // General
    case suspiciousActivity = "suspicious_activity"
    case securitySettingChanged = "security_setting_changed"
    
    var isHighSeverity: Bool {
        switch self {
        case .jailbreakDetected, .debuggerDetected, .appTampered,
             .sslPinningFailed, .injectionAttempt, .unauthorizedAccess,
             .suspiciousActivity:
            return true
        default:
            return false
        }
    }
}

// MARK: - Security Stats

struct SecurityStats {
    let totalEvents: Int
    let eventsLast24Hours: Int
    let eventsByType: [SecurityEventType: Int]
    let highSeverityEvents: Int
}

// MARK: - Security Error

enum SecurityError: LocalizedError {
    case highSeverityEvent(SecurityEventType)
    
    var errorDescription: String? {
        switch self {
        case .highSeverityEvent(let type):
            return "High severity security event: \(type.rawValue)"
        }
    }
}
