//
//  ValidationService.swift
//  stashd
//
//  Created by Sean Lynch on 10/14/25.
//


//
//  ValidationService.swift
//  stashd
//
//  Created by Sean Lynch
//

import Foundation

enum ValidationService {
    
    // MARK: - Username Validation
    
    static func validateUsername(_ username: String) throws {
        let trimmed = username.trimmingCharacters(in: .whitespaces)
        
        guard !trimmed.isEmpty else {
            throw ValidationError.usernameEmpty
        }
        
        guard trimmed.count >= 3 else {
            throw ValidationError.usernameTooShort
        }
        
        guard trimmed.count <= 20 else {
            throw ValidationError.usernameTooLong
        }
        
        // Only alphanumeric and underscore
        let usernameRegex = "^[a-zA-Z0-9_]+$"
        guard trimmed.range(of: usernameRegex, options: .regularExpression) != nil else {
            throw ValidationError.usernameInvalidCharacters
        }
        
        // Block reserved/offensive words
        let blockedWords = [
            "admin", "stashd", "moderator", "system", "support",
            "official", "staff", "owner", "founder", "team"
        ]
        
        guard !blockedWords.contains(trimmed.lowercased()) else {
            throw ValidationError.usernameReserved
        }
        
        // Block usernames that start with numbers
        guard trimmed.first?.isNumber != true else {
            throw ValidationError.usernameInvalidStart
        }
    }
    
    // MARK: - Display Name Validation
    
    static func validateDisplayName(_ name: String) throws {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmed.isEmpty else {
            throw ValidationError.displayNameEmpty
        }
        
        guard trimmed.count >= 1 else {
            throw ValidationError.displayNameTooShort
        }
        
        guard trimmed.count <= 50 else {
            throw ValidationError.displayNameTooLong
        }
        
        // Must contain at least one letter
        guard trimmed.rangeOfCharacter(from: .letters) != nil else {
            throw ValidationError.displayNameNoLetters
        }
    }
    
    // MARK: - Bio Validation
    
    static func validateBio(_ bio: String?) throws {
        guard let bio = bio, !bio.isEmpty else {
            return // Bio is optional
        }
        
        let trimmed = bio.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard trimmed.count <= 160 else {
            throw ValidationError.bioTooLong
        }
    }
    
    // MARK: - Collection Title Validation
    
    static func validateCollectionTitle(_ title: String) throws {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmed.isEmpty else {
            throw ValidationError.titleEmpty
        }
        
        guard trimmed.count >= 3 else {
            throw ValidationError.titleTooShort
        }
        
        guard trimmed.count <= 100 else {
            throw ValidationError.titleTooLong
        }
    }
    
    // MARK: - Collection Description Validation
    
    static func validateCollectionDescription(_ description: String?) throws {
        guard let description = description, !description.isEmpty else {
            return // Description is optional
        }
        
        let trimmed = description.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard trimmed.count <= 500 else {
            throw ValidationError.descriptionTooLong
        }
    }
    
    // MARK: - Item Name Validation
    
    static func validateItemName(_ name: String) throws {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmed.isEmpty else {
            throw ValidationError.itemNameEmpty
        }
        
        guard trimmed.count >= 2 else {
            throw ValidationError.itemNameTooShort
        }
        
        guard trimmed.count <= 100 else {
            throw ValidationError.itemNameTooLong
        }
    }
    
    // MARK: - Comment Validation
    
    static func validateComment(_ comment: String) throws {
        let trimmed = comment.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmed.isEmpty else {
            throw ValidationError.commentEmpty
        }
        
        guard trimmed.count >= 1 else {
            throw ValidationError.commentTooShort
        }
        
        guard trimmed.count <= 500 else {
            throw ValidationError.commentTooLong
        }
    }
    
    // MARK: - Input Sanitization
    
    static func sanitizeInput(_ input: String) -> String {
        // Remove potentially dangerous characters
        var sanitized = input.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Remove control characters
        sanitized = sanitized.components(separatedBy: .controlCharacters).joined()
        
        // Remove zero-width characters (can be used for spoofing)
        let zeroWidthChars = CharacterSet(charactersIn: "\u{200B}\u{200C}\u{200D}\u{FEFF}")
        sanitized = sanitized.components(separatedBy: zeroWidthChars).joined()
        
        return sanitized
    }
    
