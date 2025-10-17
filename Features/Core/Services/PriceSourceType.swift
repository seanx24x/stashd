//
//  SmartPriceService.swift
//  stashd
//
//  Created by Sean Lynch
//

import Foundation
import SwiftData

// MARK: - Price Source Types

enum PriceSourceType {
    case manufacturer(ManufacturerSource)
    case retailer(RetailerSource)
    case marketplace(MarketplaceSource)
    case specialty(SpecialtySource)
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
    
    // MARK: - Get Price Sources
    
    func determineSources(for item: CollectionItem) -> [PriceSourceType] {
        let collection = item.collection  // ✅ FIX: No unwrapping needed
        let category = collection.categoryEnum
        let itemName = item.name.lowercased()
        
        switch category {
        case .sneakers:
            return [
                .manufacturer(detectShoeBrand(itemName)),
                .specialty(.stockX),
                .specialty(.goat),
                .marketplace(.ebay)
            ]
            
        case .toys where itemName.contains("warhammer"):
            return [
                .manufacturer(.warhammer),
                .retailer(.amazon),
                .marketplace(.ebay)
            ]
            
        case .toys where itemName.contains("lego"):
            return [
                .manufacturer(.lego),
                .retailer(.amazon),
                .retailer(.target),
                .marketplace(.ebay)
            ]
            
        case .toys where itemName.contains("funko"):
            return [
                .manufacturer(.funko),
                .retailer(.amazon),
                .marketplace(.ebay)
            ]
            
        case .tradingCards, .pokemonCards, .sportsCards:
            return [
                .specialty(.tcgPlayer),
                .marketplace(.ebay),
                .retailer(.amazon)
            ]
            
        case .comics:
            return [
                .specialty(.cgc),
                .marketplace(.ebay),
                .retailer(.amazon)
            ]
            
        case .videoGames:
            return [
                .specialty(.priceCharting),
                .retailer(.gameStop),
                .marketplace(.ebay)
            ]
            
        case .vinyl:
            return [
                .specialty(.vinylMe),
                .retailer(.amazon),
                .marketplace(.ebay)
            ]
            
        case .movies, .books:
            return [
                .retailer(.amazon),
                .retailer(.bestBuy),
                .marketplace(.ebay)
            ]
            
        default:
            return [
                .retailer(.amazon),
                .marketplace(.ebay)
            ]
        }
    }
    
    // MARK: - Fetch Multi-Source Prices

    func fetchPrices(for item: CollectionItem) async throws -> MultiSourcePriceResult {
        let sources = determineSources(for: item)
        
        
        
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
        // For now, use AI to estimate MSRP
        // Later we can add web scraping for specific manufacturers
        let estimatedMSRP = try await estimateMSRP(item: item, manufacturer: manufacturer)
        
        return [
            PriceInfo(
                source: manufacturer.rawValue,
                sourceType: "MSRP",
                price: estimatedMSRP,
                url: manufacturer.baseURL,
                availability: "Check Official Store",
                condition: "New",
                lastUpdated: Date()
            )
        ]
    }
    
    private func fetchFromRetailer(_ retailer: RetailerSource, item: CollectionItem) async throws -> [PriceInfo] {
        // Use AI to search and extract prices
        // For MVP, we'll estimate based on MSRP + typical markup
        return []
    }
    
    private func fetchFromMarketplace(_ marketplace: MarketplaceSource, item: CollectionItem) async throws -> [PriceInfo] {
        // Use existing eBay service for eBay
        if marketplace == .ebay {
            return try await fetchFromEbay(item: item)
        }
        return []
    }
    
    private func fetchFromSpecialty(_ specialty: SpecialtySource, item: CollectionItem) async throws -> [PriceInfo] {
        // Specialty sites - will implement based on priority
        return []
    }
    
    // MARK: - eBay Integration (Existing)
    
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
        
        do {
            // Step 1: Search for the product URL
            guard let productURL = try await WebScraperService.shared.searchProductURL(
                productName: item.name,
                manufacturer: manufacturer.rawValue,
                manufacturerURL: manufacturer.baseURL
            ) else {
                print("⚠️ Could not find product URL")
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
            throw SmartPriceError.estimationFailed
            
        } catch {
            print("❌ MSRP lookup failed: \(error.localizedDescription)")
            throw error
        }
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
    
    // MARK: - Brand Detection
    
    private func detectShoeBrand(_ itemName: String) -> ManufacturerSource {
        let name = itemName.lowercased()
        if name.contains("nike") || name.contains("jordan") { return .nike }
        if name.contains("adidas") || name.contains("yeezy") { return .adidas }
        return .other
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
