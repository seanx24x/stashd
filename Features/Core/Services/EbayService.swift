//
//  eBayService.swift
//  stashd
//
//  Created by Sean Lynch on 10/12/25.
//

// File: Core/Services/eBayService.swift

import Foundation

@MainActor
final class eBayService {
    static let shared = eBayService()
    
    private var clientID: String? { AppConfig.ebayClientID }
    private var clientSecret: String? { AppConfig.ebayClientSecret }
    
    private let baseURL = "https://api.ebay.com"
    private let authURL = "https://api.ebay.com/identity/v1/oauth2/token"
    
    private var accessToken: String?
    private var tokenExpiry: Date?
    
    private init() {}
    
    // MARK: - Authentication
    
    private func getAccessToken() async throws -> String {
        // Return cached token if valid
        if let token = accessToken,
           let expiry = tokenExpiry,
           expiry > Date() {
            return token
        }
        
        guard let clientID = clientID,
              let clientSecret = clientSecret else {
            throw eBayError.noCredentials
        }
        
        // Create OAuth request
        guard let url = URL(string: authURL) else {
            throw eBayError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        // Basic Auth header
        let credentials = "\(clientID):\(clientSecret)"
        guard let credentialsData = credentials.data(using: .utf8) else {
            throw eBayError.authFailed
        }
        let base64Credentials = credentialsData.base64EncodedString()
        request.setValue("Basic \(base64Credentials)", forHTTPHeaderField: "Authorization")
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        // Request body
        let body = "grant_type=client_credentials&scope=https://api.ebay.com/oauth/api_scope"
        request.httpBody = body.data(using: .utf8)
        
        ErrorLoggingService.shared.logInfo(
            "Requesting eBay OAuth token",
            context: "eBay API"
        )
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            ErrorLoggingService.shared.logError(
                eBayError.authFailed,
                context: "eBay OAuth"
            )
            throw eBayError.authFailed
        }
        
        let tokenResponse = try JSONDecoder().decode(EBayTokenResponse.self, from: data)
        
        // Cache token (subtract 60 seconds for safety buffer)
        self.accessToken = tokenResponse.accessToken
        self.tokenExpiry = Date().addingTimeInterval(TimeInterval(tokenResponse.expiresIn - 60))
        
        ErrorLoggingService.shared.logInfo(
            "eBay OAuth token obtained",
            context: "eBay API"
        )
        
        return tokenResponse.accessToken
    }
    
    // MARK: - Models
    
    struct PriceInfo: Identifiable {
        let id = UUID()
        let title: String
        let currentPrice: Double
        let currency: String
        let condition: String
        let imageURL: String?
        let listingURL: String
        let location: String?
        let shippingCost: Double?
        
        var formattedPrice: String {
            let formatter = NumberFormatter()
            formatter.numberStyle = .currency
            formatter.currencyCode = currency
            return formatter.string(from: NSNumber(value: currentPrice)) ?? "$\(currentPrice)"
        }
    }
    
    struct PriceAnalysis {
        let averagePrice: Double
        let lowestPrice: Double
        let highestPrice: Double
        let totalListings: Int
        let recentSales: [PriceInfo]
        let currency: String
        
        var formattedAverage: String {
            let formatter = NumberFormatter()
            formatter.numberStyle = .currency
            formatter.currencyCode = currency
            return formatter.string(from: NSNumber(value: averagePrice)) ?? "$\(averagePrice)"
        }
        
        var priceRange: String {
            let formatter = NumberFormatter()
            formatter.numberStyle = .currency
            formatter.currencyCode = currency
            let low = formatter.string(from: NSNumber(value: lowestPrice)) ?? "$\(lowestPrice)"
            let high = formatter.string(from: NSNumber(value: highestPrice)) ?? "$\(highestPrice)"
            return "\(low) - \(high)"
        }
    }
    
    // MARK: - Search Items
    
