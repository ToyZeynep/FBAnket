//
//  VotingPage.swift
//  FBAnket
//
//  Created by Zeynep Toy on 17.06.2025.
//

import SwiftUI
import FirebaseFirestore
import FirebaseCore
import FirebaseRemoteConfig
import GoogleMobileAds

struct VotingPage: View {
    @State private var likeCount = 0
    @State private var dislikeCount = 0
    @State private var userVote: VoteType? = nil
    @State private var isLoading = false
    @State private var showBackground = false
    
    private let db = Firestore.firestore()
    private let remoteConfig = RemoteConfig.remoteConfig()
    private let voteDocumentID = "ali_koc_istifa_vote"
    
    enum VoteType: String, CaseIterable {
        case like = "like"
        case dislike = "dislike"
    }
    
    var body: some View {
        ZStack {
            if showBackground {
                Image("background")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .ignoresSafeArea()
                    .opacity(0.3)
            } else {
                LinearGradient(
                    gradient: Gradient(colors: [Color.blue.opacity(0.1), Color.purple.opacity(0.1)]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
            }
            
            VStack(spacing: 30) {
                HStack {
                    Spacer()
                    Button(action: {
                        loadVotes()
                        fetchRemoteConfig()
                    }) {
                        Image(systemName: "arrow.clockwise")
                            .font(.title3)
                            .foregroundColor(.blue)
                    }
                    .padding(.trailing)
                }
                Spacer()
                Text("ALİ KOÇ")
                    .font(.title)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                    .padding()
                    .cornerRadius(10)
                
                HStack(spacing: 40) {
                    VStack {
                        Image(systemName: "hand.thumbsup.fill")
                            .font(.title2)
                            .foregroundColor(.green)
                        Text("\(likeCount)")
                            .font(.headline)
                            .fontWeight(.semibold)
                    }
                    
                    VStack {
                        Image(systemName: "hand.thumbsdown.fill")
                            .font(.title2)
                            .foregroundColor(.red)
                        Text("\(dislikeCount)")
                            .font(.headline)
                            .fontWeight(.semibold)
                    }
                }
                .padding()
                .cornerRadius(12)
                
                HStack(spacing: 20) {
                    Button(action: {
                        handleVote(.like)
                    }) {
                        HStack {
                            Image(systemName: userVote == .like ? "hand.thumbsup.fill" : "hand.thumbsup")
                            Text("Devam Etsin")
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(userVote == .like ? Color.green : Color.green.opacity(0.2))
                        .foregroundColor(userVote == .like ? .white : .green)
                        .cornerRadius(10)
                    }
                    .disabled(isLoading || userVote == .like)
                    
                    Button(action: {
                        handleVote(.dislike)
                    }) {
                        HStack {
                            Image(systemName: userVote == .dislike ? "hand.thumbsdown.fill" : "hand.thumbsdown")
                            Text("İstifa Etsin")
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(userVote == .dislike ? Color.red : Color.red.opacity(0.2))
                        .foregroundColor(userVote == .dislike ? .white : .red)
                        .cornerRadius(10)
                    }
                    .disabled(isLoading || userVote == .dislike)
                }
                .padding(.horizontal)
                Spacer()
                BannerAdView()
                .frame(height: 50)
            }
            .padding()
            .onAppear {
                loadVotes()
                setupRemoteConfig()
                fetchRemoteConfig()
            }
        }
    }
    
    private func handleVote(_ voteType: VoteType) {
        guard !isLoading, userVote != voteType else { return }
        castVote(voteType)
    }
    
    private func castVote(_ voteType: VoteType) {
        isLoading = true
        
        let batch = db.batch()
        let voteRef = db.collection("votes").document(voteDocumentID)
        let userVoteRef = db.collection("userVotes").document(getUserID())
        
        if let previousVote = userVote {
            let previousField = previousVote == .like ? "likes" : "dislikes"
            batch.updateData([previousField: FieldValue.increment(Int64(-1))], forDocument: voteRef)
        }
        
        let newField = voteType == .like ? "likes" : "dislikes"
        batch.updateData([newField: FieldValue.increment(Int64(1))], forDocument: voteRef)
        
        batch.setData([
            "vote": voteType.rawValue,
            "timestamp": FieldValue.serverTimestamp()
        ], forDocument: userVoteRef)
        
        batch.commit { error in
            DispatchQueue.main.async {
                self.isLoading = false
                if error == nil {
                    let oldVote = self.userVote
                    self.userVote = voteType
                    
                    if let old = oldVote {
                        if old == .like {
                            self.likeCount -= 1
                        } else {
                            self.dislikeCount -= 1
                        }
                    }
                    
                    if voteType == .like {
                        self.likeCount += 1
                    } else {
                        self.dislikeCount += 1
                    }
                }
            }
        }
    }
    
    private func removeVote() {
        guard let currentVote = userVote else { return }
        isLoading = true
        
        let batch = db.batch()
        let voteRef = db.collection("votes").document(voteDocumentID)
        let userVoteRef = db.collection("userVotes").document(getUserID())
        
        let field = currentVote == .like ? "likes" : "dislikes"
        batch.updateData([field: FieldValue.increment(Int64(-1))], forDocument: voteRef)
        
        batch.deleteDocument(userVoteRef)
        
        batch.commit { error in
            DispatchQueue.main.async {
                self.isLoading = false
                if error == nil {
                    if currentVote == .like {
                        self.likeCount -= 1
                    } else {
                        self.dislikeCount -= 1
                    }
                    self.userVote = nil
                }
            }
        }
    }
    
    private func loadVotes() {
        db.collection("votes").document(voteDocumentID).getDocument { document, error in
            if let document = document, document.exists {
                let data = document.data()
                DispatchQueue.main.async {
                    self.likeCount = data?["likes"] as? Int ?? 0
                    self.dislikeCount = data?["dislikes"] as? Int ?? 0
                }
            } else {
                self.createInitialVoteDocument()
            }
        }
        
        db.collection("userVotes").document(getUserID()).getDocument { document, error in
            if let document = document, document.exists {
                let data = document.data()
                if let voteString = data?["vote"] as? String,
                   let vote = VoteType(rawValue: voteString) {
                    DispatchQueue.main.async {
                        self.userVote = vote
                    }
                }
            }
        }
    }
    
    private func createInitialVoteDocument() {
        db.collection("votes").document(voteDocumentID).setData([
            "likes": 0,
            "dislikes": 0,
            "createdAt": FieldValue.serverTimestamp()
        ])
    }
    
    private func updateLocalCounts(previousVote: VoteType?, newVote: VoteType) {
        if let previous = previousVote {
            if previous == .like {
                likeCount -= 1
            } else {
                dislikeCount -= 1
            }
        }
        
        if newVote == .like {
            likeCount += 1
        } else {
            dislikeCount += 1
        }
    }
    
    private func getUserID() -> String {
        if let deviceID = UIDevice.current.identifierForVendor?.uuidString {
            return deviceID
        }
        return UUID().uuidString
    }
    
    private func setupRemoteConfig() {
        let settings = RemoteConfigSettings()
        settings.minimumFetchInterval = 0
        remoteConfig.configSettings = settings
        
        let defaults: [String: NSObject] = [
            "show_background": false as NSObject
        ]
        remoteConfig.setDefaults(defaults)
    }
    
    private func fetchRemoteConfig() {
        remoteConfig.fetch { status, error in
            if status == .success {
                self.remoteConfig.activate { _, _ in
                    DispatchQueue.main.async {
                        self.showBackground = self.remoteConfig["show_background"].boolValue
                    }
                }
            }
        }
    }
}

#Preview {
    VotingPage()
}
