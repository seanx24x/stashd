//
//  SmartPriceService.swift
//  stashd
//
//  Created by Sean Lynch
//

import Foundation
import SwiftData

// MARK: - Price Source Types

enum PriceSourceType: Equatable {
    case manufacturer(ManufacturerSource)
    case retailer(RetailerSource)
    case marketplace(MarketplaceSource)
    case specialty(SpecialtySource)
    
    static func == (lhs: PriceSourceType, rhs: PriceSourceType) -> Bool {
        switch (lhs, rhs) {
        case (.manufacturer(let a), .manufacturer(let b)): return a == b
        case (.retailer(let a), .retailer(let b)): return a == b
        case (.marketplace(let a), .marketplace(let b)): return a == b
        case (.specialty(let a), .specialty(let b)): return a == b
        default: return false
        }
    }
}

enum ManufacturerSource: String {
    case nike = "Nike"
    case adidas = "Adidas"
    case warhammer = "Games Workshop"
    case lego = "LEGO"
    case funko = "Funko"
    case hasbro = "Hasbro"
    case mattel = "Mattel"
    case pokemon = "Pokémon Company"
    case other = "Official Store"
    
    var baseURL: String {
        switch self {
        case .nike: return "https://www.nike.com"
        case .adidas: return "https://www.adidas.com"
        case .warhammer: return "https://www.warhammer.com"
        case .lego: return "https://www.lego.com"
        case .funko: return "https://www.funko.com"
        case .hasbro: return "https://shop.hasbro.com"
        case .mattel: return "https://shop.mattel.com"
        case .pokemon: return "https://www.pokemoncenter.com"
        case .other: return ""
        }
    }
}

enum RetailerSource: String {
    case amazon = "Amazon"
    case walmart = "Walmart"
    case target = "Target"
    case bestBuy = "Best Buy"
    case gameStop = "GameStop"
    
    var baseURL: String {
        switch self {
        case .amazon: return "https://www.amazon.com"
        case .walmart: return "https://www.walmart.com"
        case .target: return "https://www.target.com"
        case .bestBuy: return "https://www.bestbuy.com"
        case .gameStop: return "https://www.gamestop.com"
        }
    }
}

enum MarketplaceSource: String {
    case ebay = "eBay"
    case mercari = "Mercari"
    case facebook = "Facebook Marketplace"
    
    var baseURL: String {
        switch self {
        case .ebay: return "https://www.ebay.com"
        case .mercari: return "https://www.mercari.com"
        case .facebook: return "https://www.facebook.com/marketplace"
        }
    }
}

enum SpecialtySource: String {
    case stockX = "StockX"
    case goat = "GOAT"
    case tcgPlayer = "TCGPlayer"
    case cardMarket = "Cardmarket"
    case priceCharting = "PriceCharting"
    case cgc = "CGC Comics"
    case vinylMe = "VinylMe"
    
    var baseURL: String {
        switch self {
        case .stockX: return "https://stockx.com"
        case .goat: return "https://www.goat.com"
        case .tcgPlayer: return "https://www.tcgplayer.com"
        case .cardMarket: return "https://www.cardmarket.com"
        case .priceCharting: return "https://www.pricecharting.com"
        case .cgc: return "https://www.cgccomics.com"
        case .vinylMe: return "https://vinylmeplease.com"
        }
    }
}

// MARK: - Price Result Models

struct PriceInfo: Identifiable {
    let id = UUID()
    let source: String
    let sourceType: String // "MSRP", "Retail", "Market", "Resale"
    let price: Decimal
    let url: String?
    let availability: String? // "In Stock", "Out of Stock", "14 sold"
    let condition: String?
    let lastUpdated: Date
}

struct MultiSourcePriceResult {
    let msrp: PriceInfo?
    let retailPrices: [PriceInfo]
    let marketPrices: [PriceInfo]
    let specialtyPrices: [PriceInfo]
    let aiRecommendation: AIRecommendation
}

struct AIRecommendation {
    let recommendedPrice: Decimal
    let reasoning: String
    let confidence: Int // 0-100
}

