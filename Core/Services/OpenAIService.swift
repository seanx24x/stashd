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
        // Convert image to base64
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            throw OpenAIError.invalidImage
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
            throw OpenAIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        // Make request
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw OpenAIError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            if let errorString = String(data: data, encoding: .utf8) {
                print("OpenAI Error: \(errorString)")
            }
            throw OpenAIError.apiError(statusCode: httpResponse.statusCode)
        }
        
        // Parse response
        let openAIResponse = try JSONDecoder().decode(OpenAIResponse.self, from: data)
        
        guard let content = openAIResponse.choices.first?.message.content else {
            throw OpenAIError.noContent
        }
        
        // Extract JSON from response
        let jsonString = extractJSON(from: content)
        guard let jsonData = jsonString.data(using: .utf8) else {
            throw OpenAIError.invalidJSON
        }
        
        let analysis = try JSONDecoder().decode(ItemAnalysis.self, from: jsonData)
        return analysis
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
        let apiKey = self.apiKey
        
        guard !apiKey.isEmpty else {
            throw OpenAIError.invalidAPIKey
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
        
        // Make the API call
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw OpenAIError.requestFailed
        }
        
        // Parse the response
        if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
           let choices = json["choices"] as? [[String: Any]],
           let firstChoice = choices.first,
           let message = firstChoice["message"] as? [String: Any],
           let description = message["content"] as? String {
            return description.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        throw OpenAIError.invalidResponse
    }
    
    // MARK: - Smart Tag Generation
    
    func generateSmartTags(
        itemName: String,
        category: String,
        description: String?
    ) async throws -> [String] {
        let apiKey = self.apiKey
        
        guard !apiKey.isEmpty else {
            throw OpenAIError.invalidAPIKey
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
        
        // Make the API call
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
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
            
            return tags
        }
        
        throw OpenAIError.invalidResponse
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
