//
//  FBAnketApp.swift
//  FBAnket
//
//  Created by Zeynep Toy on 17.06.2025.
//

import SwiftUI
import Firebase

@main
struct FBAnketApp: App {
    
    init() {
            FirebaseApp.configure()
        }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
