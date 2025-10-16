//
//  AppConfig.swift
//  stashd
//
//  Created by Sean Lynch on 10/13/25.
//


//
//  AppConfig.swift
//  stashd
//
//  Created by Sean Lynch
//

import Foundation

enum AppConfig {
    // MARK: - OpenAI
    
    static var openAIAPIKey: String {
        guard let key = Bundle.main.infoDictionary?["OPENAI_API_KEY"] as? String,
              !key.isEmpty,
              key != "your-openai-key-here" else {
            fatalError("""
            ⚠️ OPENAI_API_KEY not configured!
            
            Please:
            1. Copy Config.template.xcconfig to Config.xcconfig
            2. Add your real API key to Config.xcconfig
            3. Make sure Config.xcconfig is in .gitignore
            """)
        }
        return key
    }
    
    // MARK: - Discogs
    
    static var discogsAPIToken: String? {
        guard let token = Bundle.main.infoDictionary?["DISCOGS_API_TOKEN"] as? String,
              !token.isEmpty,
              token != "your-discogs-token-here" else {
            return nil
        }
        return token
    }
    
    // MARK: - TMDB (The Movie Database)
    
    static var tmdbAPIKey: String? {
        guard let key = Bundle.main.infoDictionary?["TMDB_API_KEY"] as? String,
              !key.isEmpty,
              key != "your-tmdb-key-here" else {
            return nil
        }
        return key
    }
    
    // MARK: - IGDB (Internet Game Database)
    
    static var igdbClientID: String? {
        guard let id = Bundle.main.infoDictionary?["IGDB_CLIENT_ID"] as? String,
              !id.isEmpty,
              id != "your-igdb-client-id-here" else {
            return nil
        }
        return id
    }
    
    static var igdbClientSecret: String? {
        guard let secret = Bundle.main.infoDictionary?["IGDB_CLIENT_SECRET"] as? String,
              !secret.isEmpty,
              secret != "your-igdb-client-secret-here" else {
            return nil
        }
        return secret
    }
    
    // MARK: - eBay

    static var ebayClientID: String? {
        guard let id = Bundle.main.infoDictionary?["EBAY_CLIENT_ID"] as? String,
              !id.isEmpty,
              id != "your-ebay-client-id-here" else {
            return nil
        }
        return id
    }

    static var ebayClientSecret: String? {
        guard let secret = Bundle.main.infoDictionary?["EBAY_CLIENT_SECRET"] as? String,
              !secret.isEmpty,
              secret != "your-ebay-client-secret-here" else {
            return nil
        }
        return secret
    }

    // Keep the old one for backwards compatibility
    static var ebayAPIKey: String? {
        ebayClientID
    }
    
    // MARK: - Validation
    
    static func validateConfiguration() {
        // Only OpenAI is required for core functionality
        _ = openAIAPIKey // This will crash if not configured
        
        // Log warnings for optional APIs
        if discogsAPIToken == nil {
            print("⚠️ Discogs API token not configured - vinyl search disabled")
        }
        
        if tmdbAPIKey == nil {
            print("⚠️ TMDB API key not configured - movie search disabled")
        }
        
        if igdbClientID == nil || igdbClientSecret == nil {
            print("⚠️ IGDB API not configured - video game search disabled")
        }
        
        if ebayAPIKey == nil {
            print("⚠️ eBay API key not configured - price lookup disabled")
        }
    }
}
// MARK: - Debug (REMOVE LATER)
extension AppConfig {
    static func debugPrintKeys() {
        print("🔑 OpenAI Key: \(openAIAPIKey.prefix(10))...")
        print("🔑 Discogs Token: \(discogsAPIToken?.prefix(10) ?? "MISSING")...")
        print("🔑 TMDB Key: \(tmdbAPIKey?.prefix(10) ?? "MISSING")...")
        print("🔑 IGDB Client ID: \(igdbClientID?.prefix(10) ?? "MISSING")...")
        print("🔑 eBay Key: \(ebayAPIKey?.prefix(10) ?? "MISSING")...")
    }
}