    func searchItem(query: String, condition: String? = nil, limit: Int = 20) async throws -> [PriceInfo] {
        let token = try await getAccessToken()
        
        guard !query.isEmpty else {
            throw eBayError.invalidQuery
        }
        
        // Build search URL with query parameters
        var components = URLComponents(string: "\(baseURL)/buy/browse/v1/item_summary/search")!
        
        var queryItems = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "limit", value: "\(limit)")
        ]
        
        if let condition = condition {
            queryItems.append(URLQueryItem(name: "filter", value: "conditions:{\(mapCondition(condition))}"))
        }
        
        components.queryItems = queryItems
        
        guard let url = components.url else {
            throw eBayError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        ErrorLoggingService.shared.logInfo(
            "Searching eBay: \(query)",
            context: "eBay API"
        )
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw eBayError.requestFailed
        }
        
        print("🔍 eBay API Status Code: \(httpResponse.statusCode)")
        
        guard httpResponse.statusCode == 200 else {
            if let errorString = String(data: data, encoding: .utf8) {
                print("🔍 eBay API Error Response: \(errorString)")
            }
            ErrorLoggingService.shared.logError(
                eBayError.requestFailed,
                context: "eBay API - Status \(httpResponse.statusCode)"
            )
            throw eBayError.requestFailed
        }
        
        let searchResponse = try JSONDecoder().decode(EBayBrowseResponse.self, from: data)
        
        guard let items = searchResponse.itemSummaries else {
            ErrorLoggingService.shared.logInfo(
                "No results found on eBay",
                context: "eBay API"
            )
            return []
        }
        
        let priceInfo = items.compactMap { item -> PriceInfo? in
            guard let priceValue = item.price?.value,
                  let price = Double(priceValue),
                  let currency = item.price?.currency else {
                return nil
            }
            
            let shippingCost = item.shippingOptions?.first?.shippingCost?.value.flatMap { Double($0) }
            
            return PriceInfo(
                title: item.title ?? "Unknown Item",
                currentPrice: price,
                currency: currency,
                condition: item.condition ?? "Unknown",
                imageURL: item.image?.imageUrl,
                listingURL: item.itemWebUrl ?? "",
                location: item.itemLocation?.country,
                shippingCost: shippingCost
            )
        }
        
        ErrorLoggingService.shared.logInfo(
            "Found \(priceInfo.count) items on eBay",
            context: "eBay API"
        )
        
        return priceInfo
    }
    
    // MARK: - Price Analysis
    
    func analyzePrices(for itemName: String, condition: String? = nil) async throws -> PriceAnalysis {
        let results = try await searchItem(query: itemName, condition: condition, limit: 50)
        
        guard !results.isEmpty else {
            throw eBayError.noResultsFound
        }
        
        let prices = results.map { $0.currentPrice }
        let average = prices.reduce(0, +) / Double(prices.count)
        let lowest = prices.min() ?? 0
        let highest = prices.max() ?? 0
        
        return PriceAnalysis(
            averagePrice: average,
            lowestPrice: lowest,
            highestPrice: highest,
            totalListings: results.count,
            recentSales: Array(results.prefix(5)),
            currency: results.first?.currency ?? "USD"
        )
    }
    
    // MARK: - Helpers
    
    private func mapCondition(_ condition: String) -> String {
        switch condition.lowercased() {
        case "new":
            return "NEW"
        case "like new", "near mint":
            return "LIKE_NEW"
        case "excellent":
            return "EXCELLENT"
        case "good":
            return "GOOD"
        case "acceptable":
            return "ACCEPTABLE"
        default:
            return "USED"
        }
    }
}

// MARK: - Response Models

struct EBayTokenResponse: Codable {
    let accessToken: String
    let expiresIn: Int
    let tokenType: String
    
    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case expiresIn = "expires_in"
        case tokenType = "token_type"
    }
}

struct EBayBrowseResponse: Codable {
    let total: Int?
    let itemSummaries: [EBayItemSummary]?
}

struct EBayItemSummary: Codable {
    let itemId: String?
    let title: String?
    let price: EBayPrice?
    let condition: String?
    let image: EBayImage?
    let itemWebUrl: String?
    let itemLocation: EBayLocation?
    let shippingOptions: [EBayShippingOption]?
}

struct EBayPrice: Codable {
    let value: String?
    let currency: String?
}

struct EBayImage: Codable {
    let imageUrl: String?
}

struct EBayLocation: Codable {
    let country: String?
}

struct EBayShippingOption: Codable {
    let shippingCost: EBayPrice?
}

enum eBayError: LocalizedError {
    case noCredentials
    case invalidURL
    case authFailed
    case requestFailed
    case noResultsFound
    case invalidQuery
    
    var errorDescription: String? {
        switch self {
        case .noCredentials:
            return "eBay credentials not configured"
        case .invalidURL:
            return "Invalid eBay URL"
        case .authFailed:
            return "eBay authentication failed"
        case .requestFailed:
            return "eBay request failed"
        case .noResultsFound:
            return "No price data found"
        case .invalidQuery:
            return "Invalid search query"
        }
    }
}
