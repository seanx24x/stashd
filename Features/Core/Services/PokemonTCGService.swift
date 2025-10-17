//
//  PokemonTCGService.swift
//  stashd
//
//  Created by Sean Lynch on 10/17/25.
//


//
//  PokemonTCGService.swift
//  stashd
//
//  Created by Sean Lynch
//

import Foundation

@MainActor
final class PokemonTCGService {
    static let shared = PokemonTCGService()
    
    private let baseURL = "https://api.pokemontcg.io/v2"
    
    private init() {}
    
    // MARK: - Models
    
    struct CardSearchResult: Codable {
        let data: [Card]
        let page: Int
        let pageSize: Int
        let count: Int
        let totalCount: Int
    }
    
    struct Card: Codable, Identifiable {
        let id: String
        let name: String
        let supertype: String
        let subtypes: [String]?
        let hp: String?
        let types: [String]?
        let rarity: String?
        let artist: String?
        let number: String
        let set: CardSet
        let images: CardImages
        let tcgplayer: TCGPlayerPrices?
        let cardmarket: CardMarketPrices?
        
        var displayName: String {
            "\(name) - \(set.name) #\(number)"
        }
        
        var estimatedValue: Double? {
            tcgplayer?.prices?.holofoil?.market ?? 
            tcgplayer?.prices?.normal?.market ??
            tcgplayer?.prices?.reverseHolofoil?.market ??
            cardmarket?.prices?.averageSellPrice
        }
    }
    
    struct CardSet: Codable {
        let id: String
        let name: String
        let series: String
        let printedTotal: Int?
        let total: Int
        let releaseDate: String
        let images: SetImages
    }
    
    struct CardImages: Codable {
        let small: String
        let large: String
    }
    
    struct SetImages: Codable {
        let symbol: String
        let logo: String
    }
    
    struct TCGPlayerPrices: Codable {
        let url: String?
        let updatedAt: String?
        let prices: PriceVariants?
    }
    
    struct PriceVariants: Codable {
        let normal: PriceData?
        let holofoil: PriceData?
        let reverseHolofoil: PriceData?
        let firstEdition: PriceData?
        let firstEditionHolofoil: PriceData?
    }
    
    struct PriceData: Codable {
        let low: Double?
        let mid: Double?
        let high: Double?
        let market: Double?
        let directLow: Double?
    }
    
    struct CardMarketPrices: Codable {
        let url: String?
        let updatedAt: String?
        let prices: CardMarketPriceData?
    }
    
    struct CardMarketPriceData: Codable {
        let averageSellPrice: Double?
        let lowPrice: Double?
        let trendPrice: Double?
        let averageSellPrice1: Double?
        let averageSellPrice7: Double?
        let averageSellPrice30: Double?
    }
    
    // MARK: - Search Cards
    
    func searchCards(query: String, page: Int = 1, pageSize: Int = 20) async throws -> CardSearchResult {
        print("🔍 Searching Pokemon TCG: '\(query)'")
        
        guard var components = URLComponents(string: "\(baseURL)/cards") else {
            throw PokemonTCGError.invalidURL
        }
        
        components.queryItems = [
            URLQueryItem(name: "q", value: "name:\(query)*"),
            URLQueryItem(name: "page", value: "\(page)"),
            URLQueryItem(name: "pageSize", value: "\(pageSize)"),
            URLQueryItem(name: "orderBy", value: "-set.releaseDate")
        ]
        
        guard let url = components.url else {
            throw PokemonTCGError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw PokemonTCGError.networkError
        }
        
        print("📥 Pokemon TCG API Status: \(httpResponse.statusCode)")
        
        guard httpResponse.statusCode == 200 else {
            throw PokemonTCGError.apiError(httpResponse.statusCode)
        }
        
        let decoder = JSONDecoder()
        let result = try decoder.decode(CardSearchResult.self, from: data)
        
        print("✅ Found \(result.data.count) cards")
        
        return result
    }
    
    // MARK: - Get Card by ID
    
    func getCard(id: String) async throws -> Card {
        print("🔍 Fetching Pokemon card: \(id)")
        
        guard let url = URL(string: "\(baseURL)/cards/\(id)") else {
            throw PokemonTCGError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw PokemonTCGError.networkError
        }
        
        let decoder = JSONDecoder()
        let result = try decoder.decode(CardResponse.self, from: data)
        
        print("✅ Fetched card: \(result.data.name)")
        
        return result.data
    }
    
    private struct CardResponse: Codable {
        let data: Card
    }
    
    // MARK: - Get Sets
    
    func getSets() async throws -> [CardSet] {
        print("🔍 Fetching Pokemon TCG sets")
        
        guard let url = URL(string: "\(baseURL)/sets") else {
            throw PokemonTCGError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw PokemonTCGError.networkError
        }
        
        let decoder = JSONDecoder()
        let result = try decoder.decode(SetResponse.self, from: data)
        
        print("✅ Fetched \(result.data.count) sets")
        
        return result.data
    }
    
    private struct SetResponse: Codable {
        let data: [CardSet]
    }
}

// MARK: - Errors

enum PokemonTCGError: LocalizedError {
    case invalidURL
    case networkError
    case apiError(Int)
    case decodingError
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid API URL"
        case .networkError:
            return "Network connection failed"
        case .apiError(let code):
            return "API error (status: \(code))"
        case .decodingError:
            return "Failed to decode response"
        }
    }
}