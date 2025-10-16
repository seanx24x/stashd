//
//  DuplicateDetectionService.swift
//  stashd
//
//  Created by Sean Lynch on 10/16/25.
//


//
//  DuplicateDetectionService.swift
//  stashd
//
//  Created by Sean Lynch
//

import Foundation
import SwiftData

@MainActor
final class DuplicateDetectionService {
    static let shared = DuplicateDetectionService()
    
    private init() {}
    
    struct DuplicateResult {
        let isDuplicate: Bool
        let matchedItems: [CollectionItem]
        let confidence: Double // 0-100
        let reason: String
        
        var shouldWarn: Bool {
            confidence >= 70
        }
    }
    
    // MARK: - Check for Duplicates
    
    func checkForDuplicates(
        itemName: String,
        itemDescription: String?,
        in collection: CollectionModel,
        modelContext: ModelContext
    ) async throws -> DuplicateResult {
        
        guard let items = collection.items, !items.isEmpty else {
            return DuplicateResult(
                isDuplicate: false,
                matchedItems: [],
                confidence: 0,
                reason: "No existing items to compare"
            )
        }
        
        // Quick check: exact name match
        let exactMatches = items.filter { 
            $0.name.lowercased() == itemName.lowercased()
        }
        
        if !exactMatches.isEmpty {
            return DuplicateResult(
                isDuplicate: true,
                matchedItems: exactMatches,
                confidence: 100,
                reason: "Exact name match found"
            )
        }
        
        // Use AI for fuzzy matching
        let aiResult = try await checkWithAI(
            itemName: itemName,
            itemDescription: itemDescription,
            existingItems: items
        )
        
        return aiResult
    }
    
    // MARK: - AI-Powered Detection
    
    private func checkWithAI(
        itemName: String,
        itemDescription: String?,
        existingItems: [CollectionItem]
    ) async throws -> DuplicateResult {
        
        let existingItemsText = existingItems.prefix(20).map { item in
            var text = "- \(item.name)"
            if let desc = item.notes {
                text += " (\(desc))"
            }
            return text
        }.joined(separator: "\n")
        
        let prompt = """
        You are a duplicate detection system for a collection app. Analyze if the new item is a duplicate of any existing items.
        
        NEW ITEM:
        Name: \(itemName)
        Description: \(itemDescription ?? "None")
        
        EXISTING ITEMS:
        \(existingItemsText)
        
        Return ONLY valid JSON with this exact structure:
        {
            "isDuplicate": true/false,
            "matchedItems": ["Item name 1", "Item name 2"],
            "confidence": 0-100,
            "reason": "Brief explanation"
        }
        
        Consider items duplicates if they are the same product, even with slight name variations (e.g., "iPhone 13 Pro" vs "Apple iPhone 13 Pro 128GB").
        Different conditions (New vs Used) of the same item should still be flagged as potential duplicates.
        Confidence levels:
        - 100: Exact match
        - 80-99: Very likely duplicate (minor differences)
        - 60-79: Probably duplicate (some differences)
        - 40-59: Possibly duplicate (significant differences)
        - 0-39: Not a duplicate
        """
        
        let url = URL(string: "https://api.openai.com/v1/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(AppConfig.openAIAPIKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let requestBody: [String: Any] = [
            "model": "gpt-4o-mini",
            "messages": [
                [
                    "role": "system",
                    "content": "You are a duplicate detection system. Always return valid JSON only."
                ],
                [
                    "role": "user",
                    "content": prompt
                ]
            ],
            "max_tokens": 300,
            "temperature": 0.3
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        ErrorLoggingService.shared.logInfo(
            "Checking for duplicates: \(itemName)",
            context: "Duplicate Detection"
        )
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw DuplicateDetectionError.requestFailed
        }
        
        // Parse response
        if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
           let choices = json["choices"] as? [[String: Any]],
           let firstChoice = choices.first,
           let message = firstChoice["message"] as? [String: Any],
           let content = message["content"] as? String {
            
            // Extract JSON from response
            let cleanContent = extractJSON(from: content)
            
            guard let contentData = cleanContent.data(using: .utf8),
                  let result = try? JSONSerialization.jsonObject(with: contentData) as? [String: Any],
                  let isDuplicate = result["isDuplicate"] as? Bool,
                  let confidence = result["confidence"] as? Int,
                  let reason = result["reason"] as? String else {
                
                ErrorLoggingService.shared.logError(
                    DuplicateDetectionError.invalidResponse,
                    context: "Duplicate Detection - Parse Error"
                )
                
                // Return safe default
                return DuplicateResult(
                    isDuplicate: false,
                    matchedItems: [],
                    confidence: 0,
                    reason: "Unable to analyze - proceeding with caution"
                )
            }
            
            // Find matched items
            let matchedNames = result["matchedItems"] as? [String] ?? []
            let matchedItems = existingItems.filter { item in
                matchedNames.contains { matchName in
                    item.name.localizedCaseInsensitiveContains(matchName) ||
                    matchName.localizedCaseInsensitiveContains(item.name)
                }
            }
            
            ErrorLoggingService.shared.logInfo(
                "Duplicate check: \(isDuplicate ? "DUPLICATE" : "UNIQUE") (confidence: \(confidence)%)",
                context: "Duplicate Detection"
            )
            
            return DuplicateResult(
                isDuplicate: isDuplicate,
                matchedItems: matchedItems,
                confidence: Double(confidence),
                reason: reason
            )
        }
        
        throw DuplicateDetectionError.invalidResponse
    }
    
    // MARK: - Helpers
    
    private func extractJSON(from text: String) -> String {
        // Remove markdown code blocks if present
        var cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if cleaned.hasPrefix("```json") {
            cleaned = cleaned.replacingOccurrences(of: "```json", with: "")
            cleaned = cleaned.replacingOccurrences(of: "```", with: "")
        } else if cleaned.hasPrefix("```") {
            cleaned = cleaned.replacingOccurrences(of: "```", with: "")
        }
        
        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - Errors

enum DuplicateDetectionError: LocalizedError {
    case requestFailed
    case invalidResponse
    case noItems
    
    var errorDescription: String? {
        switch self {
        case .requestFailed:
            return "Failed to check for duplicates"
        case .invalidResponse:
            return "Invalid response from duplicate detection"
        case .noItems:
            return "No items to compare"
        }
    }
}
