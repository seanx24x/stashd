//
//  OpenAIService.swift
//  stashd
//
//  Created by Sean Lynch on 10/12/25.
//

// File: Core/Services/OpenAIService.swift

import Foundation
import UIKit

@MainActor
final class OpenAIService {
    static let shared = OpenAIService()
    
    let apiKey = AppConfig.openAIAPIKey
    private let endpoint = "https://api.openai.com/v1/chat/completions"
    
    // ✅ Rate limiter (10 calls per minute)
    private let rateLimiter = RateLimiter(maxCallsPerMinute: 10)
    
    // ✅ NEW: SSL Pinning delegate and secure session
    private let sslPinningDelegate = SSLPinningDelegate()
    private lazy var secureSession: URLSession = {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30
        return URLSession(
            configuration: configuration,
            delegate: sslPinningDelegate,
            delegateQueue: nil
        )
    }()
    
    private init() {}
    
    struct ItemAnalysis: Codable {
        let name: String
        let description: String
        let category: String
        let estimatedValue: String
        let details: [String]
        let condition: String?
    }
    
    func analyzeItem(image: UIImage) async throws -> ItemAnalysis {
        // ✅ Check rate limit FIRST
        do {
            try await rateLimiter.checkRateLimit()
        } catch {
            ErrorLoggingService.shared.logError(
                error,
                context: "OpenAI rate limit check"
            )
            throw error
        }
        
        // Convert image to base64
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            let error = OpenAIError.invalidImage
            ErrorLoggingService.shared.logError(
                error,
                context: "AI Item Analysis - Image conversion"
            )
            throw error
        }
        let base64Image = imageData.base64EncodedString()
        
        // Create request
        let messages: [[String: Any]] = [
            [
                "role": "user",
                "content": [
                    [
                        "type": "text",
                        "text": """
                        Analyze this image of a collectible item and provide detailed information in JSON format.
                        
                        Return ONLY valid JSON with this exact structure:
                        {
                            "name": "Item name (be specific, include brand/model/year if visible)",
                            "description": "Detailed 2-3 sentence description",
                            "category": "One of: Sneakers, Vinyl Records, Books, Movies, Art, Sports Cards, Comics, Toys, Fashion, Watches, Tech, Other",
                            "estimatedValue": "Price range like '$50-$100' or 'Contact dealer' if rare/unknown",
                            "details": ["Detail 1", "Detail 2", "Detail 3"],
                            "condition": "Mint/Near Mint/Good/Fair/Poor or Unknown"
                        }
                        
                        Be specific and accurate. If you can't identify something, say "Unknown [Item Type]".
                        """
                    ],
                    [
                        "type": "image_url",
                        "image_url": [
                            "url": "data:image/jpeg;base64,\(base64Image)"
                        ]
                    ]
                ]
            ]
        ]
        
        let requestBody: [String: Any] = [
            "model": "gpt-4o",
            "messages": messages,
            "max_tokens": 500
        ]
        
