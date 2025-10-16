//
//  IGDBService.swift
//  stashd
//
//  Created by Sean Lynch on 10/16/25.
//


//
//  IGDBService.swift
//  stashd
//
//  Created by Sean Lynch
//

import Foundation

@MainActor
final class IGDBService {
    static let shared = IGDBService()
    
    private let baseURL = "https://api.igdb.com/v4"
    private var clientID: String? { AppConfig.igdbClientID }
    private var clientSecret: String? { AppConfig.igdbClientSecret }
    
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
            throw IGDBError.noCredentials
        }
        
        let urlString = "https://id.twitch.tv/oauth2/token?client_id=\(clientID)&client_secret=\(clientSecret)&grant_type=client_credentials"
        
        guard let url = URL(string: urlString) else {
            throw IGDBError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw IGDBError.authenticationFailed
        }
        
        let tokenResponse = try JSONDecoder().decode(IGDBTokenResponse.self, from: data)
        
        // Cache token
        self.accessToken = tokenResponse.accessToken
        self.tokenExpiry = Date().addingTimeInterval(TimeInterval(tokenResponse.expiresIn - 300)) // 5 min buffer
        
        ErrorLoggingService.shared.logInfo(
            "IGDB access token obtained",
            context: "IGDB API"
        )
        
        return tokenResponse.accessToken
    }
    
    // MARK: - Search Games
    
    func searchGames(query: String, limit: Int = 10) async throws -> [IGDBGame] {
        let token = try await getAccessToken()
        
        guard let clientID = clientID else {
            throw IGDBError.noCredentials
        }
        
        guard !query.isEmpty else {
            throw IGDBError.invalidQuery
        }
        
        let urlString = "\(baseURL)/games"
        guard let url = URL(string: urlString) else {
            throw IGDBError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(clientID, forHTTPHeaderField: "Client-ID")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let body = """
        search "\(query)";
        fields name, cover.url, summary, first_release_date, rating, genres.name, platforms.name, involved_companies.company.name;
        limit \(limit);
        """
        request.httpBody = body.data(using: .utf8)
        
        ErrorLoggingService.shared.logInfo(
            "Searching IGDB: \(query)",
            context: "IGDB API"
        )
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw IGDBError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            ErrorLoggingService.shared.logError(
                IGDBError.apiError(statusCode: httpResponse.statusCode),
                context: "IGDB API"
            )
            throw IGDBError.apiError(statusCode: httpResponse.statusCode)
        }
        
        let games = try JSONDecoder().decode([IGDBGame].self, from: data)
        
        ErrorLoggingService.shared.logInfo(
            "Found \(games.count) games on IGDB",
            context: "IGDB API"
        )
        
        return games
    }
    
    // MARK: - Get Game Details
    
    func getGame(id: Int) async throws -> IGDBGame {
        let token = try await getAccessToken()
        
        guard let clientID = clientID else {
            throw IGDBError.noCredentials
        }
        
        let urlString = "\(baseURL)/games"
        guard let url = URL(string: urlString) else {
            throw IGDBError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(clientID, forHTTPHeaderField: "Client-ID")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let body = """
        fields name, cover.url, summary, storyline, first_release_date, rating, rating_count, aggregated_rating, genres.name, platforms.name, involved_companies.company.name, screenshots.url, videos.video_id, websites.url;
        where id = \(id);
        """
        request.httpBody = body.data(using: .utf8)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw IGDBError.invalidResponse
        }
        
        let games = try JSONDecoder().decode([IGDBGame].self, from: data)
        
        guard let game = games.first else {
            throw IGDBError.gameNotFound
        }
        
        ErrorLoggingService.shared.logInfo(
            "Fetched game details: \(game.name)",
            context: "IGDB API"
        )
        
        return game
    }
}

// MARK: - Models

struct IGDBTokenResponse: Codable {
    let accessToken: String
    let expiresIn: Int
    let tokenType: String
    
    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case expiresIn = "expires_in"
        case tokenType = "token_type"
    }
}

struct IGDBGame: Codable, Identifiable {
    let id: Int
    let name: String
    let summary: String?
    let storyline: String?
    let cover: IGDBCover?
    let firstReleaseDate: Double?
    let rating: Double?
    let ratingCount: Int?
    let aggregatedRating: Double?
    let genres: [IGDBGenre]?
    let platforms: [IGDBPlatform]?
    let involvedCompanies: [IGDBInvolvedCompany]?
    let screenshots: [IGDBScreenshot]?
    
    enum CodingKeys: String, CodingKey {
        case id, name, summary, storyline, cover, rating, genres, platforms, screenshots
        case firstReleaseDate = "first_release_date"
        case ratingCount = "rating_count"
        case aggregatedRating = "aggregated_rating"
        case involvedCompanies = "involved_companies"
    }
    
    var displayName: String {
        if let year = releaseYear {
            return "\(name) (\(year))"
        }
        return name
    }
    
    var releaseYear: String? {
        guard let timestamp = firstReleaseDate else { return nil }
        let date = Date(timeIntervalSince1970: timestamp)
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy"
        return formatter.string(from: date)
    }
    
    var coverURL: URL? {
        guard let urlString = cover?.url else { return nil }
        // Replace thumb with bigger image
        let bigImageURL = urlString.replacingOccurrences(of: "t_thumb", with: "t_cover_big")
        return URL(string: "https:\(bigImageURL)")
    }
    
    var formattedRating: String? {
        guard let rating = rating else { return nil }
        return String(format: "%.0f/100", rating)
    }
    
    var genreNames: String {
        genres?.map { $0.name }.joined(separator: ", ") ?? "Unknown"
    }
    
    var platformNames: String {
        platforms?.map { $0.name }.joined(separator: ", ") ?? "Unknown"
    }
    
    var developer: String? {
        involvedCompanies?.first?.company.name
    }
}

struct IGDBCover: Codable {
    let url: String
}

struct IGDBGenre: Codable {
    let name: String
}

struct IGDBPlatform: Codable {
    let name: String
}

struct IGDBInvolvedCompany: Codable {
    let company: IGDBCompany
}

struct IGDBCompany: Codable {
    let name: String
}

struct IGDBScreenshot: Codable {
    let url: String
}

enum IGDBError: LocalizedError {
    case noCredentials
    case invalidQuery
    case invalidURL
    case invalidResponse
    case authenticationFailed
    case apiError(statusCode: Int)
    case gameNotFound
    
    var errorDescription: String? {
        switch self {
        case .noCredentials:
            return "IGDB credentials not configured"
        case .invalidQuery:
            return "Invalid search query"
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid response from IGDB"
        case .authenticationFailed:
            return "Failed to authenticate with IGDB"
        case .apiError(let code):
            return "IGDB API error (code: \(code))"
        case .gameNotFound:
            return "Game not found"
        }
    }
}