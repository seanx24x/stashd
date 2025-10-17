//
//  WebScraperService.swift
//  stashd
//
//  Created by Sean Lynch on 10/17/25.
//


//
//  WebScraperService.swift
//  stashd
//
//  Created by Sean Lynch
//

import Foundation

@MainActor
final class WebScraperService {
    static let shared = WebScraperService()
    
    private init() {}
    
    // MARK: - Search for Product URL
    
    func searchProductURL(
        productName: String,
        manufacturer: String,
        manufacturerURL: String
    ) async throws -> String? {
        
        print("🔍 Searching for: \(productName) on \(manufacturer)")
        
        // Use AI to search Google and find the official product page
        let searchQuery = "\(productName) \(manufacturer) site:\(manufacturerURL)"
        
        let prompt = """
        I need to find the official product page for this item:
        
        Product: \(productName)
        Manufacturer: \(manufacturer)
        Official Site: \(manufacturerURL)
        
        Search query: "\(searchQuery)"
        
        Based on your knowledge, what would be the most likely official product URL?
        Return ONLY the URL, nothing else.
        
        If uncertain, return the manufacturer's main shop URL.
        
        Examples of good responses:
        - https://www.warhammer.com/en-US/shop/Space-Marine-Captain
        - https://www.nike.com/t/air-jordan-1-retro-high
        - https://www.lego.com/en-us/product/millennium-falcon-75192
        """
        
        let url = URL(string: "https://api.openai.com/v1/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(AppConfig.openAIAPIKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let requestBody: [String: Any] = [
            "model": "gpt-4o",
            "messages": [
                [
                    "role": "system",
                    "content": "You are a web search assistant. Return only URLs."
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
        
        let (data, _) = try await URLSession.shared.data(for: request)
        
        if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
           let choices = json["choices"] as? [[String: Any]],
           let firstChoice = choices.first,
           let message = firstChoice["message"] as? [String: Any],
           let content = message["content"] as? String {
            
            let urlString = content.trimmingCharacters(in: .whitespacesAndNewlines)
            print("🔗 Found URL: \(urlString)")
            return urlString
        }
        
        return nil
    }
    
    // MARK: - Fetch and Parse HTML
    
    func fetchHTML(from urlString: String) async throws -> String {
        print("📥 Fetching HTML from: \(urlString)")
        
        guard let url = URL(string: urlString) else {
            throw WebScraperError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X)", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 15
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw WebScraperError.fetchFailed
        }
        
        guard let html = String(data: data, encoding: .utf8) else {
            throw WebScraperError.invalidHTML
        }
        
        print("✅ Fetched HTML (\(html.count) characters)")
        return html
    }
    
    // MARK: - Extract Price from HTML using AI
    
    func extractPrice(from html: String, productName: String) async throws -> Decimal? {
        print("🤖 Extracting price from HTML using AI...")
        
        // Truncate HTML to avoid token limits (focus on relevant sections)
        let truncatedHTML = truncateHTML(html)
        
        let prompt = """
        Extract the price from this product page HTML:
        
        Product: \(productName)
        
        HTML Content:
        \(truncatedHTML)
        
        Find the product price (MSRP, retail price, or current price) and return ONLY a JSON response:
        
        {
            "price": 45.00,
            "currency": "USD",
            "found": true
        }
        
        If no price found:
        {
            "price": 0,
            "currency": "USD",
            "found": false
        }
        
        Look for:
        - Price tags, spans, or divs with class names like "price", "cost", "amount"
        - Meta tags with price information
        - JSON-LD structured data
        - Common e-commerce price patterns
        
        Return ONLY valid JSON.
        """
        
        let url = URL(string: "https://api.openai.com/v1/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(AppConfig.openAIAPIKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let requestBody: [String: Any] = [
            "model": "gpt-4o",
            "messages": [
                [
                    "role": "system",
                    "content": "You are an expert at extracting prices from HTML. Return only valid JSON."
                ],
                [
                    "role": "user",
                    "content": prompt
                ]
            ],
            "max_tokens": 300,
            "temperature": 0.1
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        let (data, _) = try await URLSession.shared.data(for: request)
        
        if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
           let choices = json["choices"] as? [[String: Any]],
           let firstChoice = choices.first,
           let message = firstChoice["message"] as? [String: Any],
           let content = message["content"] as? String {
            
            print("💬 AI extraction response: \(content)")
            
            // Parse JSON response
            let cleaned = content
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: "```json", with: "")
                .replacingOccurrences(of: "```", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            
            if let jsonData = cleaned.data(using: .utf8),
               let result = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
               let found = result["found"] as? Bool,
               found == true,
               let price = result["price"] as? Double,
               price > 0 {
                
                print("✅ Extracted price: $\(price)")
                return Decimal(price)
            }
        }
        
        print("❌ Could not extract price")
        return nil
    }
    
    // MARK: - Helper Methods
    
    private func truncateHTML(_ html: String) -> String {
        // Take first 8000 characters to avoid token limits
        // Focus on areas most likely to contain price
        let maxLength = 8000
        
        if html.count <= maxLength {
            return html
        }
        
        // Try to find price-related sections
        let priceKeywords = ["price", "cost", "buy", "cart", "product", "amount"]
        var relevantSections: [String] = []
        
        // Split HTML into chunks and find relevant sections
        let chunks = html.components(separatedBy: "\n")
        for chunk in chunks {
            let lowerChunk = chunk.lowercased()
            if priceKeywords.contains(where: { lowerChunk.contains($0) }) {
                relevantSections.append(chunk)
            }
        }
        
        let combined = relevantSections.joined(separator: "\n")
        
        if combined.count > 500 {
            return String(combined.prefix(maxLength))
        }
        
        // Fallback: just return beginning of HTML
        return String(html.prefix(maxLength))
    }
}

// MARK: - Errors

enum WebScraperError: LocalizedError {
    case invalidURL
    case fetchFailed
    case invalidHTML
    case extractionFailed
    
    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid product URL"
        case .fetchFailed: return "Failed to fetch webpage"
        case .invalidHTML: return "Invalid HTML content"
        case .extractionFailed: return "Could not extract price from page"
        }
    }
}