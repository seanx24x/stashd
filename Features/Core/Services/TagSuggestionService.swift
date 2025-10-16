//
//  TagSuggestionService.swift
//  stashd
//
//  Created by Sean Lynch on 10/16/25.
//


//
//  TagSuggestionService.swift
//  stashd
//
//  Created by Sean Lynch
//

import Foundation
import SwiftData

@MainActor
final class TagSuggestionService {
    static let shared = TagSuggestionService()
    
    private init() {}
    
    // MARK: - Generate Tag Suggestions
    
    func suggestTags(
        for itemName: String,
        description: String?,
        category: CollectionCategory,
        existingTags: [String] = []
    ) async throws -> [String] {
        
        // Combine category-based tags with AI suggestions
        let categoryTags = getCategoryBasedTags(for: category)
        let aiTags = try await getAISuggestions(
            itemName: itemName,
            description: description,
            category: category
        )
        
        // Merge and deduplicate
        var allTags = Set(categoryTags)
        allTags.formUnion(aiTags)
        allTags.formUnion(existingTags)
        
        // Remove common/generic words
        let filtered = allTags.filter { tag in
            !commonWords.contains(tag.lowercased()) && tag.count >= 2
        }
        
        return Array(filtered).sorted()
    }
    
    // MARK: - Category-Based Tags
    
    private func getCategoryBasedTags(for category: CollectionCategory) -> [String] {
        switch category {
        case .vinyl:
            return ["Vintage", "Rare", "First Press", "Import", "Limited Edition", "Reissue"]
            
        case .sneakers:
            return ["Vintage", "Deadstock", "Retro", "Limited", "Collaboration", "OG"]
            
        case .movies:
            return ["Blu-ray", "DVD", "4K", "Criterion", "Steelbook", "Director's Cut"]
            
        case .videoGames:
            return ["Sealed", "Complete", "Cartridge Only", "Rare", "Limited", "Collector's Edition"]
            
        case .books:
            return ["First Edition", "Signed", "Hardcover", "Paperback", "Rare", "Vintage"]
            
        case .comics:
            return ["Graded", "First Appearance", "Key Issue", "Variant", "CGC", "CBCS"]
            
        case .tradingCards, .sportsCards, .pokemonCards:
            return ["Graded", "Rookie", "Autograph", "Holographic", "First Edition", "PSA"]
            
        case .toys:
            return ["Mint in Box", "Vintage", "Rare", "Limited", "Prototype", "Exclusive"]
            
        case .watches:
            return ["Automatic", "Quartz", "Vintage", "Limited Edition", "Swiss", "Chronograph"]
            
        case .tech:
            return ["Mint", "Sealed", "Refurbished", "Vintage", "Rare", "Limited"]
            
        default:
            return ["Vintage", "Rare", "Limited", "Mint", "Collectible"]
        }
    }
    
    // MARK: - AI Suggestions
    
    private func getAISuggestions(
        itemName: String,
        description: String?,
        category: CollectionCategory
    ) async throws -> [String] {
        
        let prompt = """
        Generate 5-8 relevant tags for this collectible item. Return ONLY a JSON array of strings.
        
        Item: \(itemName)
        Description: \(description ?? "None")
        Category: \(category.rawValue)
        
        Tags should be:
        - Specific and relevant
        - 1-2 words each
        - Descriptive of attributes (era, style, condition, brand, type)
        - Useful for searching/filtering
        
        Return format: ["Tag1", "Tag2", "Tag3", ...]
        
        Examples of good tags:
        - For a 1980s Nike sneaker: ["1980s", "Nike", "Retro", "Basketball", "Leather"]
        - For a vinyl record: ["Jazz", "1960s", "Blue Note", "First Press", "Original"]
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
                    "content": "You are a tagging system. Return only JSON arrays of strings."
                ],
                [
                    "role": "user",
                    "content": prompt
                ]
            ],
            "max_tokens": 150,
            "temperature": 0.7
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        ErrorLoggingService.shared.logInfo(
            "Generating tag suggestions: \(itemName)",
            context: "Tag Suggestions"
        )
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw TagSuggestionError.requestFailed
        }
        
        // Parse response
        if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
           let choices = json["choices"] as? [[String: Any]],
           let firstChoice = choices.first,
           let message = firstChoice["message"] as? [String: Any],
           let content = message["content"] as? String {
            
            // Extract JSON array
            let cleanContent = extractJSON(from: content)
            
            if let contentData = cleanContent.data(using: .utf8),
               let tags = try? JSONSerialization.jsonObject(with: contentData) as? [String] {
                
                ErrorLoggingService.shared.logInfo(
                    "Generated \(tags.count) tag suggestions",
                    context: "Tag Suggestions"
                )
                
                return tags.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            }
        }
        
        // Return empty if parsing fails
        return []
    }
    
    // MARK: - Helpers
    
    private func extractJSON(from text: String) -> String {
        var cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if cleaned.hasPrefix("```json") {
            cleaned = cleaned.replacingOccurrences(of: "```json", with: "")
            cleaned = cleaned.replacingOccurrences(of: "```", with: "")
        } else if cleaned.hasPrefix("```") {
            cleaned = cleaned.replacingOccurrences(of: "```", with: "")
        }
        
        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    // Common words to filter out
    private let commonWords = Set([
        "the", "a", "an", "and", "or", "but", "in", "on", "at", "to", "for",
        "of", "with", "by", "from", "item", "collection", "piece"
    ])
}

// MARK: - Errors

enum TagSuggestionError: LocalizedError {
    case requestFailed
    case invalidResponse
    
    var errorDescription: String? {
        switch self {
        case .requestFailed:
            return "Failed to generate tag suggestions"
        case .invalidResponse:
            return "Invalid response from tag suggestion service"
        }
    }
}