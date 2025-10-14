//
//  CollectionInsightsService.swift
//  stashd
//
//  Created by Sean Lynch
//

// File: Core/Services/CollectionInsightsService.swift

import Foundation

struct CollectionInsights: Codable {
    let valueAnalysis: String
    let rarityScore: String
    let completionSuggestions: [String]
    let marketTrend: String
    let topItems: [String]
    let insights: [String]
}

@MainActor
final class CollectionInsightsService {
    static let shared = CollectionInsightsService()
    
    private init() {}
    
    // Calculate basic statistics
    func calculateStats(for collection: CollectionModel) -> CollectionStats {
        let totalValue = collection.items.reduce(Decimal(0)) { $0 + $1.estimatedValue }
        let averageValue = collection.items.isEmpty ? 0 : totalValue / Decimal(collection.items.count)
        
        let itemsByCondition = Dictionary(grouping: collection.items) { $0.condition }
        let mintCount = itemsByCondition[.mint]?.count ?? 0
        
        let allTags = collection.items.flatMap { $0.tags }
        let uniqueTags = Set(allTags)
        
        let topValuedItems = collection.items
            .sorted { $0.estimatedValue > $1.estimatedValue }
            .prefix(3)
            .map { $0.name }
        
        return CollectionStats(
            totalValue: totalValue,
            averageValue: averageValue,
            itemCount: collection.items.count,
            mintConditionCount: mintCount,
            uniqueTagsCount: uniqueTags.count,
            topValuedItems: Array(topValuedItems)
        )
    }
    
    // Generate AI-powered insights
    func generateInsights(
        for collection: CollectionModel,
        stats: CollectionStats
    ) async throws -> CollectionInsights {
        let prompt = """
        Analyze this collection and provide insights in JSON format:
        
        Collection: \(collection.title)
        Category: \(collection.category.rawValue)
        Items: \(stats.itemCount)
        Total Value: $\(stats.totalValue)
        Average Item Value: $\(stats.averageValue)
        Mint Condition Items: \(stats.mintConditionCount)
        Unique Tags: \(stats.uniqueTagsCount)
        Top Items: \(stats.topValuedItems.joined(separator: ", "))
        
        Provide insights in this JSON format:
        {
            "valueAnalysis": "Brief analysis of the collection's value (1 sentence)",
            "rarityScore": "Assessment of rare items (1 sentence)",
            "completionSuggestions": ["Suggestion 1", "Suggestion 2", "Suggestion 3"],
            "marketTrend": "Current market trend for this category (1 sentence)",
            "topItems": ["Item 1 insight", "Item 2 insight"],
            "insights": ["General insight 1", "General insight 2", "General insight 3"]
        }
        
        Be encouraging, specific, and helpful. Focus on what makes this collection special.
        """
        
        let url = URL(string: "https://api.openai.com/v1/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(OpenAIService.shared.apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let requestBody: [String: Any] = [
            "model": "gpt-4o-mini",
            "messages": [
                [
                    "role": "system",
                    "content": "You are a professional collection curator and market analyst who provides insightful, encouraging analysis."
                ],
                [
                    "role": "user",
                    "content": prompt
                ]
            ],
            "max_tokens": 500,
            "temperature": 0.7
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw OpenAIError.requestFailed
        }
        
        if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
           let choices = json["choices"] as? [[String: Any]],
           let firstChoice = choices.first,
           let message = firstChoice["message"] as? [String: Any],
           let content = message["content"] as? String {
            
            // Extract JSON from response
            let jsonString = extractJSON(from: content)
            guard let jsonData = jsonString.data(using: .utf8) else {
                throw OpenAIError.invalidJSON
            }
            
            let insights = try JSONDecoder().decode(CollectionInsights.self, from: jsonData)
            return insights
        }
        
        throw OpenAIError.invalidResponse
    }
    
    // MARK: - Duplicate Detection
    
