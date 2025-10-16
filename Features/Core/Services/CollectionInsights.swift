//
//  CollectionInsightsService.swift
//  stashd
//
//  Created by Sean Lynch
//

import Foundation
import SwiftData

// MARK: - Models

struct CollectionInsights: Codable {
    let valueAnalysis: String
    let rarityScore: String
    let completionSuggestions: [String]
    let marketTrend: String
    let topItems: [String]
    let insights: [String]
}

struct CollectionStats {
    let totalValue: Decimal
    let averageValue: Decimal
    let itemCount: Int
    let mintConditionCount: Int
    let uniqueTagsCount: Int
    let topValuedItems: [String]
    let conditionBreakdown: [ItemCondition: Int]
    let topTags: [(tag: String, count: Int)]
    let recentItems: [CollectionItem]
    let valueGrowth: ValueGrowth
}

struct ValueGrowth {
    let currentValue: Decimal
    let purchaseValue: Decimal
    let growthAmount: Decimal
    let growthPercentage: Double
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

@MainActor
final class CollectionInsightsService {
    static let shared = CollectionInsightsService()
    
    private init() {}
    
    // MARK: - Calculate Enhanced Statistics
    
    func calculateStats(for collection: CollectionModel) -> CollectionStats {
        guard let items = collection.items, !items.isEmpty else {
            return CollectionStats(
                totalValue: 0,
                averageValue: 0,
                itemCount: 0,
                mintConditionCount: 0,
                uniqueTagsCount: 0,
                topValuedItems: [],
                conditionBreakdown: [:],
                topTags: [],
                recentItems: [],
                valueGrowth: ValueGrowth(
                    currentValue: 0,
                    purchaseValue: 0,
                    growthAmount: 0,
                    growthPercentage: 0
                )
            )
        }
        
        let totalValue = items.reduce(Decimal(0)) { $0 + ($1.estimatedValue ?? 0) }
        let averageValue = totalValue / Decimal(items.count)
        
        // Condition breakdown
        let itemsByCondition = Dictionary(grouping: items) { $0.condition }
        let mintCount = itemsByCondition[.mint]?.count ?? 0
        
        var conditionBreakdown: [ItemCondition: Int] = [:]
        for item in items {
            if let condition = item.condition {
                conditionBreakdown[condition, default: 0] += 1
            }
        }
        
        // Tags analysis
        let allTags = items.flatMap { $0.tags }
        let uniqueTags = Set(allTags)
        
        var tagCounts: [String: Int] = [:]
        for item in items {
            for tag in item.tags {
                tagCounts[tag, default: 0] += 1
            }
        }
        
        let topTags = tagCounts
            .sorted { $0.value > $1.value }
            .prefix(5)
            .map { (tag: $0.key, count: $0.value) }
        
        // Top valued items
        let topValuedItems = items
            .sorted { ($0.estimatedValue ?? 0) > ($1.estimatedValue ?? 0) }
            .prefix(3)
            .map { $0.name }
        
        // Recent items
        let recentItems = items
            .sorted { $0.createdAt > $1.createdAt }
            .prefix(5)
            .map { $0 }
        
        // Value growth calculation - NOW ACCURATE!
        var totalPurchasePrice = Decimal(0)
        var itemsWithPurchasePrice = 0

        for item in items {
            if let purchasePrice = item.purchasePrice, purchasePrice > 0 {
                totalPurchasePrice += purchasePrice
                itemsWithPurchasePrice += 1
            } else {
                // No purchase price recorded, assume current value as purchase price (0% growth)
                totalPurchasePrice += (item.estimatedValue ?? 0)
            }
        }

        let growthAmount = totalValue - totalPurchasePrice
        let growthPercentage = totalPurchasePrice > 0
            ? Double(truncating: (growthAmount / totalPurchasePrice * 100) as NSDecimalNumber)
            : 0

        let valueGrowth = ValueGrowth(
            currentValue: totalValue,
            purchaseValue: totalPurchasePrice,
            growthAmount: growthAmount,
            growthPercentage: growthPercentage
        )
        
        return CollectionStats(
            totalValue: totalValue,
            averageValue: averageValue,
            itemCount: items.count,
            mintConditionCount: mintCount,
            uniqueTagsCount: uniqueTags.count,
            topValuedItems: Array(topValuedItems),
            conditionBreakdown: conditionBreakdown,
            topTags: topTags,
            recentItems: recentItems,
            valueGrowth: valueGrowth
        )
    }
    
    // MARK: - Generate AI-powered insights
    