        guard let url = URL(string: endpoint) else {
            let error = OpenAIError.invalidURL
            ErrorLoggingService.shared.logError(
                error,
                context: "OpenAI endpoint configuration"
            )
            throw error
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        // ✅ NEW: Use secure session with SSL pinning
        do {
            let (data, response) = try await secureSession.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                let error = OpenAIError.invalidResponse
                ErrorLoggingService.shared.logNetworkError(
                    error,
                    endpoint: "OpenAI /chat/completions (analyze item)"
                )
                throw error
            }
            
            guard httpResponse.statusCode == 200 else {
                if let errorString = String(data: data, encoding: .utf8) {
                    print("OpenAI Error: \(errorString)")
                }
                let error = OpenAIError.apiError(statusCode: httpResponse.statusCode)
                ErrorLoggingService.shared.logNetworkError(
                    error,
                    endpoint: "OpenAI /chat/completions (analyze item)",
                    statusCode: httpResponse.statusCode
                )
                throw error
            }
            
            // Parse response
            let openAIResponse = try JSONDecoder().decode(OpenAIResponse.self, from: data)
            
            guard let content = openAIResponse.choices.first?.message.content else {
                let error = OpenAIError.noContent
                ErrorLoggingService.shared.logError(
                    error,
                    context: "OpenAI response parsing - no content"
                )
                throw error
            }
            
            // Extract JSON from response
            let jsonString = extractJSON(from: content)
            guard let jsonData = jsonString.data(using: .utf8) else {
                let error = OpenAIError.invalidJSON
                ErrorLoggingService.shared.logError(
                    error,
                    context: "OpenAI JSON extraction"
                )
                throw error
            }
            
            let analysis = try JSONDecoder().decode(ItemAnalysis.self, from: jsonData)
            
            ErrorLoggingService.shared.logInfo(
                "Successfully analyzed item",
                context: "OpenAI"
            )
            
            return analysis
        } catch let decodingError as DecodingError {
            ErrorLoggingService.shared.logError(
                decodingError,
                context: "OpenAI response decoding"
            )
            throw OpenAIError.invalidJSON
        } catch {
            ErrorLoggingService.shared.logNetworkError(
                error,
                endpoint: "OpenAI /chat/completions (analyze item)"
            )
            throw error
        }
    }
    
    // MARK: - Collection Description Generation
    
    func generateCollectionDescription(
        title: String,
        category: String,
        itemCount: Int,
        topItems: [String],
        totalValue: Decimal,
        dateRange: String?
    ) async throws -> String {
        // ✅ Check rate limit FIRST
        do {
            try await rateLimiter.checkRateLimit()
        } catch {
            ErrorLoggingService.shared.logError(
                error,
                context: "OpenAI rate limit check"
            )
            throw error
        }
        
        let apiKey = self.apiKey
        
        guard !apiKey.isEmpty else {
            let error = OpenAIError.invalidAPIKey
            ErrorLoggingService.shared.logError(
                error,
                context: "OpenAI API key validation"
            )
            throw error
        }
        
        // Build the prompt
        var prompt = """
        Generate a compelling 3-4 sentence description for this collection:
        
        Collection Name: \(title)
        Category: \(category)
        Number of Items: \(itemCount)
        """
        
        if !topItems.isEmpty {
            let itemsList = topItems.prefix(5).joined(separator: ", ")
            prompt += "\nNotable Items: \(itemsList)"
        }
        
        if totalValue > 0 {
            prompt += "\nEstimated Total Value: $\(totalValue)"
        }
        
        if let dateRange {
            prompt += "\nDate Range: \(dateRange)"
        }
        
        prompt += """
        
        
        Style: Write a professional but engaging description that:
        - Highlights what makes this collection special
        - Mentions the estimated value naturally
        - References notable items
        - Appeals to collectors and enthusiasts
        - Is 3-4 sentences long
        - Sounds natural, not robotic
        
        Description:
        """
        
        // Prepare the API request
        let url = URL(string: endpoint)!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let requestBody: [String: Any] = [
            "model": "gpt-4o-mini",
            "messages": [
                [
                    "role": "system",
                    "content": "You are a professional collection curator who writes engaging, accurate descriptions for collectors."
                ],
                [
                    "role": "user",
                    "content": prompt
                ]
            ],
            "max_tokens": 200,
            "temperature": 0.7
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        // ✅ NEW: Use secure session with SSL pinning
        do {
            let (data, response) = try await secureSession.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                let statusCode = (response as? HTTPURLResponse)?.statusCode
                ErrorLoggingService.shared.logNetworkError(
                    OpenAIError.requestFailed,
                    endpoint: "OpenAI /chat/completions (generate description)",
                    statusCode: statusCode
                )
                throw OpenAIError.requestFailed
            }
            
            // Parse the response
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let choices = json["choices"] as? [[String: Any]],
               let firstChoice = choices.first,
               let message = firstChoice["message"] as? [String: Any],
               let description = message["content"] as? String {
                
                ErrorLoggingService.shared.logInfo(
                    "Successfully generated collection description",
                    context: "OpenAI"
                )
                
                return description.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            
            ErrorLoggingService.shared.logError(
                OpenAIError.invalidResponse,
                context: "OpenAI description generation - invalid response format"
            )
            throw OpenAIError.invalidResponse
        } catch {
            ErrorLoggingService.shared.logNetworkError(
                error,
                endpoint: "OpenAI /chat/completions (generate description)"
            )
            throw error
        }
    }
    
    // MARK: - Smart Tag Generation
    
    func generateSmartTags(
        itemName: String,
        category: String,
        description: String?
    ) async throws -> [String] {
        // ✅ Check rate limit FIRST
        do {
            try await rateLimiter.checkRateLimit()
        } catch {
            ErrorLoggingService.shared.logError(
                error,
                context: "OpenAI rate limit check"
            )
            throw error
        }
        
        let apiKey = self.apiKey
        
        guard !apiKey.isEmpty else {
            let error = OpenAIError.invalidAPIKey
            ErrorLoggingService.shared.logError(
                error,
                context: "OpenAI API key validation"
            )
            throw error
        }
        
        // Build the prompt
        var prompt = """
        Generate 5-8 relevant tags for this collectible item:
        
        Item Name: \(itemName)
        Category: \(category)
        """
        
        if let description, !description.isEmpty {
            prompt += "\nDescription: \(description)"
        }
        
        prompt += """
        
        
        Generate tags that include:
        - Era/decade (if applicable)
        - Style/theme
        - Brand (if mentioned)
        - Color/aesthetic
        - Rarity/condition hints
        - Subcategory
        
        Return ONLY a comma-separated list of tags, nothing else.
        Example: Vintage, 1980s, Basketball, Nike, High-Top, Red & Black, Rare
        
        Tags:
        """
        
        // Prepare the API request
        let url = URL(string: endpoint)!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let requestBody: [String: Any] = [
            "model": "gpt-4o-mini",
            "messages": [
                [
                    "role": "system",
                    "content": "You are a professional collectibles curator who generates accurate, relevant tags."
                ],
                [
                    "role": "user",
                    "content": prompt
                ]
            ],
            "max_tokens": 100,
            "temperature": 0.5
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        // ✅ NEW: Use secure session with SSL pinning
        do {
            let (data, response) = try await secureSession.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                let statusCode = (response as? HTTPURLResponse)?.statusCode
                ErrorLoggingService.shared.logNetworkError(
                    OpenAIError.requestFailed,
                    endpoint: "OpenAI /chat/completions (generate tags)",
                    statusCode: statusCode
                )
                throw OpenAIError.requestFailed
            }
            
            // Parse the response
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let choices = json["choices"] as? [[String: Any]],
               let firstChoice = choices.first,
               let message = firstChoice["message"] as? [String: Any],
               let tagsString = message["content"] as? String {
                
                // Parse comma-separated tags
                let tags = tagsString
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .components(separatedBy: ",")
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
                
                ErrorLoggingService.shared.logInfo(
                    "Successfully generated \(tags.count) tags",
                    context: "OpenAI"
                )
                
                return tags
            }
            
            ErrorLoggingService.shared.logError(
                OpenAIError.invalidResponse,
                context: "OpenAI tag generation - invalid response format"
            )
            throw OpenAIError.invalidResponse
        } catch {
            ErrorLoggingService.shared.logNetworkError(
                error,
                endpoint: "OpenAI /chat/completions (generate tags)"
            )
            throw error
        }
    }
    
    // ✅ Helper to check remaining API calls
    func getRemainingCalls() async -> Int {
        await rateLimiter.getRemainingCalls()
    }
    
    private func extractJSON(from text: String) -> String {
        // Remove markdown code blocks if present
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

// MARK: - Response Models

struct OpenAIResponse: Codable {
    let choices: [Choice]
    
    struct Choice: Codable {
        let message: Message
    }
    
    struct Message: Codable {
        let content: String
    }
}

enum OpenAIError: LocalizedError {
    case invalidImage
    case invalidURL
    case invalidResponse
    case apiError(statusCode: Int)
    case noContent
    case invalidJSON
    case invalidAPIKey
    case requestFailed
    
    var errorDescription: String? {
        switch self {
        case .invalidImage:
            return "Could not process image"
        case .invalidURL:
            return "Invalid API URL"
        case .invalidResponse:
            return "Invalid response from API"
        case .apiError(let code):
            return "API error (code: \(code))"
        case .noContent:
            return "No content in response"
        case .invalidJSON:
            return "Could not parse response"
        case .invalidAPIKey:
            return "Invalid or missing API key"
        case .requestFailed:
            return "Request failed"
        }
    }
}
