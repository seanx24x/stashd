//
//  DiscogsService.swift
//  stashd
//
//  Created by Sean Lynch on 10/16/25.
//


//
//  DiscogsService.swift
//  stashd
//
//  Created by Sean Lynch
//

import Foundation

@MainActor
final class DiscogsService {
    static let shared = DiscogsService()
    
    private let baseURL = "https://api.discogs.com"
    private var token: String? { AppConfig.discogsAPIToken }
    
    private init() {}
    
    // MARK: - Search
    
    func searchReleases(query: String, type: DiscogsSearchType = .all) async throws -> [DiscogsRelease] {
        guard let token = token else {
            throw DiscogsError.noAPIToken
        }
        
        guard !query.isEmpty else {
            throw DiscogsError.invalidQuery
        }
        
        let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        let typeParam = type == .all ? "" : "&type=\(type.rawValue)"
        let urlString = "\(baseURL)/database/search?q=\(encodedQuery)\(typeParam)&token=\(token)"
        
        guard let url = URL(string: urlString) else {
            throw DiscogsError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.setValue("Stashd/1.0", forHTTPHeaderField: "User-Agent")
        
        ErrorLoggingService.shared.logInfo(
            "Searching Discogs: \(query)",
            context: "Discogs API"
        )
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw DiscogsError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            ErrorLoggingService.shared.logError(
                DiscogsError.apiError(statusCode: httpResponse.statusCode),
                context: "Discogs API"
            )
            throw DiscogsError.apiError(statusCode: httpResponse.statusCode)
        }
        
        let searchResponse = try JSONDecoder().decode(DiscogsSearchResponse.self, from: data)
        
        ErrorLoggingService.shared.logInfo(
            "Found \(searchResponse.results.count) results on Discogs",
            context: "Discogs API"
        )
        
        return searchResponse.results
    }
    
    // MARK: - Get Release Details
    
    func getRelease(id: Int) async throws -> DiscogsReleaseDetail {
        guard let token = token else {
            throw DiscogsError.noAPIToken
        }
        
        let urlString = "\(baseURL)/releases/\(id)?token=\(token)"
        
        guard let url = URL(string: urlString) else {
            throw DiscogsError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.setValue("Stashd/1.0", forHTTPHeaderField: "User-Agent")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw DiscogsError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            throw DiscogsError.apiError(statusCode: httpResponse.statusCode)
        }
        
        let release = try JSONDecoder().decode(DiscogsReleaseDetail.self, from: data)
        
        ErrorLoggingService.shared.logInfo(
            "Fetched release details: \(release.title)",
            context: "Discogs API"
        )
        
        return release
    }
    
    // MARK: - Search by Barcode
    
    func searchByBarcode(_ barcode: String) async throws -> [DiscogsRelease] {
        guard let token = token else {
            throw DiscogsError.noAPIToken
        }
        
        let urlString = "\(baseURL)/database/search?barcode=\(barcode)&token=\(token)"
        
        guard let url = URL(string: urlString) else {
            throw DiscogsError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.setValue("Stashd/1.0", forHTTPHeaderField: "User-Agent")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw DiscogsError.invalidResponse
        }
        
        let searchResponse = try JSONDecoder().decode(DiscogsSearchResponse.self, from: data)
        return searchResponse.results
    }
}

// MARK: - Models

enum DiscogsSearchType: String {
    case all = ""
    case release = "release"
    case master = "master"
    case artist = "artist"
    case label = "label"
}

struct DiscogsSearchResponse: Codable {
    let results: [DiscogsRelease]
}

struct DiscogsRelease: Codable, Identifiable {
    let id: Int
    let title: String
    let year: String?
    let coverImage: String?
    let thumb: String?
    let genre: [String]?
    let style: [String]?
    let country: String?
    let format: [String]?
    let label: [String]?
    
    enum CodingKeys: String, CodingKey {
        case id, title, year, genre, style, country, format, label
        case coverImage = "cover_image"
        case thumb
    }
    
    var displayTitle: String {
        title
    }
    
    var displayYear: String {
        year ?? "Unknown Year"
    }
    
    var imageURL: URL? {
        if let cover = coverImage, !cover.isEmpty {
            return URL(string: cover)
        }
        return nil
    }
}

struct DiscogsReleaseDetail: Codable {
    let id: Int
    let title: String
    let artists: [DiscogsArtist]?
    let year: Int?
    let genres: [String]?
    let styles: [String]?
    let tracklist: [DiscogsTrack]?
    let images: [DiscogsImage]?
    let country: String?
    let released: String?
    let notes: String?
    let lowestPrice: Double?
    
    enum CodingKeys: String, CodingKey {
        case id, title, artists, year, genres, styles, tracklist, images, country, released, notes
        case lowestPrice = "lowest_price"
    }
    
    var artistNames: String {
        artists?.map { $0.name }.joined(separator: ", ") ?? "Unknown Artist"
    }
    
    // ✅ FIXED
    var primaryImageURL: URL? {
        guard let firstImage = images?.first else { return nil }
        return URL(string: firstImage.uri)
    }
    
    var formattedPrice: String? {
        guard let price = lowestPrice else { return nil }
        return String(format: "$%.2f", price)
    }
}

struct DiscogsArtist: Codable {
    let name: String
    let id: Int?
}

struct DiscogsTrack: Codable {
    let position: String
    let title: String
    let duration: String?
}

struct DiscogsImage: Codable {
    let uri: String
    let width: Int
    let height: Int
    let type: String
}

enum DiscogsError: LocalizedError {
    case noAPIToken
    case invalidQuery
    case invalidURL
    case invalidResponse
    case apiError(statusCode: Int)
    case decodingError
    
    var errorDescription: String? {
        switch self {
        case .noAPIToken:
            return "Discogs API token not configured"
        case .invalidQuery:
            return "Invalid search query"
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid response from Discogs"
        case .apiError(let code):
            return "Discogs API error (code: \(code))"
        case .decodingError:
            return "Failed to decode Discogs response"
        }
    }
}
