//
//  SecurityService.swift
//  stashd
//
//  Created by Sean Lynch
//

import Foundation
import UIKit

final class SecurityService {
    static let shared = SecurityService()
    
    private init() {}
    
    // MARK: - Security Checks
    
    /// Run all security checks on app launch
    func performSecurityChecks() -> SecurityCheckResult {
        var issues: [String] = []
        
        // Check for jailbreak
        if isJailbroken() {
            issues.append("Jailbreak detected")
            ErrorLoggingService.shared.logInfo(
                "SECURITY: Jailbreak detected",
                context: "Security"
            )
        }
        
        // Check for debugger
        if isDebuggerAttached() {
            issues.append("Debugger detected")
            ErrorLoggingService.shared.logInfo(
                "SECURITY: Debugger attached",
                context: "Security"
            )
        }
        
        // Check API key
        if !isAPIKeyValid() {
            issues.append("Invalid API key configuration")
            ErrorLoggingService.shared.logInfo(
                "SECURITY: Invalid API key",
                context: "Security"
            )
        }
        
        return SecurityCheckResult(
            passed: issues.isEmpty,
            issues: issues
        )
    }
    
    // MARK: - Jailbreak Detection
    
    func isJailbroken() -> Bool {
        #if targetEnvironment(simulator)
        return false
        #else
        
        // Check for common jailbreak files
        let jailbreakPaths = [
            "/Applications/Cydia.app",
            "/Library/MobileSubstrate/MobileSubstrate.dylib",
            "/bin/bash",
            "/usr/sbin/sshd",
            "/etc/apt",
            "/private/var/lib/apt/",
            "/Applications/blackra1n.app",
            "/Applications/FakeCarrier.app",
            "/Applications/Icy.app",
            "/Applications/IntelliScreen.app",
            "/Applications/MxTube.app",
            "/Applications/RockApp.app",
            "/Applications/SBSettings.app",
            "/Applications/WinterBoard.app"
        ]
        
        for path in jailbreakPaths {
            if FileManager.default.fileExists(atPath: path) {
                // ✅ NEW: Log security event
                SecurityMonitoringService.shared.logEvent(
                    .jailbreakDetected,
                    details: ["method": "file_check", "path": path]
                )
                return true
            }
        }
        
        // Check if we can write to system directories
        let testPath = "/private/test_jailbreak.txt"
        do {
            try "test".write(toFile: testPath, atomically: true, encoding: .utf8)
            try? FileManager.default.removeItem(atPath: testPath)
            
            // ✅ NEW: Log security event
            SecurityMonitoringService.shared.logEvent(
                .jailbreakDetected,
                details: ["method": "write_check"]
            )
            return true
        } catch {
            // Cannot write - good sign
        }
        
        // Check for Cydia URL scheme
        if let url = URL(string: "cydia://package/com.example.package") {
            if UIApplication.shared.canOpenURL(url) {
                // ✅ NEW: Log security event
                SecurityMonitoringService.shared.logEvent(
                    .jailbreakDetected,
                    details: ["method": "url_scheme"]
                )
                return true
            }
        }
        
        return false
        #endif
    }
    
    // MARK: - Debugger Detection
    
    func isDebuggerAttached() -> Bool {
        var info = kinfo_proc()
        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, getpid()]
        var size = MemoryLayout<kinfo_proc>.stride
        let result = sysctl(&mib, UInt32(mib.count), &info, &size, nil, 0)
        
        let isDebugging = (result == 0) && (info.kp_proc.p_flag & P_TRACED) != 0
        
        if isDebugging {
            // ✅ NEW: Log security event
            SecurityMonitoringService.shared.logEvent(
                .debuggerDetected,
                details: ["pid": getpid()]
            )
        }
        
        return isDebugging
    }
    
    // MARK: - API Key Validation
    
    func isAPIKeyValid() -> Bool {
        let apiKey = AppConfig.openAIAPIKey
        
        // Check if API key exists and has proper format
        guard !apiKey.isEmpty,
              apiKey.hasPrefix("sk-"),
              apiKey.count > 20 else {
            return false
        }
        
        return true
    }
}

// MARK: - Security Check Result

struct SecurityCheckResult {
    let passed: Bool
    let issues: [String]
    
    var isSecure: Bool {
        return passed
    }
    
    var message: String {
        if passed {
            return "All security checks passed"
        } else {
            return "Security issues detected: \(issues.joined(separator: ", "))"
        }
    }
    
    var warningMessage: String? {
        if passed {
            return nil
        }
        
        return """
        Security Issue Detected
        
        \(issues.joined(separator: "\n"))
        
        Your device may be compromised. Some features may be restricted for your protection.
        """
    }
}
