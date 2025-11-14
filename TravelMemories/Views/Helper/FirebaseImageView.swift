//
//  FirebaseImageView.swift
//  TravelMemories
//
//  Helper view to load and display images from Firebase Storage
//

import SwiftUI

struct FirebaseImageView: View {
    let imageURL: String?
    let placeholder: Image
    
    @State private var loadedImage: UIImage?
    @State private var isLoading = false
    @State private var currentImageURL: String?
    
    init(imageURL: String?, placeholder: Image = Image(systemName: "photo")) {
        self.imageURL = imageURL
        self.placeholder = placeholder
    }
    
    var body: some View {
        Group {
            if let loadedImage = loadedImage {
                Image(uiImage: loadedImage)
                    .resizable()
            } else if isLoading {
                ProgressView()
            } else {
                placeholder
                    .resizable()
            }
        }
        .task(id: imageURL) {
            await loadImage()
        }
    }
    
    private func loadImage() async {
        guard let urlString = imageURL,
              let url = URL(string: urlString) else {
            // Reset if URL is nil
            await MainActor.run {
                self.loadedImage = nil
                self.currentImageURL = nil
                self.isLoading = false
            }
            return
        }
        
        // If URL changed, reset and reload
        if currentImageURL != urlString {
            await MainActor.run {
                self.loadedImage = nil
                self.currentImageURL = urlString
            }
        } else if loadedImage != nil {
            // Already loaded this URL, no need to reload
            return
        }
        
        isLoading = true
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let uiImage = UIImage(data: data) {
                await MainActor.run {
                    self.loadedImage = uiImage
                    self.isLoading = false
                }
            }
        } catch {
            print("Error loading image from Firebase: \(error)")
            await MainActor.run {
                self.isLoading = false
            }
        }
    }
}

