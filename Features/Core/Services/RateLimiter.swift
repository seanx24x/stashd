//
//  RateLimiter.swift
//  stashd
//
//  Created by Sean Lynch on 10/14/25.
//


//
//  RateLimiter.swift
//  stashd
//
//  Created by Sean Lynch
//

import Foundation

actor RateLimiter {
    private var callTimestamps: [Date] = []
    private let maxCallsPerMinute: Int
    private let windowSeconds: TimeInterval
    
    init(maxCallsPerMinute: Int = 10, windowSeconds: TimeInterval = 60) {
        self.maxCallsPerMinute = maxCallsPerMinute
        self.windowSeconds = windowSeconds
    }
    
    func checkRateLimit() throws {
        let now = Date()
        let windowStart = now.addingTimeInterval(-windowSeconds)
        
        // Remove timestamps outside the current window
        callTimestamps = callTimestamps.filter { $0 > windowStart }
        
        // Check if we've exceeded the limit
        guard callTimestamps.count < maxCallsPerMinute else {
            throw RateLimitError.rateLimitExceeded(
                limit: maxCallsPerMinute,
                window: Int(windowSeconds)
            )
        }
        
        // Record this call
        callTimestamps.append(now)
    }
    
    func getRemainingCalls() -> Int {
        let now = Date()
        let windowStart = now.addingTimeInterval(-windowSeconds)
        
        // Count calls in current window
        let recentCalls = callTimestamps.filter { $0 > windowStart }.count
        return max(0, maxCallsPerMinute - recentCalls)
    }
    
    func reset() {
        callTimestamps.removeAll()
    }
}

enum RateLimitError: LocalizedError {
    case rateLimitExceeded(limit: Int, window: Int)
    
    var errorDescription: String? {
        switch self {
        case .rateLimitExceeded(let limit, let window):
            return "Rate limit exceeded: Maximum \(limit) API calls per \(window) seconds. Please try again in a moment."
        }
    }
}