// MARK: - Smart Price Service

@MainActor
final class SmartPriceService {
    static let shared = SmartPriceService()
    
    private init() {}
    
    // MARK: - Get Price Sources (AI-Powered Universal)
    
    func determineSources(for item: CollectionItem) async throws -> [PriceSourceType] {
        let collection = item.collection
        let category = collection.categoryEnum
        let itemName = item.name
        
        print("🤖 Using AI to determine best price sources for: \(itemName)")
        
        // Use AI to identify manufacturer and suggest sources
        let aiSources = try await identifySourcesWithAI(itemName: itemName, category: category.rawValue)
        
        // Always include eBay as fallback
        var sources = aiSources
        if !sources.contains(where: { if case .marketplace(.ebay) = $0 { return true }; return false }) {
            sources.append(.marketplace(.ebay))
        }
        
        return sources
    }
    
    // MARK: - AI Source Identification
    
    private func identifySourcesWithAI(itemName: String, category: String) async throws -> [PriceSourceType] {
        let prompt = """
        Identify the best price sources for this collectible item:
        
        Item: \(itemName)
        Category: \(category)
        
        Determine:
        1. The manufacturer/brand (if applicable)
        2. The best retail sources
        3. The best specialty marketplaces
        
        Return JSON:
        {
            "manufacturer": "Games Workshop" or null,
            "retailers": ["Amazon", "Target"],
            "specialty": ["StockX", "TCGPlayer"]
        }
        
        Available manufacturers: Nike, Adidas, Games Workshop, LEGO, Funko, Hasbro, Mattel, Pokémon Company
        Available retailers: Amazon, Walmart, Target, Best Buy, GameStop
        Available specialty: StockX, GOAT, TCGPlayer, Cardmarket, PriceCharting, CGC Comics, VinylMe
        
        If manufacturer not in list or unknown, set to null.
        Be smart about identifying brands from product names.
        """
        
        let url = URL(string: "https://api.openai.com/v1/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(AppConfig.openAIAPIKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let requestBody: [String: Any] = [
            "model": "gpt-4o-mini",
            "messages": [
                ["role": "system", "content": "You are a product identification expert. Return only valid JSON."],
                ["role": "user", "content": prompt]
            ],
            "max_tokens": 300,
            "temperature": 0.3
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        let (data, _) = try await URLSession.shared.data(for: request)
        
        var sources: [PriceSourceType] = []
        
        if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
           let choices = json["choices"] as? [[String: Any]],
           let firstChoice = choices.first,
           let message = firstChoice["message"] as? [String: Any],
           let content = message["content"] as? String {
            
            print("🤖 AI source identification response: \(content)")
            
            let cleaned = content
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: "```json", with: "")
                .replacingOccurrences(of: "```", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            
            if let jsonData = cleaned.data(using: .utf8),
               let result = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] {
                
                // Parse manufacturer
                if let manufacturerName = result["manufacturer"] as? String,
                   !manufacturerName.isEmpty,
                   manufacturerName.lowercased() != "null" {
                    if let manufacturer = parseManufacturer(manufacturerName) {
                        sources.append(.manufacturer(manufacturer))
                        print("✅ Manufacturer identified: \(manufacturerName)")
                    }
                }
                
                // Parse retailers
                if let retailers = result["retailers"] as? [String] {
                    for retailerName in retailers {
                        if let retailer = parseRetailer(retailerName) {
                            sources.append(.retailer(retailer))
                        }
                    }
                }
                
                // Parse specialty
                if let specialty = result["specialty"] as? [String] {
                    for specialtyName in specialty {
                        if let specialtySite = parseSpecialty(specialtyName) {
                            sources.append(.specialty(specialtySite))
                        }
                    }
                }
            }
        }
        
        print("📊 AI determined \(sources.count) sources")
        return sources
    }
    
    // MARK: - Parse Helper Functions
    
