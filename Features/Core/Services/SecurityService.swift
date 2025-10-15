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
    
    // MARK: - Jailbreak Detection
    
    /// Check if device is jailbroken
    func isJailbroken() -> Bool {
        #if targetEnvironment(simulator)
        // Simulators are always "jailbroken" for testing purposes
        return false
        #else
        
        // Method 1: Check for common jailbreak files
        let jailbreakPaths = [
            "/Applications/Cydia.app",
            "/Applications/blackra1n.app",
            "/Applications/FakeCarrier.app",
            "/Applications/Icy.app",
            "/Applications/IntelliScreen.app",
            "/Applications/MxTube.app",
            "/Applications/RockApp.app",
            "/Applications/SBSettings.app",
            "/Applications/WinterBoard.app",
            "/Library/MobileSubstrate/MobileSubstrate.dylib",
            "/Library/MobileSubstrate/DynamicLibraries/LiveClock.plist",
            "/Library/MobileSubstrate/DynamicLibraries/Veency.plist",
            "/private/var/lib/apt",
            "/private/var/lib/cydia",
            "/private/var/mobile/Library/SBSettings/Themes",
            "/private/var/stash",
            "/private/var/tmp/cydia.log",
            "/System/Library/LaunchDaemons/com.ikey.bbot.plist",
            "/System/Library/LaunchDaemons/com.saurik.Cydia.Startup.plist",
            "/usr/bin/sshd",
            "/usr/libexec/sftp-server",
            "/usr/sbin/sshd",
            "/etc/apt",
            "/bin/bash",
            "/bin/sh",
            "/usr/libexec/ssh-keysign",
            "/usr/libexec/sftp-server",
            "/Applications/Sileo.app",
            "/var/binpack",
            "/Library/PreferenceBundles/LibertyPref.bundle",
            "/Library/PreferenceBundles/ShadowPreferences.bundle",
            "/var/lib/dpkg/info"
        ]
        
        for path in jailbreakPaths {
            if FileManager.default.fileExists(atPath: path) {
                ErrorLoggingService.shared.logInfo(
                    "Jailbreak detected: Found file at \(path)",
                    context: "Security"
                )
                return true
            }
        }
        
        // Method 2: Check if we can write outside the sandbox
        let testPath = "/private/jailbreak_test_" + UUID().uuidString + ".txt"
        do {
            try "test".write(toFile: testPath, atomically: true, encoding: .utf8)
            try FileManager.default.removeItem(atPath: testPath)
            ErrorLoggingService.shared.logInfo(
                "Jailbreak detected: Able to write outside sandbox",
                context: "Security"
            )
            return true
        } catch {
            // Unable to write - good, device is not jailbroken
        }
        
        // Method 3: Check if Cydia URL scheme is available
        if let url = URL(string: "cydia://package/com.example.package"),
           UIApplication.shared.canOpenURL(url) {
            ErrorLoggingService.shared.logInfo(
                "Jailbreak detected: Cydia URL scheme available",
                context: "Security"
            )
            return true
        }
        
        // Method 4: Check for suspicious libraries
        let suspiciousLibraries = [
            "MobileSubstrate",
            "SubstrateLoader",
            "SSLKillSwitch"
        ]
        
        for library in suspiciousLibraries {
            if let _ = dlopen("/usr/lib/\(library).dylib", RTLD_NOW) {
                ErrorLoggingService.shared.logInfo(
                    "Jailbreak detected: Found suspicious library \(library)",
                    context: "Security"
                )
                return true
            }
        }
        
        // Method 5: Check for stat on system files (✅ FIXED)
        // On jailbroken devices, we can stat files that should be restricted
        var statInfo = stat()
        let restrictedPaths = ["/bin/bash", "/usr/sbin/sshd", "/etc/apt"]
        for path in restrictedPaths {
            if stat(path, &statInfo) == 0 {
                ErrorLoggingService.shared.logInfo(
                    "Jailbreak detected: Can access restricted path \(path)",
                    context: "Security"
                )
                return true
            }
        }
        
        // No jailbreak detected
        return false
        #endif
    }
    
    // MARK: - Debugger Detection
    
    /// Check if a debugger is attached
    func isDebuggerAttached() -> Bool {
        #if DEBUG
        // Allow debuggers in debug builds
        return false
        #else
        var info = kinfo_proc()
        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, getpid()]
        var size = MemoryLayout<kinfo_proc>.stride
        
        let result = sysctl(&mib, UInt32(mib.count), &info, &size, nil, 0)
        
        if result != 0 {
            return false
        }
        
        let isDebugged = (info.kp_proc.p_flag & P_TRACED) != 0
        
        if isDebugged {
            ErrorLoggingService.shared.logInfo(
                "Debugger detected",
                context: "Security"
            )
        }
        
        return isDebugged
        #endif
    }
    
    // MARK: - App Integrity Check
    
    /// Check if the app has been tampered with
    func isAppTampered() -> Bool {
        #if DEBUG
        // Skip integrity checks in debug builds
        return false
        #else
        
        // Check if app is running from expected location
        guard let bundlePath = Bundle.main.bundlePath as String? else {
            return true
        }
        
        // Apps should be in /var/containers/Bundle/Application/
        // or /private/var/containers/Bundle/Application/
        let isInExpectedLocation = bundlePath.contains("/var/containers/Bundle/Application/") ||
                                   bundlePath.contains("/private/var/containers/Bundle/Application/")
        
        if !isInExpectedLocation {
            ErrorLoggingService.shared.logInfo(
                "App integrity check failed: Unexpected bundle location",
                context: "Security"
            )
            return true
        }
        
        // Check if Info.plist has been modified
        guard let infoPlist = Bundle.main.infoDictionary,
              let bundleID = infoPlist["CFBundleIdentifier"] as? String else {
            return true
        }
        
        // Verify bundle ID matches expected value
        if bundleID != "com.stashd.app" {
            ErrorLoggingService.shared.logInfo(
                "App integrity check failed: Bundle ID mismatch",
                context: "Security"
            )
            return true
        }
        
        return false
        #endif
    }
    
    // MARK: - Combined Security Check
    
    /// Perform all security checks
    func performSecurityChecks() -> SecurityCheckResult {
        let jailbroken = isJailbroken()
        let debuggerAttached = isDebuggerAttached()
        let appTampered = isAppTampered()
        
        let isSecure = !jailbroken && !debuggerAttached && !appTampered
        
        if !isSecure {
            ErrorLoggingService.shared.logInfo(
                "Security check failed - Jailbroken: \(jailbroken), Debugger: \(debuggerAttached), Tampered: \(appTampered)",
                context: "Security"
            )
        }
        
        return SecurityCheckResult(
            isSecure: isSecure,
            isJailbroken: jailbroken,
            hasDebugger: debuggerAttached,
            isTampered: appTampered
        )
    }
}

// MARK: - Security Check Result

struct SecurityCheckResult {
    let isSecure: Bool
    let isJailbroken: Bool
    let hasDebugger: Bool
    let isTampered: Bool
    
    var warningMessage: String? {
        if !isSecure {
            var messages: [String] = []
            
            if isJailbroken {
                messages.append("This device appears to be jailbroken.")
            }
            if hasDebugger {
                messages.append("A debugger is attached.")
            }
            if isTampered {
                messages.append("The app may have been tampered with.")
            }
            
            return messages.joined(separator: " ") + " This may affect app security and functionality."
        }
        return nil
    }
}