    // MARK: - Email Validation (Basic)
    
    static func validateEmail(_ email: String) throws {
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
        
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        guard trimmed.range(of: emailRegex, options: .regularExpression) != nil else {
            throw ValidationError.emailInvalid
        }
    }
    
    // MARK: - URL Validation
    
    static func validateURL(_ urlString: String) throws -> URL {
        guard let url = URL(string: urlString),
              url.scheme != nil,
              url.host != nil else {
            throw ValidationError.urlInvalid
        }
        
        // Only allow http/https
        guard url.scheme == "http" || url.scheme == "https" else {
            throw ValidationError.urlInvalidScheme
        }
        
        return url
    }
    
    // MARK: - Price/Value Validation
    
    static func validatePrice(_ price: Decimal) throws {
        guard price >= 0 else {
            throw ValidationError.priceNegative
        }
        
        guard price <= 999999.99 else {
            throw ValidationError.priceTooHigh
        }
    }
}

// MARK: - Validation Errors

enum ValidationError: LocalizedError {
    // Username
    case usernameEmpty
    case usernameTooShort
    case usernameTooLong
    case usernameInvalidCharacters
    case usernameReserved
    case usernameInvalidStart
    
    // Display Name
    case displayNameEmpty
    case displayNameTooShort
    case displayNameTooLong
    case displayNameNoLetters
    
    // Bio
    case bioTooLong
    
    // Collection Title
    case titleEmpty
    case titleTooShort
    case titleTooLong
    
    // Description
    case descriptionTooLong
    
    // Item Name
    case itemNameEmpty
    case itemNameTooShort
    case itemNameTooLong
    
    // Comment
    case commentEmpty
    case commentTooShort
    case commentTooLong
    
    // Email
    case emailInvalid
    
    // URL
    case urlInvalid
    case urlInvalidScheme
    
    // Price
    case priceNegative
    case priceTooHigh
    
    var errorDescription: String? {
        switch self {
        // Username
        case .usernameEmpty:
            return "Username cannot be empty"
        case .usernameTooShort:
            return "Username must be at least 3 characters"
        case .usernameTooLong:
            return "Username must be 20 characters or less"
        case .usernameInvalidCharacters:
            return "Username can only contain letters, numbers, and underscores"
        case .usernameReserved:
            return "This username is reserved"
        case .usernameInvalidStart:
            return "Username cannot start with a number"
            
        // Display Name
        case .displayNameEmpty:
            return "Display name cannot be empty"
        case .displayNameTooShort:
            return "Display name must be at least 1 character"
        case .displayNameTooLong:
            return "Display name must be 50 characters or less"
        case .displayNameNoLetters:
            return "Display name must contain at least one letter"
            
        // Bio
        case .bioTooLong:
            return "Bio must be 160 characters or less"
            
        // Collection Title
        case .titleEmpty:
            return "Title cannot be empty"
        case .titleTooShort:
            return "Title must be at least 3 characters"
        case .titleTooLong:
            return "Title must be 100 characters or less"
            
        // Description
        case .descriptionTooLong:
            return "Description must be 500 characters or less"
            
        // Item Name
        case .itemNameEmpty:
            return "Item name cannot be empty"
        case .itemNameTooShort:
            return "Item name must be at least 2 characters"
        case .itemNameTooLong:
            return "Item name must be 100 characters or less"
            
        // Comment
        case .commentEmpty:
            return "Comment cannot be empty"
        case .commentTooShort:
            return "Comment must be at least 1 character"
        case .commentTooLong:
            return "Comment must be 500 characters or less"
            
        // Email
        case .emailInvalid:
            return "Please enter a valid email address"
            
        // URL
        case .urlInvalid:
            return "Please enter a valid URL"
        case .urlInvalidScheme:
            return "URL must start with http:// or https://"
            
        // Price
        case .priceNegative:
            return "Price cannot be negative"
        case .priceTooHigh:
            return "Price cannot exceed $999,999.99"
        }
    }
}
