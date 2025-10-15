//
//  ResponseValidationService.swift
//  stashd
//
//  Created by Sean Lynch on 10/15/25.
//


//
//  ResponseValidationService.swift
//  stashd
//
//  Created by Sean Lynch
//

import Foundation

final class ResponseValidationService {
    static let shared = ResponseValidationService()
    
    private init() {}
    
    // MARK: - Response Structure Validation
    
    /// Validate JSON response has expected structure
    func validateJSONStructure(
        _ data: Data,
        expectedKeys: [String]
    ) throws -> [String: Any] {
        // Parse JSON
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            ErrorLoggingService.shared.logInfo(
                "Invalid JSON response structure",
                context: "Response Validation"
            )
            throw ResponseValidationError.invalidJSON
        }
        
        // Check for expected keys
        for key in expectedKeys {
            guard json[key] != nil else {
                ErrorLoggingService.shared.logInfo(
                    "Missing expected key: \(key)",
                    context: "Response Validation"
                )
                throw ResponseValidationError.missingRequiredField(key)
            }
        }
        
        return json
    }
    
    // MARK: - String Validation
    
    /// Validate and sanitize string from API
    func validateString(
        _ value: Any?,
        fieldName: String,
        maxLength: Int = 1000,
        allowEmpty: Bool = false
    ) throws -> String {
        guard let string = value as? String else {
            throw ResponseValidationError.invalidType(fieldName, expected: "String")
        }
        
        if !allowEmpty && string.isEmpty {
            throw ResponseValidationError.emptyValue(fieldName)
        }
        
        guard string.count <= maxLength else {
            ErrorLoggingService.shared.logInfo(
                "String too long for field \(fieldName): \(string.count) chars",
                context: "Response Validation"
            )
            throw ResponseValidationError.valueTooLong(fieldName, maxLength)
        }
        
        // Sanitize the string
        return ValidationService.sanitizeInput(string)
    }
    
    // MARK: - Number Validation
    
    /// Validate integer from API
    func validateInt(
        _ value: Any?,
        fieldName: String,
        min: Int? = nil,
        max: Int? = nil
    ) throws -> Int {
        guard let number = value as? Int else {
            // Try to convert from string or double
            if let string = value as? String, let int = Int(string) {
                return try validateInt(int, fieldName: fieldName, min: min, max: max)
            }
            if let double = value as? Double {
                return try validateInt(Int(double), fieldName: fieldName, min: min, max: max)
            }
            throw ResponseValidationError.invalidType(fieldName, expected: "Int")
        }
        
        if let min = min, number < min {
            throw ResponseValidationError.valueOutOfRange(fieldName, min, max)
        }
        
        if let max = max, number > max {
            throw ResponseValidationError.valueOutOfRange(fieldName, min, max)
        }
        
        return number
    }
    
    /// Validate decimal/double from API
    func validateDecimal(
        _ value: Any?,
        fieldName: String,
        min: Decimal? = nil,
        max: Decimal? = nil
    ) throws -> Decimal {
        let decimal: Decimal
        
        if let number = value as? NSNumber {
            decimal = number.decimalValue
        } else if let double = value as? Double {
            decimal = Decimal(double)
        } else if let string = value as? String, let doubleValue = Double(string) {
            decimal = Decimal(doubleValue)
        } else {
            throw ResponseValidationError.invalidType(fieldName, expected: "Decimal")
        }
        
        if let min = min, decimal < min {
            throw ResponseValidationError.valueOutOfRange(fieldName, min, max)
        }
        
        if let max = max, decimal > max {
            throw ResponseValidationError.valueOutOfRange(fieldName, min, max)
        }
        
        return decimal
    }
    
    // MARK: - Array Validation
    
    /// Validate array from API
    func validateArray<T>(
        _ value: Any?,
        fieldName: String,
        maxCount: Int = 1000,
        allowEmpty: Bool = true
    ) throws -> [T] {
        guard let array = value as? [T] else {
            throw ResponseValidationError.invalidType(fieldName, expected: "Array")
        }
        
        if !allowEmpty && array.isEmpty {
            throw ResponseValidationError.emptyValue(fieldName)
        }
        
        guard array.count <= maxCount else {
            ErrorLoggingService.shared.logInfo(
                "Array too large for field \(fieldName): \(array.count) items",
                context: "Response Validation"
            )
            throw ResponseValidationError.arrayTooLarge(fieldName, maxCount)
        }
        
        return array
    }
    
    // MARK: - URL Validation
    
    /// Validate URL from API
    func validateURL(
        _ value: Any?,
        fieldName: String,
        allowedSchemes: [String] = ["https", "http"]
    ) throws -> URL {
        guard let urlString = value as? String else {
            throw ResponseValidationError.invalidType(fieldName, expected: "URL String")
        }
        
        guard let url = URL(string: urlString) else {
            throw ResponseValidationError.invalidURL(fieldName)
        }
        
        guard let scheme = url.scheme?.lowercased(),
              allowedSchemes.contains(scheme) else {
            throw ResponseValidationError.invalidURLScheme(fieldName, allowedSchemes)
        }
        
        return url
    }
    
    // MARK: - Date Validation
    
    /// Validate ISO8601 date from API
    func validateDate(
        _ value: Any?,
        fieldName: String
    ) throws -> Date {
        guard let dateString = value as? String else {
            throw ResponseValidationError.invalidType(fieldName, expected: "Date String")
        }
        
        let formatter = ISO8601DateFormatter()
        guard let date = formatter.date(from: dateString) else {
            throw ResponseValidationError.invalidDateFormat(fieldName)
        }
        
        return date
    }
    
    // MARK: - Enum Validation
    
    /// Validate enum value from API
    func validateEnum<T: RawRepresentable>(
        _ value: Any?,
        fieldName: String,
        type: T.Type
    ) throws -> T where T.RawValue == String {
        guard let stringValue = value as? String else {
            throw ResponseValidationError.invalidType(fieldName, expected: "String")
        }
        
        guard let enumValue = T(rawValue: stringValue) else {
            throw ResponseValidationError.invalidEnumValue(fieldName, stringValue)
        }
        
        return enumValue
    }
    
    // MARK: - Response Size Validation
    
    /// Validate response isn't too large
    func validateResponseSize(
        _ data: Data,
        maxBytes: Int = 10_000_000 // 10 MB default
    ) throws {
        guard data.count <= maxBytes else {
            ErrorLoggingService.shared.logInfo(
                "Response too large: \(data.count) bytes",
                context: "Response Validation"
            )
            throw ResponseValidationError.responseTooLarge(maxBytes)
        }
    }
    
    // MARK: - Content Type Validation
    
    /// Validate response content type
    func validateContentType(
        _ response: HTTPURLResponse,
        expectedTypes: [String] = ["application/json"]
    ) throws {
        guard let contentType = response.value(forHTTPHeaderField: "Content-Type") else {
            throw ResponseValidationError.missingContentType
        }
        
        let typeMatches = expectedTypes.contains { expectedType in
            contentType.lowercased().contains(expectedType.lowercased())
        }
        
        guard typeMatches else {
            ErrorLoggingService.shared.logInfo(
                "Unexpected content type: \(contentType)",
                context: "Response Validation"
            )
            throw ResponseValidationError.invalidContentType(contentType, expectedTypes)
        }
    }
}

