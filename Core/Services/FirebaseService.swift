//
//  FirebaseService.swift
//  stashd
//
//  Created by Sean Lynch on 10/9/25.
//


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
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }
        
        self.auth = Auth.auth()
        self.firestore = Firestore.firestore()
        self.storage = Storage.storage()
        
        let settings = FirestoreSettings()
        settings.cacheSettings = PersistentCacheSettings(sizeBytes: FirestoreCacheSizeUnlimited as NSNumber)
        firestore.settings = settings
    }
}