    private func parseManufacturer(_ name: String) -> ManufacturerSource? {
        let normalized = name.lowercased()
        if normalized.contains("games workshop") || normalized.contains("warhammer") {
            return .warhammer
        }
        if normalized.contains("nike") { return .nike }
        if normalized.contains("adidas") { return .adidas }
        if normalized.contains("lego") { return .lego }
        if normalized.contains("funko") { return .funko }
        if normalized.contains("hasbro") { return .hasbro }
        if normalized.contains("mattel") { return .mattel }
        if normalized.contains("pokémon") || normalized.contains("pokemon") { return .pokemon }
        return nil
    }
    
    private func parseRetailer(_ name: String) -> RetailerSource? {
        let normalized = name.lowercased()
        if normalized.contains("amazon") { return .amazon }
        if normalized.contains("walmart") { return .walmart }
        if normalized.contains("target") { return .target }
        if normalized.contains("best buy") { return .bestBuy }
        if normalized.contains("gamestop") { return .gameStop }
        return nil
    }
    
    private func parseSpecialty(_ name: String) -> SpecialtySource? {
        let normalized = name.lowercased()
        if normalized.contains("stockx") { return .stockX }
        if normalized.contains("goat") { return .goat }
        if normalized.contains("tcgplayer") || normalized.contains("tcg") { return .tcgPlayer }
        if normalized.contains("cardmarket") { return .cardMarket }
        if normalized.contains("pricecharting") { return .priceCharting }
        if normalized.contains("cgc") { return .cgc }
        if normalized.contains("vinylme") { return .vinylMe }
        return nil
    }

    // MARK: - Fetch Multi-Source Prices

    func fetchPrices(for item: CollectionItem) async throws -> MultiSourcePriceResult {
        
        print("🚨🚨🚨 NEW AI-POWERED SMARTPRICESERVICE IS RUNNING 🚨🚨🚨")
        
        // ✅ NOW ASYNC
        let sources = try await determineSources(for: item)
        
        print("🔍 Fetching prices for: \(item.name)")
        print("📊 Sources to check: \(sources.count)")
        
        for source in sources {
            print("   - \(sourceDescription(source))")
        }
        
        var msrp: PriceInfo?
        var retailPrices: [PriceInfo] = []
        var marketPrices: [PriceInfo] = []
        var specialtyPrices: [PriceInfo] = []
        
        // Fetch from each source
        for source in sources {
            print("⏳ Fetching from: \(sourceDescription(source))")
            
            do {
                let prices = try await fetchFromSource(source, item: item)
                print("✅ Got \(prices.count) prices from \(sourceDescription(source))")
                
                switch source {
                case .manufacturer:
                    msrp = prices.first
                    if let msrp = msrp {
                        print("💰 MSRP: $\(msrp.price)")
                    }
                    
                case .retailer:
                    retailPrices.append(contentsOf: prices)
                    
                case .marketplace:
                    marketPrices.append(contentsOf: prices)
                    print("🛒 Market prices: \(prices.map { "$\($0.price)" }.joined(separator: ", "))")
                    
                case .specialty:
                    specialtyPrices.append(contentsOf: prices)
                }
            } catch {
                print("❌ Failed to fetch from \(sourceDescription(source)): \(error.localizedDescription)")
                ErrorLoggingService.shared.logError(
                    error,
                    context: "Fetch price from \(sourceDescription(source))"
                )
                // Continue with other sources even if one fails
                continue
            }
        }
        
        print("📊 Final results:")
        print("   MSRP: \(msrp?.price.description ?? "none")")
        print("   Retail: \(retailPrices.count)")
        print("   Market: \(marketPrices.count)")
        print("   Specialty: \(specialtyPrices.count)")
        
        // Generate AI recommendation
        let recommendation = try await generateAIRecommendation(
            item: item,
            msrp: msrp,
            retailPrices: retailPrices,
            marketPrices: marketPrices,
            specialtyPrices: specialtyPrices
        )
        
        return MultiSourcePriceResult(
            msrp: msrp,
            retailPrices: retailPrices,
            marketPrices: marketPrices,
            specialtyPrices: specialtyPrices,
            aiRecommendation: recommendation
        )
    }
    
