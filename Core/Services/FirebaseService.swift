// File: Core/Services/FirebaseService.swift

import Foundation
import FirebaseCore
import FirebaseAuth
import FirebaseFirestore
import FirebaseStorage

@MainActor
final class FirebaseService {
    static let shared = FirebaseService()
    
    let auth: Auth
    let firestore: Firestore
    let storage: Storage
    
    private init() {
        // Firebase is already configured in StashdApp
        // Just get references to the services
        
        self.auth = Auth.auth()
        self.firestore = Firestore.firestore()
        self.storage = Storage.storage()
        
        // Configure Firestore settings
        let settings = FirestoreSettings()
        settings.isPersistenceEnabled = true
        settings.cacheSizeBytes = FirestoreCacheSizeUnlimited
        firestore.settings = settings
        
        // DEBUG LOGS
        print("🔥 FirebaseService initialized")
        print("✅ Auth configured")
        print("✅ Firestore configured")
        print("✅ Storage configured")
        print("🪣 Storage bucket: \(storage.reference().bucket)")
    }
    
    // Helper to get current user ID
    var currentUserID: String? {
        auth.currentUser?.uid
    }
    
    // Helper to check if user is signed in
    var isSignedIn: Bool {
        auth.currentUser != nil
    }
}
