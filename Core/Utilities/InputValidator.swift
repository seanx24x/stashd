//
//  InputValidator.swift
//  stashd
//
//  Created by Sean Lynch on 10/13/25.
//


//
//  InputValidator.swift
//  stashd
//
//  Created by Sean Lynch
//

// File: Core/Utilities/InputValidator.swift

import Foundation

enum InputValidator {
    
    // MARK: - String Validation
    
    static func isValidCollectionName(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty && trimmed.count >= 1 && trimmed.count <= 100
    }
    
    static func isValidItemName(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty && trimmed.count >= 1 && trimmed.count <= 200
    }
    
    static func isValidUsername(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        // Username: 3-20 characters, alphanumeric and underscore only
        let pattern = "^[a-zA-Z0-9_]{3,20}$"
        return trimmed.range(of: pattern, options: .regularExpression) != nil
    }
    
    static func isValidDisplayName(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty && trimmed.count >= 1 && trimmed.count <= 50
    }
    
    static func isValidEmail(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let pattern = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        return trimmed.range(of: pattern, options: .regularExpression) != nil
    }
    
    static func isValidPassword(_ text: String) -> Bool {
        // Minimum 8 characters, at least one uppercase, one lowercase, one number
        guard text.count >= 8 else { return false }
        
        let hasUppercase = text.range(of: "[A-Z]", options: .regularExpression) != nil
        let hasLowercase = text.range(of: "[a-z]", options: .regularExpression) != nil
        let hasNumber = text.range(of: "[0-9]", options: .regularExpression) != nil
        
        return hasUppercase && hasLowercase && hasNumber
    }
    
    static func isValidDescription(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.count <= 500
    }
    
    static func isValidComment(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty && trimmed.count >= 1 && trimmed.count <= 500
    }
    
    static func isValidBio(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.count <= 200
    }
    
    // MARK: - Sanitization
    
    static func sanitize(_ text: String) -> String {
        var sanitized = text.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Remove potential script injection attempts
        sanitized = sanitized.replacingOccurrences(of: "<script>", with: "", options: .caseInsensitive)
        sanitized = sanitized.replacingOccurrences(of: "</script>", with: "", options: .caseInsensitive)
        sanitized = sanitized.replacingOccurrences(of: "<iframe>", with: "", options: .caseInsensitive)
        sanitized = sanitized.replacingOccurrences(of: "</iframe>", with: "", options: .caseInsensitive)
        sanitized = sanitized.replacingOccurrences(of: "javascript:", with: "", options: .caseInsensitive)
        
        return sanitized
    }
    
    // MARK: - Validation Error Messages
    
    static func errorMessage(for validationType: ValidationType) -> String {
        switch validationType {
        case .collectionName:
            return "Collection name must be 1-100 characters"
        case .itemName:
            return "Item name must be 1-200 characters"
        case .username:
            return "Username must be 3-20 characters (letters, numbers, underscore only)"
        case .displayName:
            return "Display name must be 1-50 characters"
        case .email:
            return "Please enter a valid email address"
        case .password:
            return "Password must be at least 8 characters with uppercase, lowercase, and number"
        case .description:
            return "Description must be 500 characters or less"
        case .comment:
            return "Comment must be 1-500 characters"
        case .bio:
            return "Bio must be 200 characters or less"
        }
    }
    
    enum ValidationType {
        case collectionName
        case itemName
        case username
        case displayName
        case email
        case password
        case description
        case comment
        case bio
    }
}

// MARK: - String Extension for Convenience

extension String {
    var sanitized: String {
        InputValidator.sanitize(self)
    }
    
    var isValidCollectionName: Bool {
        InputValidator.isValidCollectionName(self)
    }
    
    var isValidItemName: Bool {
        InputValidator.isValidItemName(self)
    }
    
    var isValidUsername: Bool {
        InputValidator.isValidUsername(self)
    }
    
    var isValidDisplayName: Bool {
        InputValidator.isValidDisplayName(self)
    }
    
    var isValidEmail: Bool {
        InputValidator.isValidEmail(self)
    }
    
    var isValidPassword: Bool {
        InputValidator.isValidPassword(self)
    }
    
    var isValidComment: Bool {
        InputValidator.isValidComment(self)
    }
}