    // MARK: - Fetch From Individual Source
    
    private func fetchFromSource(_ source: PriceSourceType, item: CollectionItem) async throws -> [PriceInfo] {
        switch source {
        case .manufacturer(let manufacturer):
            return try await fetchFromManufacturer(manufacturer, item: item)
            
        case .retailer(let retailer):
            return try await fetchFromRetailer(retailer, item: item)
            
        case .marketplace(let marketplace):
            return try await fetchFromMarketplace(marketplace, item: item)
            
        case .specialty(let specialty):
            return try await fetchFromSpecialty(specialty, item: item)
        }
    }
    
    // MARK: - Source-Specific Fetchers
    
    private func fetchFromManufacturer(_ manufacturer: ManufacturerSource, item: CollectionItem) async throws -> [PriceInfo] {
        do {
            let estimatedMSRP = try await estimateMSRP(item: item, manufacturer: manufacturer)
            
            return [
                PriceInfo(
                    source: manufacturer.rawValue,
                    sourceType: "MSRP",
                    price: estimatedMSRP,
                    url: manufacturer.baseURL,
                    availability: "In Stock at Official Store",
                    condition: "New",
                    lastUpdated: Date()
                )
            ]
        } catch {
            // ✅ GRACEFUL FALLBACK: Show manufacturer card with link
            print("ℹ️ MSRP unavailable, showing manufacturer info card")
            return [
                PriceInfo(
                    source: manufacturer.rawValue,
                    sourceType: "Official Retailer",
                    price: 0, // Special: 0 = show "Visit Store" instead
                    url: manufacturer.baseURL,
                    availability: "Check for current pricing",
                    condition: "New",
                    lastUpdated: Date()
                )
            ]
        }
    }
    
    private func fetchFromRetailer(_ retailer: RetailerSource, item: CollectionItem) async throws -> [PriceInfo] {
        // Future: Implement retailer scraping
        return []
    }
    
    private func fetchFromMarketplace(_ marketplace: MarketplaceSource, item: CollectionItem) async throws -> [PriceInfo] {
        if marketplace == .ebay {
            return try await fetchFromEbay(item: item)
        }
        return []
    }
    
    private func fetchFromSpecialty(_ specialty: SpecialtySource, item: CollectionItem) async throws -> [PriceInfo] {
        // Future: Implement specialty site scraping
        return []
    }
    
    // MARK: - eBay Integration
    
    private func fetchFromEbay(item: CollectionItem) async throws -> [PriceInfo] {
        let ebayResults = try await eBayService.shared.searchItem(
            query: item.name,
            condition: item.condition?.rawValue
        )
        
        return ebayResults.map { result in
            PriceInfo(
                source: "eBay",
                sourceType: "Market",
                price: Decimal(result.currentPrice),
                url: result.listingURL,
                availability: "\(ebayResults.count) sold recently",
                condition: result.condition,
                lastUpdated: Date()
            )
        }
    }
    
    // MARK: - AI-Powered Real MSRP Lookup

    private func estimateMSRP(item: CollectionItem, manufacturer: ManufacturerSource) async throws -> Decimal {
        print("🔍 Looking up real MSRP for: \(item.name)")
        
        // ✅ Try up to 2 times
        for attempt in 1...2 {
            do {
                print("🔄 Attempt \(attempt)/2")
                
                // Step 1: Search for the product URL
                guard let productURL = try await WebScraperService.shared.searchProductURL(
                    productName: item.name,
                    manufacturer: manufacturer.rawValue,
                    manufacturerURL: manufacturer.baseURL
                ) else {
                    print("⚠️ Could not find product URL")
                    if attempt < 2 {
                        print("🔄 Retrying...")
                        try await Task.sleep(nanoseconds: 2_000_000_000)
                        continue
                    }
                    throw SmartPriceError.estimationFailed
                }
                
                // Step 2: Fetch the HTML
                let html = try await WebScraperService.shared.fetchHTML(from: productURL)
                
                // Step 3: Extract price using AI
                if let price = try await WebScraperService.shared.extractPrice(
                    from: html,
                    productName: item.name
                ) {
                    print("✅ Found real MSRP: $\(price)")
                    return price
                }
                
                print("⚠️ Could not extract price from page")
                
                if attempt < 2 {
                    print("🔄 Retrying...")
                    try await Task.sleep(nanoseconds: 2_000_000_000)
                }
                
            } catch {
                print("❌ Attempt \(attempt) failed: \(error.localizedDescription)")
                
                if attempt < 2 {
                    print("🔄 Retrying in 2 seconds...")
                    try await Task.sleep(nanoseconds: 2_000_000_000)
                } else {
                    throw error
                }
            }
        }
        
        throw SmartPriceError.estimationFailed
    }
    
