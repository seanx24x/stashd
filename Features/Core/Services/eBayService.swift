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
    
    private let appID = "YOUR_EBAY_APP_ID_HERE"  // ← REPLACE WITH YOUR APP ID
    private let certID = "YOUR_EBAY_CERT_ID_HERE"  // ← REPLACE WITH YOUR CERT ID
    
    // Use sandbox for testing, production for live
    private let findingEndpoint = "https://svcs.ebay.com/services/search/FindingService/v1"
    
    private init() {}
    
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
    
    func searchItem(query: String, condition: String? = nil) async throws -> [PriceInfo] {
        var components = URLComponents(string: findingEndpoint)!
        
        var queryItems = [
            URLQueryItem(name: "OPERATION-NAME", value: "findCompletedItems"),
            URLQueryItem(name: "SERVICE-VERSION", value: "1.0.0"),
            URLQueryItem(name: "SECURITY-APPNAME", value: appID),
            URLQueryItem(name: "RESPONSE-DATA-FORMAT", value: "JSON"),
            URLQueryItem(name: "keywords", value: query),
            URLQueryItem(name: "paginationInput.entriesPerPage", value: "20"),
            URLQueryItem(name: "sortOrder", value: "EndTimeSoonest")
        ]
        
        if let condition {
            queryItems.append(URLQueryItem(name: "itemFilter(0).name", value: "Condition"))
            queryItems.append(URLQueryItem(name: "itemFilter(0).value", value: mapCondition(condition)))
        }
        
        components.queryItems = queryItems
        
        guard let url = components.url else {
            throw eBayError.invalidURL
        }
        
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw eBayError.requestFailed
        }
        
        let decoder = JSONDecoder()
        let searchResponse = try decoder.decode(eBaySearchResponse.self, from: data)
        
        guard let searchResult = searchResponse.findCompletedItemsResponse.first?.searchResult.first,
              let items = searchResult.item else {
            return []
        }
        
        return items.compactMap { item -> PriceInfo? in
            guard let title = item.title?.first,
                  let currentPriceValue = item.sellingStatus?.first?.currentPrice?.first?.value,
                  let currentPrice = Double(currentPriceValue),
                  let currency = item.sellingStatus?.first?.currentPrice?.first?.currencyId else {
                return nil
            }
            
            let shippingCostValue = item.shippingInfo?.first?.shippingServiceCost?.first?.value
            let shippingCost = shippingCostValue.flatMap { Double($0) }
            
            return PriceInfo(
                title: title,
                currentPrice: currentPrice,
                currency: currency,
                condition: item.condition?.first?.conditionDisplayName?.first ?? "Unknown",
                imageURL: item.galleryURL?.first,
                listingURL: item.viewItemURL?.first ?? "",
                location: item.location?.first,
                shippingCost: shippingCost
            )
        }
    }
    
    func analyzePrices(for itemName: String, condition: String? = nil) async throws -> PriceAnalysis {
        let results = try await searchItem(query: itemName, condition: condition)
        
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
    
    private func mapCondition(_ condition: String) -> String {
        switch condition.lowercased() {
        case "mint":
            return "1000"
        case "near mint", "excellent":
            return "1500"
        case "good":
            return "3000"
        case "fair":
            return "4000"
        case "poor":
            return "5000"
        default:
            return "3000"
        }
    }
}

// MARK: - Response Models

struct eBaySearchResponse: Codable {
    let findCompletedItemsResponse: [FindCompletedItemsResponse]
}

struct FindCompletedItemsResponse: Codable {
    let searchResult: [SearchResult]
}

struct SearchResult: Codable {
    let item: [eBayItem]?
}

struct eBayItem: Codable {
    let title: [String]?
    let viewItemURL: [String]?
    let galleryURL: [String]?
    let location: [String]?
    let sellingStatus: [SellingStatus]?
    let shippingInfo: [ShippingInfo]?
    let condition: [ItemConditionInfo]?
}

struct SellingStatus: Codable {
    let currentPrice: [PriceValue]?
}

struct PriceValue: Codable {
    let value: String?
    let currencyId: String?
    
    enum CodingKeys: String, CodingKey {
        case value = "__value__"
        case currencyId = "@currencyId"
    }
}

struct ShippingInfo: Codable {
    let shippingServiceCost: [PriceValue]?
}

struct ItemConditionInfo: Codable {
    let conditionDisplayName: [String]?
}

enum eBayError: LocalizedError {
    case invalidURL
    case requestFailed
    case noResultsFound
    case invalidResponse
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid eBay URL"
        case .requestFailed:
            return "eBay request failed"
        case .noResultsFound:
            return "No price data found"
        case .invalidResponse:
            return "Invalid eBay response"
        }
    }
}