    func checkForDuplicates(
        newItemName: String,
        newItemDescription: String?,
        existingItems: [CollectionItem]
    ) async throws -> DuplicateCheckResult {
        
        // If collection is empty, no duplicates
        if existingItems.isEmpty {
            return DuplicateCheckResult(
                isDuplicate: false,
                matchedItems: [],
                confidence: 0,
                reason: nil
            )
        }
        
        let existingItemsText = existingItems.map { item in
            var text = "- \(item.name)"
            if let notes = item.notes {
                text += " (\(notes))"
            }
            return text
        }.joined(separator: "\n")
        
        let prompt = """
        Check if this new item is a duplicate of any existing items:
        
        NEW ITEM:
        Name: \(newItemName)
        Description: \(newItemDescription ?? "None")
        
        EXISTING ITEMS:
        \(existingItemsText)
        
        Return JSON:
        {
            "isDuplicate": true/false,
            "matchedItems": ["Item name 1", "Item name 2"],
            "confidence": 0-100,
            "reason": "Brief explanation"
        }
        
        Consider items duplicates if they are the same product, even with slight name variations.
        """
        
        let url = URL(string: "https://api.openai.com/v1/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(OpenAIService.shared.apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let requestBody: [String: Any] = [
            "model": "gpt-4o-mini",
            "messages": [
                [
                    "role": "system",
                    "content": "You are a duplicate detection system for collections. Be accurate but not overly strict."
                ],
                [
                    "role": "user",
                    "content": prompt
                ]
            ],
            "max_tokens": 200,
            "temperature": 0.3
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw OpenAIError.requestFailed
        }
        
        if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
           let choices = json["choices"] as? [[String: Any]],
           let firstChoice = choices.first,
           let message = firstChoice["message"] as? [String: Any],
           let content = message["content"] as? String {
            
            let jsonString = extractJSON(from: content)
            guard let jsonData = jsonString.data(using: .utf8) else {
                throw OpenAIError.invalidJSON
            }
            
            let result = try JSONDecoder().decode(DuplicateCheckResult.self, from: jsonData)
            return result
        }
        
        throw OpenAIError.invalidResponse
    }
    
    // MARK: - Completion Suggestions
    
    func generateCompletionSuggestions(
        for collection: CollectionModel
    ) async throws -> [CompletionSuggestion] {
        
        if collection.items.isEmpty {
            return []
        }
        
        let itemsList = collection.items.prefix(10).map { item in
            "- \(item.name)"
        }.joined(separator: "\n")
        
        let prompt = """
        Analyze this \(collection.category.rawValue) collection and suggest items to complete it:
        
        CURRENT ITEMS:
        \(itemsList)
        
        Collection has \(collection.items.count) total items.
        
        Suggest 3-5 items that would complement this collection well.
        
        Return JSON array:
        [
            {
                "itemName": "Suggested item name",
                "reason": "Why this would be a good addition (1 sentence)",
                "priority": "high/medium/low"
            }
        ]
        
        Focus on items that:
        1. Fit the collection theme
        2. Fill gaps in the collection
        3. Are realistically obtainable
        """
        
        let url = URL(string: "https://api.openai.com/v1/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(OpenAIService.shared.apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let requestBody: [String: Any] = [
            "model": "gpt-4o-mini",
            "messages": [
                [
                    "role": "system",
                    "content": "You are a collection curator who suggests items to complete collections."
                ],
                [
                    "role": "user",
                    "content": prompt
                ]
            ],
            "max_tokens": 400,
            "temperature": 0.7
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw OpenAIError.requestFailed
        }
        
        if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
           let choices = json["choices"] as? [[String: Any]],
           let firstChoice = choices.first,
           let message = firstChoice["message"] as? [String: Any],
           let content = message["content"] as? String {
            
            let jsonString = extractJSON(from: content)
            guard let jsonData = jsonString.data(using: .utf8) else {
                throw OpenAIError.invalidJSON
            }
            
            let suggestions = try JSONDecoder().decode([CompletionSuggestion].self, from: jsonData)
            return suggestions
        }
        
        throw OpenAIError.invalidResponse
    }
    
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
}

// MARK: - Models

struct CollectionStats {
    let totalValue: Decimal
    let averageValue: Decimal
    let itemCount: Int
    let mintConditionCount: Int
    let uniqueTagsCount: Int
    let topValuedItems: [String]
}

struct DuplicateCheckResult: Codable {
    let isDuplicate: Bool
    let matchedItems: [String]
    let confidence: Int
    let reason: String?
}

struct CompletionSuggestion: Codable {
    let itemName: String
    let reason: String
    let priority: String
}
