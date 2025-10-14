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
}
