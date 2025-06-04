//
//  ProfileSummary.swift
//  Created by Wayne on 13/05/2025.
//

import SwiftUI

struct ProfileSummary: View {
    @Environment(ModelData.self) var modelData
    var profile: Profile
    
    var totalMemories: Int {
        modelData.memories.count
    }
    var uniqueCountries: Int {
        Set(modelData.memories.map { $0.country }).count
    }
    var favoriteMemories: Int {
        modelData.memories.filter { $0.isFavorite }.count
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 40) {
                // Profile image placeholder + username
                VStack(spacing: 12) {
                    if let fileName = profile.profileImageFileName {
                        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent(fileName)
                        if let uiImage = UIImage(contentsOfFile: url.path) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 100, height: 100)
                                .clipShape(Circle())
                        } else {
                            Circle()
                                .fill(Color.gray.opacity(0.3))
                                .frame(width: 100, height: 100)
                                .overlay(
                                    Image(systemName: "person.crop.circle")
                                        .font(.largeTitle)
                                        .foregroundColor(.gray)
                                )
                        }
                    } else {
                        Circle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 100, height: 100)
                            .overlay(
                                Image(systemName: "person.crop.circle")
                                    .font(.largeTitle)
                                    .foregroundColor(.gray)
                            )
                    }
                    Text(profile.username)
                        .bold()
                        .font(.title)
                }
                // Notifications + travel stats
                VStack(spacing: 10) {
                    Text("Notifications: \(profile.prefersNotifications ? "On" : "Off")")
                    HStack(spacing: 24) {
                        VStack {
                            Text("\(totalMemories)").font(.title2).bold()
                            Text("Memories").font(.caption)
                        }
                        VStack {
                            Text("\(uniqueCountries)").font(.title2).bold()
                            Text("Countries").font(.caption)
                        }
                        VStack {
                            Text("\(favoriteMemories)").font(.title2).bold()
                            Text("Favorites").font(.caption)
                        }
                    }
                    .padding(.vertical)
                }
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .multilineTextAlignment(.center)
        }
    }
}

#Preview {
    ProfileSummary(profile: Profile.default)
        .environment(ModelData())
}
