//
//  NaturalLanguageSearchService.swift
//  stashd
//
//  Created by Sean Lynch on 10/17/25.
//


//
//  NaturalLanguageSearchService.swift
//  stashd
//
//  Created by Sean Lynch
//

import Foundation
import SwiftData

@MainActor
final class NaturalLanguageSearchService {
    static let shared = NaturalLanguageSearchService()
    
    private init() {}
    
    // MARK: - Search Query Structure
    
    struct SearchQuery {
        var keywords: [String]?
        var category: CollectionCategory?
        var tags: [String]?
        var priceRange: PriceRange?
        var condition: ItemCondition?
        var dateRange: DateRange?
        var brand: String?
        var sortBy: SortOption?
    }
    
    enum PriceRange {
        case under(Decimal)
        case over(Decimal)
        case between(Decimal, Decimal)
        case expensive  // Top 20%
        case cheap      // Bottom 20%
        case average    // Middle 60%
    }
    
    enum DateRange {
        case lastWeek
        case lastMonth
        case lastYear
        case custom(Date, Date)
    }
    
    enum SortOption {
        case mostExpensive
        case cheapest
        case newest
        case oldest
        case alphabetical
    }
    
    // MARK: - Parse Natural Language Query
    
    func parseQuery(_ naturalLanguage: String) async throws -> SearchQuery {
        print("🔍 Parsing natural language query: '\(naturalLanguage)'")
        
        let prompt = """
        Parse this natural language search query into structured filters for a collectibles database:
        
        Query: "\(naturalLanguage)"
        
        Available categories: Sneakers, Vinyl Records, Books, Movies, Comics, Video Games, Trading Cards, Pokemon Cards, Sports Cards, Toys, LEGO, Fashion, Watches, Tech, Other
        
        Available conditions: Mint, Near Mint, Excellent, Good, Fair, Poor
        
        Return JSON with any relevant filters:
        {
            "keywords": ["nike", "jordan"] or null,
            "category": "Sneakers" or null,
            "tags": ["vintage", "red"] or null,
            "priceRange": "expensive" or "cheap" or "under100" or "over500" or "between100and500" or null,
            "condition": "Mint" or null,
            "dateRange": "lastWeek" or "lastMonth" or "lastYear" or null,
            "brand": "Nike" or null,
            "sortBy": "mostExpensive" or "cheapest" or "newest" or "oldest" or "alphabetical" or null
        }
        
        Examples:
        - "Show me expensive Nike sneakers" → category: "Sneakers", brand: "Nike", priceRange: "expensive"
        - "Find mint condition Warhammer from last month" → keywords: ["warhammer"], condition: "Mint", dateRange: "lastMonth"
        - "What's my most valuable item?" → sortBy: "mostExpensive"
        - "Show sealed games under $50" → category: "Video Games", priceRange: "under50", tags: ["sealed"]
        
        Be smart about inferring intent. Return ONLY valid JSON.
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
                    "content": "You are an expert at parsing natural language search queries into structured database filters. Return only valid JSON."
                ],
                [
                    "role": "user",
                    "content": prompt
                ]
            ],
            "max_tokens": 400,
            "temperature": 0.2
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        let (data, _) = try await URLSession.shared.data(for: request)
        
        if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
           let choices = json["choices"] as? [[String: Any]],
           let firstChoice = choices.first,
           let message = firstChoice["message"] as? [String: Any],
           let content = message["content"] as? String {
            
            print("🤖 AI parsed query: \(content)")
            
            let cleaned = content
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: "```json", with: "")
                .replacingOccurrences(of: "```", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            
            if let jsonData = cleaned.data(using: .utf8),
               let result = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] {
                
                return parseSearchQuery(from: result)
            }
        }
        
        throw NLSearchError.parsingFailed
    }
    
    // MARK: - Parse JSON to SearchQuery
    
    private func parseSearchQuery(from json: [String: Any]) -> SearchQuery {
        var query = SearchQuery()
        
        // Keywords
        if let keywords = json["keywords"] as? [String] {
            query.keywords = keywords.filter { !$0.isEmpty }
        }
        
        // Category
        if let categoryStr = json["category"] as? String,
           let category = CollectionCategory.allCases.first(where: { $0.rawValue.lowercased() == categoryStr.lowercased() }) {
            query.category = category
        }
        
        // Tags
        if let tags = json["tags"] as? [String] {
            query.tags = tags.filter { !$0.isEmpty }
        }
        
        // Price Range
        if let priceStr = json["priceRange"] as? String {
            query.priceRange = parsePriceRange(priceStr)
        }
        
        // Condition
        if let conditionStr = json["condition"] as? String,
           let condition = ItemCondition(rawValue: conditionStr) {
            query.condition = condition
        }
        
        // Date Range
        if let dateStr = json["dateRange"] as? String {
            query.dateRange = parseDateRange(dateStr)
        }
        
        // Brand
        if let brand = json["brand"] as? String, !brand.isEmpty {
            query.brand = brand
        }
        
        // Sort By
        if let sortStr = json["sortBy"] as? String {
            query.sortBy = parseSortOption(sortStr)
        }
        
        print("✅ Parsed query: category=\(query.category?.rawValue ?? "nil"), brand=\(query.brand ?? "nil"), price=\(String(describing: query.priceRange))")
        
        return query
    }
    
    // MARK: - Helper Parsers
    
    private func parsePriceRange(_ str: String) -> PriceRange? {
        let lower = str.lowercased()
        
        if lower == "expensive" { return .expensive }
        if lower == "cheap" { return .cheap }
        if lower == "average" { return .average }
        
        // Parse "under100", "over500", "between100and500"
        if lower.hasPrefix("under") {
            if let amount = extractNumber(from: String(lower.dropFirst(5))) {
                return .under(Decimal(amount))
            }
        }
        
        if lower.hasPrefix("over") {
            if let amount = extractNumber(from: String(lower.dropFirst(4))) {
                return .over(Decimal(amount))
            }
        }
        
        if lower.contains("between") && lower.contains("and") {
            let components = lower.replacingOccurrences(of: "between", with: "").split(separator: "a")
            if components.count == 2,
               let min = extractNumber(from: String(components[0])),
               let max = extractNumber(from: String(components[1])) {
                return .between(Decimal(min), Decimal(max))
            }
        }
        
        return nil
    }
    
    private func parseDateRange(_ str: String) -> DateRange? {
        switch str.lowercased() {
        case "lastweek": return .lastWeek
        case "lastmonth": return .lastMonth
        case "lastyear": return .lastYear
        default: return nil
        }
    }
    
    private func parseSortOption(_ str: String) -> SortOption? {
        switch str.lowercased() {
        case "mostexpensive": return .mostExpensive
        case "cheapest": return .cheapest
        case "newest": return .newest
        case "oldest": return .oldest
        case "alphabetical": return .alphabetical
        default: return nil
        }
    }
    
    private func extractNumber(from str: String) -> Int? {
        let digits = str.filter { $0.isNumber }
        return Int(digits)
    }
    
    // MARK: - Execute Search
    
    func search(
        query: SearchQuery,
        in collections: [CollectionModel],
        context: ModelContext
    ) -> [CollectionItem] {
        
        print("🔍 Executing search with filters...")
        
        // Get all items from all collections
        var allItems: [CollectionItem] = []
        for collection in collections {
            if let items = collection.items {
                allItems.append(contentsOf: items)
            }
        }
        
        print("📦 Total items to search: \(allItems.count)")
        
        var results = allItems
        
        // Filter by category
        if let category = query.category {
            results = results.filter { $0.collection.categoryEnum == category }
            print("🏷️ After category filter: \(results.count)")
        }
        
        // Filter by keywords
        if let keywords = query.keywords, !keywords.isEmpty {
            results = results.filter { item in
                keywords.contains { keyword in
                    item.name.lowercased().contains(keyword.lowercased()) ||
                    (item.notes?.lowercased().contains(keyword.lowercased()) ?? false)
                }
            }
            print("🔤 After keyword filter: \(results.count)")
        }
        
        // Filter by brand
        if let brand = query.brand {
            results = results.filter { item in
                item.name.lowercased().contains(brand.lowercased())
            }
            print("🏢 After brand filter: \(results.count)")
        }
        
        // Filter by tags
        if let tags = query.tags, !tags.isEmpty {
            results = results.filter { item in
                tags.contains { tag in
                    item.tags.contains { itemTag in
                        itemTag.lowercased().contains(tag.lowercased())
                    }
                }
            }
            print("🏷️ After tag filter: \(results.count)")
        }
        
        // Filter by condition
        if let condition = query.condition {
            results = results.filter { $0.condition == condition }
            print("⭐ After condition filter: \(results.count)")
        }
        
        // Filter by price range
        if let priceRange = query.priceRange {
            results = filterByPriceRange(results, range: priceRange)
            print("💰 After price filter: \(results.count)")
        }
        
        // Filter by date range
        if let dateRange = query.dateRange {
            results = filterByDateRange(results, range: dateRange)
            print("📅 After date filter: \(results.count)")
        }
        
        // Sort results
        if let sortBy = query.sortBy {
            results = sortResults(results, by: sortBy)
            print("📊 Sorted by: \(sortBy)")
        }
        
        print("✅ Final results: \(results.count) items")
        
        return results
    }
    
    // MARK: - Filter Helpers
    
    private func filterByPriceRange(_ items: [CollectionItem], range: PriceRange) -> [CollectionItem] {
        switch range {
        case .under(let amount):
            return items.filter { $0.estimatedValue < amount }
            
        case .over(let amount):
            return items.filter { $0.estimatedValue > amount }
            
        case .between(let min, let max):
            return items.filter { $0.estimatedValue >= min && $0.estimatedValue <= max }
            
        case .expensive:
            let sorted = items.sorted { $0.estimatedValue > $1.estimatedValue }
            let topCount = max(1, sorted.count / 5) // Top 20%
            return Array(sorted.prefix(topCount))
            
        case .cheap:
            let sorted = items.sorted { $0.estimatedValue < $1.estimatedValue }
            let bottomCount = max(1, sorted.count / 5) // Bottom 20%
            return Array(sorted.prefix(bottomCount))
            
        case .average:
            let sorted = items.sorted { $0.estimatedValue < $1.estimatedValue }
            let skip = sorted.count / 5 // Skip bottom 20%
            let take = (sorted.count * 3) / 5 // Take middle 60%
            return Array(sorted.dropFirst(skip).prefix(take))
        }
    }
    
    private func filterByDateRange(_ items: [CollectionItem], range: DateRange) -> [CollectionItem] {
        let now = Date()
        let calendar = Calendar.current
        
        switch range {
        case .lastWeek:
            let weekAgo = calendar.date(byAdding: .day, value: -7, to: now)!
            return items.filter { $0.createdAt >= weekAgo }
            
        case .lastMonth:
            let monthAgo = calendar.date(byAdding: .month, value: -1, to: now)!
            return items.filter { $0.createdAt >= monthAgo }
            
        case .lastYear:
            let yearAgo = calendar.date(byAdding: .year, value: -1, to: now)!
            return items.filter { $0.createdAt >= yearAgo }
            
        case .custom(let start, let end):
            return items.filter { $0.createdAt >= start && $0.createdAt <= end }
        }
    }
    
    private func sortResults(_ items: [CollectionItem], by option: SortOption) -> [CollectionItem] {
        switch option {
        case .mostExpensive:
            return items.sorted { $0.estimatedValue > $1.estimatedValue }
            
        case .cheapest:
            return items.sorted { $0.estimatedValue < $1.estimatedValue }
            
        case .newest:
            return items.sorted { $0.createdAt > $1.createdAt }
            
        case .oldest:
            return items.sorted { $0.createdAt < $1.createdAt }
            
        case .alphabetical:
            return items.sorted { $0.name < $1.name }
        }
    }
}

// MARK: - Errors

enum NLSearchError: LocalizedError {
    case parsingFailed
    case noResults
    
    var errorDescription: String? {
        switch self {
        case .parsingFailed: return "Could not understand search query"
        case .noResults: return "No items match your search"
        }
    }
}