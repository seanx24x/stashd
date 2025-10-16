//
//  TMDBService.swift
//  stashd
//
//  Created by Sean Lynch on 10/16/25.
//


//
//  TMDBService.swift
//  stashd
//
//  Created by Sean Lynch
//

import Foundation

@MainActor
final class TMDBService {
    static let shared = TMDBService()
    
    private let baseURL = "https://api.themoviedb.org/3"
    private let imageBaseURL = "https://image.tmdb.org/t/p"
    private var apiKey: String? { AppConfig.tmdbAPIKey }
    
    private init() {}
    
    // MARK: - Search Movies
    
    func searchMovies(query: String) async throws -> [TMDBMovie] {
        guard let apiKey = apiKey else {
            throw TMDBError.noAPIKey
        }
        
        guard !query.isEmpty else {
            throw TMDBError.invalidQuery
        }
        
        let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        let urlString = "\(baseURL)/search/movie?api_key=\(apiKey)&query=\(encodedQuery)"
        
        guard let url = URL(string: urlString) else {
            throw TMDBError.invalidURL
        }
        
        ErrorLoggingService.shared.logInfo(
            "Searching TMDB: \(query)",
            context: "TMDB API"
        )
        
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw TMDBError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            ErrorLoggingService.shared.logError(
                TMDBError.apiError(statusCode: httpResponse.statusCode),
                context: "TMDB API"
            )
            throw TMDBError.apiError(statusCode: httpResponse.statusCode)
        }
        
        let searchResponse = try JSONDecoder().decode(TMDBSearchResponse.self, from: data)
        
        ErrorLoggingService.shared.logInfo(
            "Found \(searchResponse.results.count) movies on TMDB",
            context: "TMDB API"
        )
        
        return searchResponse.results
    }
    
    // MARK: - Get Movie Details
    
    func getMovie(id: Int) async throws -> TMDBMovieDetail {
        guard let apiKey = apiKey else {
            throw TMDBError.noAPIKey
        }
        
        let urlString = "\(baseURL)/movie/\(id)?api_key=\(apiKey)&append_to_response=credits,videos"
        
        guard let url = URL(string: urlString) else {
            throw TMDBError.invalidURL
        }
        
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw TMDBError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            throw TMDBError.apiError(statusCode: httpResponse.statusCode)
        }
        
        let movie = try JSONDecoder().decode(TMDBMovieDetail.self, from: data)
        
        ErrorLoggingService.shared.logInfo(
            "Fetched movie details: \(movie.title)",
            context: "TMDB API"
        )
        
        return movie
    }
    
    // MARK: - Helper Methods
    
    func posterURL(path: String?, size: TMDBImageSize = .w500) -> URL? {
        guard let path = path else { return nil }
        return URL(string: "\(imageBaseURL)/\(size.rawValue)\(path)")
    }
    
    func backdropURL(path: String?, size: TMDBImageSize = .original) -> URL? {
        guard let path = path else { return nil }
        return URL(string: "\(imageBaseURL)/\(size.rawValue)\(path)")
    }
}

// MARK: - Models

enum TMDBImageSize: String {
    case w92 = "w92"
    case w154 = "w154"
    case w185 = "w185"
    case w342 = "w342"
    case w500 = "w500"
    case w780 = "w780"
    case original = "original"
}

struct TMDBSearchResponse: Codable {
    let results: [TMDBMovie]
}

struct TMDBMovie: Codable, Identifiable {
    let id: Int
    let title: String
    let overview: String?
    let posterPath: String?
    let backdropPath: String?
    let releaseDate: String?
    let voteAverage: Double?
    let genreIds: [Int]?
    
    enum CodingKeys: String, CodingKey {
        case id, title, overview
        case posterPath = "poster_path"
        case backdropPath = "backdrop_path"
        case releaseDate = "release_date"
        case voteAverage = "vote_average"
        case genreIds = "genre_ids"
    }
    
    var displayTitle: String {
        if let year = releaseYear {
            return "\(title) (\(year))"
        }
        return title
    }
    
    var releaseYear: String? {
        guard let date = releaseDate else { return nil }
        return String(date.prefix(4))
    }
    
    var posterURL: URL? {
        TMDBService.shared.posterURL(path: posterPath)
    }
    
    var rating: String? {
        guard let vote = voteAverage else { return nil }
        return String(format: "%.1f", vote)
    }
}

struct TMDBMovieDetail: Codable {
    let id: Int
    let title: String
    let overview: String?
    let posterPath: String?
    let backdropPath: String?
    let releaseDate: String?
    let runtime: Int?
    let voteAverage: Double?
    let genres: [TMDBGenre]?
    let credits: TMDBCredits?
    let tagline: String?
    let budget: Int?
    let revenue: Int?
    
    enum CodingKeys: String, CodingKey {
        case id, title, overview, runtime, genres, credits, tagline, budget, revenue
        case posterPath = "poster_path"
        case backdropPath = "backdrop_path"
        case releaseDate = "release_date"
        case voteAverage = "vote_average"
    }
    
    var releaseYear: String? {
        guard let date = releaseDate else { return nil }
        return String(date.prefix(4))
    }
    
    var formattedRuntime: String? {
        guard let runtime = runtime else { return nil }
        let hours = runtime / 60
        let minutes = runtime % 60
        return "\(hours)h \(minutes)m"
    }
    
    var posterURL: URL? {
        TMDBService.shared.posterURL(path: posterPath)
    }
    
    var backdropURL: URL? {
        TMDBService.shared.backdropURL(path: backdropPath)
    }
    
    var director: String? {
        credits?.crew.first(where: { $0.job == "Director" })?.name
    }
    
    var cast: [String] {
        credits?.cast.prefix(5).map { $0.name } ?? []
    }
    
    var genreNames: String {
        genres?.map { $0.name }.joined(separator: ", ") ?? ""
    }
}

struct TMDBGenre: Codable {
    let id: Int
    let name: String
}

struct TMDBCredits: Codable {
    let cast: [TMDBCast]
    let crew: [TMDBCrew]
}

struct TMDBCast: Codable {
    let name: String
    let character: String?
    let order: Int?
}

struct TMDBCrew: Codable {
    let name: String
    let job: String
    let department: String?
}

enum TMDBError: LocalizedError {
    case noAPIKey
    case invalidQuery
    case invalidURL
    case invalidResponse
    case apiError(statusCode: Int)
    
    var errorDescription: String? {
        switch self {
        case .noAPIKey:
            return "TMDB API key not configured"
        case .invalidQuery:
            return "Invalid search query"
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid response from TMDB"
        case .apiError(let code):
            return "TMDB API error (code: \(code))"
        }
    }
}