    // MARK: - AI Recommendation
    
    private func generateAIRecommendation(
        item: CollectionItem,
        msrp: PriceInfo?,
        retailPrices: [PriceInfo],
        marketPrices: [PriceInfo],
        specialtyPrices: [PriceInfo]
    ) async throws -> AIRecommendation {
        
        let allPrices = [msrp].compactMap { $0 } + retailPrices + marketPrices + specialtyPrices
        
        guard !allPrices.isEmpty else {
            return AIRecommendation(
                recommendedPrice: item.estimatedValue,
                reasoning: "Unable to fetch current market prices. Using your estimated value.",
                confidence: 50
            )
        }
        
        let pricesSummary = allPrices.map { "\($0.sourceType) (\($0.source)): $\($0.price)" }.joined(separator: "\n")
        
        let prompt = """
        Analyze these prices and recommend a fair market value:
        
        Item: \(item.name)
        Condition: \(item.condition?.rawValue ?? "Unknown")
        
        Available Prices:
        \(pricesSummary)
        
        Return JSON:
        {
            "recommendedPrice": 45.00,
            "reasoning": "Brief explanation",
            "confidence": 85
        }
        
        Consider: condition, source reliability, market trends.
        """
        
        let url = URL(string: "https://api.openai.com/v1/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(AppConfig.openAIAPIKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let requestBody: [String: Any] = [
            "model": "gpt-4o-mini",
            "messages": [
                ["role": "system", "content": "You are a pricing analyst. Return only valid JSON."],
                ["role": "user", "content": prompt]
            ],
            "max_tokens": 200,
            "temperature": 0.5
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        let (data, _) = try await URLSession.shared.data(for: request)
        
        if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
           let choices = json["choices"] as? [[String: Any]],
           let firstChoice = choices.first,
           let message = firstChoice["message"] as? [String: Any],
           let content = message["content"] as? String {
            
            let cleaned = content.trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: "```json", with: "")
                .replacingOccurrences(of: "```", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            
            if let jsonData = cleaned.data(using: .utf8),
               let result = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
               let price = result["recommendedPrice"] as? Double,
               let reasoning = result["reasoning"] as? String,
               let confidence = result["confidence"] as? Int {
                
                return AIRecommendation(
                    recommendedPrice: Decimal(price),
                    reasoning: reasoning,
                    confidence: confidence
                )
            }
        }
        
        // Fallback to average
        let avgPrice = allPrices.reduce(Decimal(0)) { $0 + $1.price } / Decimal(allPrices.count)
        return AIRecommendation(
            recommendedPrice: avgPrice,
            reasoning: "Based on average of available prices.",
            confidence: 70
        )
    }
    
    private func sourceDescription(_ source: PriceSourceType) -> String {
        switch source {
        case .manufacturer(let m): return m.rawValue
        case .retailer(let r): return r.rawValue
        case .marketplace(let m): return m.rawValue
        case .specialty(let s): return s.rawValue
        }
    }
}

// MARK: - Errors

enum SmartPriceError: LocalizedError {
    case estimationFailed
    case noSourcesAvailable
    case allSourcesFailed
    
    var errorDescription: String? {
        switch self {
        case .estimationFailed: return "Failed to estimate price"
        case .noSourcesAvailable: return "No price sources available for this item"
        case .allSourcesFailed: return "All price sources failed to respond"
        }
    }
}
