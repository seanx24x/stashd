//
//  CollectionCategory.swift
//  stashd
//
//  Created by Sean Lynch
//

// File: Core/Models/CollectionCategory.swift

import Foundation

enum CollectionCategory: String, Codable, CaseIterable {
    // Entertainment & Media
    case vinyl = "Vinyl Records"
    case movies = "Movies"
    case books = "Books"
    case comics = "Comics"
    case videoGames = "Video Games"
    
    // Fashion & Accessories
    case sneakers = "Sneakers"
    case fashion = "Fashion"
    case watches = "Watches"
    
    // Collectibles & Trading
    case tradingCards = "Trading Cards"
    case sportsCards = "Sports Cards"
    case pokemonCards = "Pokemon Cards"
    
    // Toys & Models
    case toys = "Toys & Action Figures"
    case lego = "LEGO"
    case scaleModels = "Scale Models"
    case vinylToys = "Vinyl Toys"
    
    // Gaming
    case tabletopGaming = "Tabletop Gaming"
    case boardGames = "Board Games"
    case dice = "Dice"
    case miniatures = "Miniatures"
    
    // EDC & Tools
    case edc = "EDC (Everyday Carry)"
    case knives = "Knives"
    case pens = "Pens"
    
    // Tech & Gadgets
    case tech = "Tech & Gadgets"
    case vintageTech = "Vintage Tech"
    case cameras = "Cameras"
    
    // Traditional Collectibles
    case coins = "Coins"
    case stamps = "Stamps"
    case art = "Art"
    
    // Other
    case other = "Other"
    
    var iconName: String {
        switch self {
        // Entertainment & Media
        case .vinyl:
            return "music.note.list"
        case .movies:
            return "film"
        case .books:
            return "book"
        case .comics:
            return "book.pages"
        case .videoGames:
            return "gamecontroller"
            
        // Fashion & Accessories
        case .sneakers:
            return "shoe"
        case .fashion:
            return "tshirt"
        case .watches:
            return "watch"
            
        // Collectibles & Trading
        case .tradingCards:
            return "rectangle.stack"
        case .sportsCards:
            return "sportscourt"
        case .pokemonCards:
            return "star.circle"
            
        // Toys & Models
        case .toys:
            return "figure.walk"
        case .lego:
            return "square.stack.3d.up"
        case .scaleModels:
            return "airplane"
        case .vinylToys:
            return "teddybear"
            
        // Gaming
        case .tabletopGaming:
            return "dice"
        case .boardGames:
            return "checkerboard.rectangle"
        case .dice:
            return "die.face.6"
        case .miniatures:
            return "sparkles"
            
        // EDC & Tools
        case .edc:
            return "backpack"
        case .knives:
            return "triangle"
        case .pens:
            return "pencil"
            
        // Tech & Gadgets
        case .tech:
            return "laptopcomputer"
        case .vintageTech:
            return "rotary.phone"
        case .cameras:
            return "camera"
            
        // Traditional Collectibles
        case .coins:
            return "dollarsign.circle"
        case .stamps:
            return "envelope"
        case .art:
            return "paintbrush"
            
        // Other
        case .other:
            return "square.grid.2x2"
        }
    }
    
    // API availability flag
    var hasAPI: Bool {
        switch self {
        case .vinyl, .movies, .books, .videoGames, .tabletopGaming, .boardGames, .pokemonCards:
            return true
        default:
            return false
        }
    }
    
    // API type for each category
    var apiType: String? {
        switch self {
        case .vinyl:
            return "discogs"
        case .movies:
            return "tmdb"
        case .books:
            return "googleBooks"
        case .videoGames:
            return "igdb"
        case .tabletopGaming, .boardGames:
            return "boardGameGeek"
        case .pokemonCards:
            return "pokemonTCG"
        default:
            return nil
        }
    }
    
    // Description for category
    var description: String {
        switch self {
        // Entertainment & Media
        case .vinyl:
            return "Vinyl records, albums, and singles"
        case .movies:
            return "Movies, films, and cinema collections"
        case .books:
            return "Books, novels, and literature"
        case .comics:
            return "Comic books, graphic novels, and manga"
        case .videoGames:
            return "Video games across all platforms"
            
        // Fashion & Accessories
        case .sneakers:
            return "Sneakers, shoes, and footwear"
        case .fashion:
            return "Clothing, streetwear, and apparel"
        case .watches:
            return "Watches and timepieces"
            
        // Collectibles & Trading
        case .tradingCards:
            return "Trading cards of all types"
        case .sportsCards:
            return "Sports trading cards and memorabilia"
        case .pokemonCards:
            return "Pokemon trading card game"
            
        // Toys & Models
        case .toys:
            return "Action figures, toys, and collectibles"
        case .lego:
            return "LEGO sets and builds"
        case .scaleModels:
            return "Scale models, aircraft, cars, and ships"
        case .vinylToys:
            return "Designer toys and vinyl figures"
            
        // Gaming
        case .tabletopGaming:
            return "Tabletop games, RPGs, and board games"
        case .boardGames:
            return "Board games and strategy games"
        case .dice:
            return "Dice sets and polyhedral dice"
        case .miniatures:
            return "Gaming miniatures and models"
            
        // EDC & Tools
        case .edc:
            return "Everyday carry items and gear"
        case .knives:
            return "Knives, blades, and tools"
        case .pens:
            return "Pens, pencils, and writing instruments"
            
        // Tech & Gadgets
        case .tech:
            return "Technology, gadgets, and electronics"
        case .vintageTech:
            return "Vintage and retro technology"
        case .cameras:
            return "Cameras and photography equipment"
            
        // Traditional Collectibles
        case .coins:
            return "Coins, currency, and numismatics"
        case .stamps:
            return "Stamps and postal collectibles"
        case .art:
            return "Art, paintings, and sculptures"
            
        // Other
        case .other:
            return "Other collectibles"
        }
    }
}