// MARK: - Errors

enum ResponseValidationError: LocalizedError {
    case invalidJSON
    case missingRequiredField(String)
    case invalidType(String, expected: String)
    case emptyValue(String)
    case valueTooLong(String, Int)
    case valueOutOfRange(String, Any?, Any?)
    case arrayTooLarge(String, Int)
    case invalidURL(String)
    case invalidURLScheme(String, [String])
    case invalidDateFormat(String)
    case invalidEnumValue(String, String)
    case responseTooLarge(Int)
    case missingContentType
    case invalidContentType(String, [String])
    
    var errorDescription: String? {
        switch self {
        case .invalidJSON:
            return "Invalid JSON response"
        case .missingRequiredField(let field):
            return "Missing required field: \(field)"
        case .invalidType(let field, let expected):
            return "Invalid type for \(field), expected \(expected)"
        case .emptyValue(let field):
            return "Empty value for required field: \(field)"
        case .valueTooLong(let field, let max):
            return "Value too long for \(field), max \(max) characters"
        case .valueOutOfRange(let field, let min, let max):
            return "Value out of range for \(field), expected between \(String(describing: min)) and \(String(describing: max))"
        case .arrayTooLarge(let field, let max):
            return "Array too large for \(field), max \(max) items"
        case .invalidURL(let field):
            return "Invalid URL for \(field)"
        case .invalidURLScheme(let field, let allowed):
            return "Invalid URL scheme for \(field), allowed: \(allowed.joined(separator: ", "))"
        case .invalidDateFormat(let field):
            return "Invalid date format for \(field)"
        case .invalidEnumValue(let field, let value):
            return "Invalid enum value '\(value)' for \(field)"
        case .responseTooLarge(let max):
            return "Response too large, max \(max) bytes"
        case .missingContentType:
            return "Missing Content-Type header"
        case .invalidContentType(let actual, let expected):
            return "Invalid content type '\(actual)', expected one of: \(expected.joined(separator: ", "))"
        }
    }
}