    func generateInsights(
        for collection: CollectionModel,
        stats: CollectionStats
    ) async throws -> CollectionInsights {
        let categoryName = collection.categoryEnum.rawValue
        
        let prompt = """
        Analyze this collection and provide insights in JSON format:
        
        Collection: \(collection.title)
        Category: \(categoryName)
        Items: \(stats.itemCount)
        Total Value: $\(stats.totalValue)
        Average Item Value: $\(stats.averageValue)
        Mint Condition Items: \(stats.mintConditionCount)
        Unique Tags: \(stats.uniqueTagsCount)
        Value Growth: \(String(format: "%.1f", stats.valueGrowth.growthPercentage))%
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
        request.addValue("Bearer \(AppConfig.openAIAPIKey)", forHTTPHeaderField: "Authorization")
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
        
        ErrorLoggingService.shared.logInfo(
            "Generating AI insights for collection: \(collection.title)",
            context: "Collection Insights"
        )
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw InsightsError.requestFailed
        }
        
        if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
           let choices = json["choices"] as? [[String: Any]],
           let firstChoice = choices.first,
           let message = firstChoice["message"] as? [String: Any],
           let content = message["content"] as? String {
            
            let jsonString = extractJSON(from: content)
            guard let jsonData = jsonString.data(using: .utf8) else {
                throw InsightsError.invalidResponse
            }
            
            let insights = try JSONDecoder().decode(CollectionInsights.self, from: jsonData)
            
            ErrorLoggingService.shared.logInfo(
                "Generated insights successfully",
                context: "Collection Insights"
            )
            
            return insights
        }
        
        throw InsightsError.invalidResponse
    }
    
    // MARK: - Duplicate Detection
    
    func checkForDuplicates(
        newItemName: String,
        newItemDescription: String?,
        existingItems: [CollectionItem]
    ) async throws -> DuplicateCheckResult {
        
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
        request.addValue("Bearer \(AppConfig.openAIAPIKey)", forHTTPHeaderField: "Authorization")
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
            throw InsightsError.requestFailed
        }
        
        if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
           let choices = json["choices"] as? [[String: Any]],
           let firstChoice = choices.first,
           let message = firstChoice["message"] as? [String: Any],
           let content = message["content"] as? String {
            
            let jsonString = extractJSON(from: content)
            guard let jsonData = jsonString.data(using: .utf8) else {
                throw InsightsError.invalidResponse
            }
            
            let result = try JSONDecoder().decode(DuplicateCheckResult.self, from: jsonData)
            return result
        }
        
        throw InsightsError.invalidResponse
    }
    
    // MARK: - Completion Suggestions
    
    func generateCompletionSuggestions(
        for collection: CollectionModel
    ) async throws -> [CompletionSuggestion] {
        
        guard let items = collection.items, !items.isEmpty else {
            return []
        }
        
        let itemsList = items.prefix(10).map { item in
            "- \(item.name)"
        }.joined(separator: "\n")
        
        let categoryName = collection.categoryEnum.rawValue
        
        let prompt = """
        Analyze this \(categoryName) collection and suggest items to complete it:
        
        CURRENT ITEMS:
        \(itemsList)
        
        Collection has \(items.count) total items.
        
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
        request.addValue("Bearer \(AppConfig.openAIAPIKey)", forHTTPHeaderField: "Authorization")
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
            throw InsightsError.requestFailed
        }
        
        if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
           let choices = json["choices"] as? [[String: Any]],
           let firstChoice = choices.first,
           let message = firstChoice["message"] as? [String: Any],
           let content = message["content"] as? String {
            
            let jsonString = extractJSON(from: content)
            guard let jsonData = jsonString.data(using: .utf8) else {
                throw InsightsError.invalidResponse
            }
            
            let suggestions = try JSONDecoder().decode([CompletionSuggestion].self, from: jsonData)
            return suggestions
        }
        
        throw InsightsError.invalidResponse
    }
    
    // MARK: - Helper Methods
    
    func formatCurrency(_ value: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.maximumFractionDigits = 0
        return formatter.string(from: value as NSDecimalNumber) ?? "$\(value)"
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

// MARK: - Errors

enum InsightsError: LocalizedError {
    case requestFailed
    case invalidResponse
    case noItems
    
    var errorDescription: String? {
        switch self {
        case .requestFailed:
            return "Failed to generate insights"
        case .invalidResponse:
            return "Invalid response from insights service"
        case .noItems:
            return "No items in collection"
        }
    }
}
