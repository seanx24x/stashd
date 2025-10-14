//
//  AppConfig.swift
//  stashd
//
//  Created by Sean Lynch on 10/13/25.
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
        
        // ✅ NEW: Validate OpenAI key format
        guard key.hasPrefix("sk-") || key.hasPrefix("sk-proj-") else {
            fatalError("""
            ⚠️ Invalid OPENAI_API_KEY format!
            
            OpenAI API keys must start with 'sk-' or 'sk-proj-'
            Your key appears to be invalid or from a different service.
            
            Get a valid key from: https://platform.openai.com/api-keys
            """)
        }
        
        // ✅ NEW: Validate minimum length (OpenAI keys are typically 48+ characters)
        guard key.count >= 40 else {
            fatalError("""
            ⚠️ OPENAI_API_KEY appears truncated!
            
            OpenAI keys are typically 48+ characters long.
            Your key is only \(key.count) characters.
            
            Please check that you copied the entire key.
            """)
        }
        
        return key
    }
    
    // ✅ NEW: Validate key at app launch without exposing it
    static func validateConfiguration() {
        _ = openAIAPIKey // This will trigger all validations
        print("✅ OpenAI API key validated successfully")
    }
}
