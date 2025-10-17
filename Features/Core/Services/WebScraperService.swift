//
//  WebScraperService.swift
//  stashd
//
//  Created by Sean Lynch on 10/17/25.
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
        
        // Use OpenAI with web browsing capability or better prompting
        let prompt = """
        I need to find the EXACT product page URL for this item on the official manufacturer website.
        
        Product: \(productName)
        Manufacturer: \(manufacturer)
        Official Site: \(manufacturerURL)
        
        Think step by step:
        1. What is the full product name with model/SKU if identifiable?
        2. What would be the likely URL structure for this manufacturer?
        3. Construct the most likely direct product page URL.
        
        For Games Workshop products, the URL format is typically:
        https://www.warhammer.com/en-US/shop/[product-category]/[product-name-with-hyphens]
        
        For Nike products:
        https://www.nike.com/t/[product-slug]/[sku]
        
        Return ONLY the most specific product URL you can construct.
        If you cannot determine the exact URL, return the category/search page that would contain this product.
        
        Do NOT return the homepage or main shop page.
        
        Examples of good responses:
        - https://www.warhammer.com/en-US/shop/Space-Marines-Execrator-2024
        - https://www.nike.com/t/air-jordan-1-retro-high-og/555088-134
        - https://www.lego.com/en-us/product/millennium-falcon-75192
        
        Return ONLY the URL, nothing else.
        """
        
        let url = URL(string: "https://api.openai.com/v1/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(AppConfig.openAIAPIKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let requestBody: [String: Any] = [
            "model": "gpt-4o", // ✅ Use GPT-4o for better reasoning
            "messages": [
                [
                    "role": "system",
                    "content": "You are an expert at finding product URLs on manufacturer websites. Return only the most specific product URL possible."
                ],
                [
                    "role": "user",
                    "content": prompt
                ]
            ],
            "max_tokens": 300,
            "temperature": 0.1 // ✅ Lower temperature for more precise URLs
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
            
            // ✅ Validate it's not just the homepage
            if urlString.hasSuffix("/shop") || urlString.hasSuffix("/shop/") ||
               urlString == manufacturerURL || urlString == "\(manufacturerURL)/" {
                print("⚠️ AI returned generic shop page, will try search fallback")
                return nil
            }
            
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
        
        // ✅ Add realistic browser headers to avoid blocking
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36", forHTTPHeaderField: "User-Agent")
        request.setValue("text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8", forHTTPHeaderField: "Accept")
        request.setValue("en-US,en;q=0.9", forHTTPHeaderField: "Accept-Language")
        request.setValue("gzip, deflate, br", forHTTPHeaderField: "Accept-Encoding")
        request.setValue("keep-alive", forHTTPHeaderField: "Connection")
        request.setValue("1", forHTTPHeaderField: "Upgrade-Insecure-Requests")
        
        // ✅ Add cache control
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        
        // ✅ Longer timeout for slow sites
        request.timeoutInterval = 30
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw WebScraperError.fetchFailed
            }
            
            print("📥 Response status: \(httpResponse.statusCode)")
            
            // ✅ Handle different status codes
            switch httpResponse.statusCode {
            case 200:
                break // Success!
            case 301, 302, 303, 307, 308:
                // Follow redirects manually if needed
                if let location = httpResponse.allHeaderFields["Location"] as? String {
                    print("↪️ Following redirect to: \(location)")
                    return try await fetchHTML(from: location)
                }
                throw WebScraperError.fetchFailed
            case 403:
                print("❌ 403 Forbidden - Site is blocking scrapers")
                throw WebScraperError.blocked
            case 404:
                print("❌ 404 Not Found - URL doesn't exist")
                throw WebScraperError.notFound
            case 429:
                print("❌ 429 Rate Limited - Too many requests")
                throw WebScraperError.rateLimited
            default:
                print("❌ Unexpected status code: \(httpResponse.statusCode)")
                throw WebScraperError.fetchFailed
            }
            
            guard let html = String(data: data, encoding: .utf8) else {
                throw WebScraperError.invalidHTML
            }
            
            print("✅ Fetched HTML (\(html.count) characters)")
            
            // ✅ Check if we got a valid page (not error/login page)
            if html.contains("Access Denied") || html.contains("Forbidden") {
                print("⚠️ Got access denied page")
                throw WebScraperError.blocked
            }
            
            return html
            
        } catch let error as WebScraperError {
            throw error
        } catch {
            print("❌ Network error: \(error.localizedDescription)")
            throw WebScraperError.networkError(error.localizedDescription)
        }
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
    case blocked
    case notFound
    case rateLimited
    case networkError(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid product URL"
        case .fetchFailed: return "Failed to fetch webpage"
        case .invalidHTML: return "Invalid HTML content"
        case .extractionFailed: return "Could not extract price from page"
        case .blocked: return "Website blocked scraping attempt"
        case .notFound: return "Product page not found"
        case .rateLimited: return "Too many requests - try again later"
        case .networkError(let msg): return "Network error: \(msg)"
        }
    }
}
