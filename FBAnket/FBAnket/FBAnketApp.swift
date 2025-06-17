//
//  FBAnketApp.swift
//  FBAnket
//
//  Created by Zeynep Toy on 17.06.2025.
//

import SwiftUI
import Firebase
import GoogleMobileAds

@main
struct FBAnketApp: App {
    
    init() {
        FirebaseApp.configure()
        MobileAds.shared.start { status in
            print("AdMob başlatıldı. Status: \(status)")
        }
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
