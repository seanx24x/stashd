//
//  ErrorLoggingService.swift
//  stashd
//
//  Created by Sean Lynch on 10/15/25.
//


//
//  ErrorLoggingService.swift
//  stashd
//
//  Created by Sean Lynch
//

import Foundation
import os.log

final class ErrorLoggingService {
    static let shared = ErrorLoggingService()
    
    private let logger = Logger(subsystem: "com.stashd.app", category: "ErrorLogging")
    
    // Sensitive keywords that should never be logged
    private let sensitiveKeywords = [
        "password", "token", "key", "secret", "api", "auth",
        "bearer", "credential", "session", "firebase"
    ]
    
    private init() {}
    
    // MARK: - Public Logging Methods
    
    /// Log a general error
    func logError(
        _ error: Error,
        context: String,
        additionalInfo: [String: Any]? = nil
    ) {
        let sanitizedMessage = sanitize(error.localizedDescription)
        let sanitizedContext = sanitize(context)
        let sanitizedInfo = sanitizeDict(additionalInfo ?? [:])
        
        #if DEBUG
        logger.error("❌ [\(sanitizedContext)] \(sanitizedMessage)")
        if !sanitizedInfo.isEmpty {
            logger.debug("Additional Info: \(String(describing: sanitizedInfo))")
        }
        #else
        // In production, send to analytics service
        sendToAnalytics(
            level: .error,
            message: sanitizedMessage,
            context: sanitizedContext,
            info: sanitizedInfo
        )
        #endif
    }
    
    /// Log a validation error
    func logValidationError(
        _ error: ValidationError,
        field: String,
        value: String
    ) {
        let sanitizedField = sanitize(field)
        let sanitizedValue = sanitize(value)
        
        #if DEBUG
        logger.warning("⚠️ Validation failed for '\(sanitizedField)': \(error.localizedDescription ?? "Unknown error")")
        #else
        sendToAnalytics(
            level: .warning,
            message: "Validation failed: \(error.localizedDescription ?? "Unknown")",
            context: "Field: \(sanitizedField)",
            info: ["field": sanitizedField, "errorType": String(describing: error)]
        )
        #endif
    }
    
    /// Log a network error
    func logNetworkError(
        _ error: Error,
        endpoint: String,
        statusCode: Int? = nil
    ) {
        let sanitizedEndpoint = sanitizeURL(endpoint)
        
        #if DEBUG
        logger.error("🌐 Network error at \(sanitizedEndpoint): \(error.localizedDescription)")
        if let statusCode = statusCode {
            logger.debug("Status code: \(statusCode)")
        }
        #else
        sendToAnalytics(
            level: .error,
            message: "Network error: \(error.localizedDescription)",
            context: "Endpoint: \(sanitizedEndpoint)",
            info: [
                "endpoint": sanitizedEndpoint,
                "statusCode": statusCode ?? 0
            ]
        )
        #endif
    }
    
    /// Log an authentication error
    func logAuthError(
        _ error: Error,
        action: String
    ) {
        let sanitizedAction = sanitize(action)
        
        #if DEBUG
        logger.error("🔐 Auth error during '\(sanitizedAction)': \(error.localizedDescription)")
        #else
        sendToAnalytics(
            level: .error,
            message: "Authentication error",
            context: "Action: \(sanitizedAction)",
            info: ["action": sanitizedAction]
        )
        #endif
    }
    
    /// Log a Firebase error
    func logFirebaseError(
        _ error: Error,
        operation: String
    ) {
        let sanitizedOperation = sanitize(operation)
        
        #if DEBUG
        logger.error("🔥 Firebase error during '\(sanitizedOperation)': \(error.localizedDescription)")
        #else
        sendToAnalytics(
            level: .error,
            message: "Firebase error",
            context: "Operation: \(sanitizedOperation)",
            info: ["operation": sanitizedOperation]
        )
        #endif
    }
    
    /// Log an info message (for tracking user actions)
    func logInfo(
        _ message: String,
        context: String = ""
    ) {
        let sanitizedMessage = sanitize(message)
        let sanitizedContext = sanitize(context)
        
        #if DEBUG
        logger.info("ℹ️ [\(sanitizedContext)] \(sanitizedMessage)")
        #endif
    }
    
    // MARK: - Sanitization
    
    /// Sanitize a string to remove sensitive information
    private func sanitize(_ text: String) -> String {
        var sanitized = text.lowercased()
        
        // Check for sensitive keywords
        for keyword in sensitiveKeywords {
            if sanitized.contains(keyword) {
                return "[REDACTED - Contains sensitive data]"
            }
        }
        
        // Remove potential API keys (anything starting with sk-, pk-, etc.)
        let keyPattern = "\\b(sk|pk|api|key)[-_][a-zA-Z0-9]{20,}\\b"
        if let regex = try? NSRegularExpression(pattern: keyPattern, options: .caseInsensitive) {
            let range = NSRange(text.startIndex..., in: text)
            if regex.firstMatch(in: text, range: range) != nil {
                return "[REDACTED - Contains API key]"
            }
        }
        
        return text
    }
    
    /// Sanitize a URL to remove query parameters with sensitive data
    private func sanitizeURL(_ urlString: String) -> String {
        guard let url = URL(string: urlString) else {
            return sanitize(urlString)
        }
        
        // Remove query parameters (they might contain tokens)
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return url.path
        }
        
        return components.path
    }
    
    /// Sanitize a dictionary to remove sensitive values
    private func sanitizeDict(_ dict: [String: Any]) -> [String: String] {
        var sanitized: [String: String] = [:]
        
        for (key, value) in dict {
            let sanitizedKey = sanitize(key)
            let sanitizedValue = sanitize(String(describing: value))
            sanitized[sanitizedKey] = sanitizedValue
        }
        
        return sanitized
    }
    
    // MARK: - Analytics Integration
    
    private func sendToAnalytics(
        level: LogLevel,
        message: String,
        context: String,
        info: [String: Any]
    ) {
        // TODO: Integrate with your analytics service
        // Examples:
        // - Firebase Crashlytics: Crashlytics.crashlytics().log(message)
        // - Sentry: SentrySDK.capture(message: message)
        // - Custom backend endpoint
        
        // For now, just use os.log in production too
        switch level {
        case .error:
            logger.error("[\(context)] \(message)")
        case .warning:
            logger.warning("[\(context)] \(message)")
        case .info:
            logger.info("[\(context)] \(message)")
        }
    }
    
    private enum LogLevel {
        case error, warning, info
    }
}