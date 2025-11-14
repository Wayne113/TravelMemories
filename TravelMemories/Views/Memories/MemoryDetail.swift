import SwiftUI
import PhotosUI

struct MemoryDetail: View {
    @Environment(ModelData.self) var modelData
    @Environment(\.dismiss) var dismiss
    var memory: Memory
    
    @State private var selectedItems: [PhotosPickerItem] = []
    @State private var selectedImages: [UIImage] = []
    @State private var firebaseImages: [UIImage] = [] // Store loaded Firebase images
    @State private var showPhotoPreview = false
    @State private var selectedPhotoIndex = 0
    @State private var isLoadingFirebaseImages = false
    @State private var showEditMemory = false
    
    var memoryIndex: Int? {
        modelData.memories.firstIndex(where: { $0.id == memory.id })
    }
    
    // Get current memory from modelData to reflect updates
    var currentMemory: Memory? {
        modelData.memories.first(where: { $0.id == memory.id })
    }
    
    var body: some View {
        @Bindable var modelData = modelData
        
        // Use current memory if available, otherwise use initial memory
        let displayMemory = currentMemory ?? memory
        
        ScrollView {
            MapView(memory: displayMemory)
                .frame(height: 300)

            Group {
                if displayMemory.isFromFirebase, let imageURL = displayMemory.firstImageURL {
                    FirebaseImageView(imageURL: imageURL, placeholder: displayMemory.image)
                        .frame(width: 200, height: 200)
                        .scaledToFill()
                        .clipShape(Circle())
                        .overlay {
                            Circle().stroke(.white, lineWidth: 4)
                        }
                        .shadow(radius: 7)
                        .offset(y: -100)
                        .padding(.bottom, -100)
                } else {
                    CircleImage(image: displayMemory.image)
                        .frame(width: 200, height: 200)
                        .offset(y: -100)
                        .padding(.bottom, -100)
                }
            }

            VStack(alignment: .leading) {
                HStack {
                    Text(displayMemory.name)
                        .font(.title)
                    Spacer()
                    if let index = memoryIndex {
                        FavoriteButton(isSet: $modelData.memories[index].isFavorite)
                    }
                }

                HStack {
                    Text(displayMemory.state.isEmpty ? displayMemory.country : displayMemory.state + ", " + displayMemory.country)
                    Spacer()
                    Text(displayMemory.visitedDate ?? "Unknown Date")
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)

                Divider()

                Text("About \(displayMemory.name)")
                    .font(.title2)
                Spacer()
                Text(displayMemory.description)

                Divider()
                Text("Photos")
                    .font(.title2)

                // Grid layout for all images (Firebase + user-added) and '+' button
                let columns = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]
                LazyVGrid(columns: columns, spacing: 8) {
                    // Show Firebase images first
                    ForEach(firebaseImages.indices, id: \.self) { idx in
                        Image(uiImage: firebaseImages[idx])
                            .resizable()
                            .scaledToFill()
                            .frame(width: 100, height: 100)
                            .clipped()
                            .cornerRadius(8)
                            .onTapGesture {
                                // Firebase images come first, so index is just idx
                                selectedPhotoIndex = idx
                                showPhotoPreview = true
                            }
                    }
                    
                    // Show user-added images
                    ForEach(selectedImages.indices, id: \.self) { idx in
                        Image(uiImage: selectedImages[idx])
                            .resizable()
                            .scaledToFill()
                            .frame(width: 100, height: 100)
                            .clipped()
                            .cornerRadius(8)
                            .onTapGesture {
                                // User images come after Firebase images
                                selectedPhotoIndex = firebaseImages.count + idx
                                showPhotoPreview = true
                            }
                    }
                    
                    // '+' button as grid item (only show if not a Firebase-only memory or allow adding more)
                    PhotosPicker(
                        selection: $selectedItems,
                        matching: .images,
                        photoLibrary: .shared()
                    ) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color(.systemGray6))
                                .frame(width: 100, height: 100)
                            Image(systemName: "plus")
                                .font(.system(size: 32, weight: .bold))
                                .foregroundColor(.blue)
                        }
                    }
                    .onChange(of: selectedItems) { oldItems, newItems in
                        selectedImages = Array(repeating: UIImage(), count: newItems.count)
                        var newPaths: [String?] = Array(repeating: nil, count: newItems.count)
                        for (index, item) in newItems.enumerated() {
                            item.loadTransferable(type: Data.self) { result in
                                switch result {
                                case .success(let data):
                                    if let data, let uiImage = UIImage(data: data) {
                                        DispatchQueue.main.async {
                                            selectedImages[index] = uiImage
                                            // Save to disk
                                            let fileName = "memory_\(memory.id)_userphoto_\(index)_\(UUID().uuidString).jpg"
                                            if let path = saveImageToDocuments(uiImage, fileName: fileName) {
                                                newPaths[index] = path
                                                // Check if all completed
                                                if newPaths.allSatisfy({ $0 != nil }), let memoryIndex = memoryIndex {
                                                    modelData.memories[memoryIndex].userImagePaths = newPaths.compactMap { $0 }
                                                    saveMemories(memories: modelData.memories)
                                                }
                                            }
                                        }
                                    }
                                case .failure(let error):
                                    print("Failed to load image: \(error)")
                                }
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical)
                .onAppear {
                    // Load user-added images
                    if let paths = displayMemory.userImagePaths {
                        selectedImages = paths.compactMap { loadImageFromDocuments(path: $0) }
                    }
                    
                    // Load Firebase images
                    loadFirebaseImages()
                }
            }
            .padding()
            .onChange(of: displayMemory.isFavorite) { oldValue, newValue in
                if memoryIndex != nil {
                    saveMemories(memories: modelData.memories)
                    print("Memory favorite status changed for \(displayMemory.name), saved memories from detail view.")
                }
            }
        }
        .navigationTitle(displayMemory.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack {
                    Button {
                        showEditMemory = true
                    } label: {
                        Label("Edit Memory", systemImage: "pencil")
                    }
                    
                    Button(role: .destructive) {
                        Task {
                            do {
                                // deleteMemory handles Firebase deletion if needed
                                try await modelData.deleteMemory(displayMemory)
                                await MainActor.run {
                                    dismiss()
                                }
                            } catch {
                                print("Error deleting memory: \(error)")
                                // Still remove from local array and dismiss even if Firebase delete fails
                                await MainActor.run {
                                    if let index = memoryIndex {
                                        modelData.memories.remove(at: index)
                                        saveMemories(memories: modelData.memories)
                                    }
                                    dismiss()
                                }
                            }
                        }
                    } label: {
                        Label("Delete Memory", systemImage: "trash")
                    }
                }
            }
        }
        .sheet(isPresented: $showEditMemory) {
            if let currentMemory = currentMemory {
                EditMemory(memory: currentMemory)
                    .environment(modelData)
            } else {
                EditMemory(memory: memory)
                    .environment(modelData)
            }
        }
        .onChange(of: showEditMemory) { _, isPresented in
            if !isPresented {
                // Reload images when edit sheet is dismissed
                loadFirebaseImages()
            }
        }
        .onChange(of: displayMemory.firstImageURL) { _, _ in
            // Reload images when image URL changes
            loadFirebaseImages()
        }
        .sheet(isPresented: $showPhotoPreview) {
            // Combine Firebase images and user images for preview
            let allImages = firebaseImages + selectedImages
            if allImages.indices.contains(selectedPhotoIndex) {
                PhotoPreviewModal(
                    images: Binding(
                        get: { firebaseImages + selectedImages },
                        set: { newImages in
                            // Split back into Firebase and user images
                            let firebaseCount = firebaseImages.count
                            if newImages.count >= firebaseCount {
                                firebaseImages = Array(newImages.prefix(firebaseCount))
                                selectedImages = Array(newImages.suffix(from: firebaseCount))
                            }
                        }
                    ),
                    imagePaths: Binding(
                        get: { displayMemory.userImagePaths ?? [] },
                        set: { newPaths in
                            if let memoryIndex = memoryIndex {
                                modelData.memories[memoryIndex].userImagePaths = newPaths
                                saveMemories(memories: modelData.memories)
                            }
                        }
                    ),
                    selectedIndex: $selectedPhotoIndex,
                    isPresented: $showPhotoPreview,
                    selectedItems: $selectedItems,
                    firebaseImageCount: firebaseImages.count
                )
            }
        }
    }
    
    // Load Firebase images into the firebaseImages array
    private func loadFirebaseImages() {
        let displayMemory = currentMemory ?? memory
        guard let imageURLs = displayMemory.imageNames, !imageURLs.isEmpty else {
            return
        }
        
        isLoadingFirebaseImages = true
        Task {
            var loadedImages: [UIImage] = []
            
            for imageURL in imageURLs {
                if let url = URL(string: imageURL) {
                    do {
                        let (data, _) = try await URLSession.shared.data(from: url)
                        if let uiImage = UIImage(data: data) {
                            loadedImages.append(uiImage)
                        }
                    } catch {
                        print("Error loading Firebase image: \(error)")
                    }
                }
            }
            
            await MainActor.run {
                firebaseImages = loadedImages
                isLoadingFirebaseImages = false
            }
        }
    }
}

#Preview {
    let modelData = ModelData()
    return MemoryDetail(memory: modelData.memories[1])
        .environment(modelData)
}

// Add these helpers at the top level
func saveImageToDocuments(_ image: UIImage, fileName: String) -> String? {
    guard let data = image.jpegData(compressionQuality: 0.9) else { return nil }
    let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    let fileURL = url.appendingPathComponent(fileName)
    do {
        try data.write(to: fileURL)
        return fileURL.path
    } catch {
        print("Error saving image: \(error)")
        return nil
    }
}

func loadImageFromDocuments(path: String) -> UIImage? {
    return UIImage(contentsOfFile: path)
}

struct PhotoPreviewModal: View {
    @Binding var images: [UIImage]
    @Binding var imagePaths: [String]
    @Binding var selectedIndex: Int
    @Binding var isPresented: Bool
    @Binding var selectedItems: [PhotosPickerItem]
    var firebaseImageCount: Int = 0 // Number of Firebase images (non-deletable)
    @State private var isZoomed: Bool = false
    @State private var dragOffset: CGFloat = 0.0
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    
    // Check if current image is a Firebase image (non-deletable)
    private var isFirebaseImage: Bool {
        selectedIndex < firebaseImageCount
    }

    var body: some View {
        VStack {
            HStack {
                Button("Back") { isPresented = false }
                Spacer()
                VStack(spacing: 2) {
                    Text(Date(), style: .date)
                        .font(.subheadline)
                        .fontWeight(.bold)
                    Text(Date(), style: .time)
                        .font(.caption)
                }
                Spacer()
                Button(action: {
                    if images.indices.contains(selectedIndex) {
                        UIImageWriteToSavedPhotosAlbum(images[selectedIndex], nil, nil, nil)
                    }
                }) {
                    Image(systemName: "square.and.arrow.down")
                        .foregroundColor(.blue)
                        .font(.title2)
                }
                Button(action: {
                    // Only allow deleting user-added images, not Firebase images
                    if !isFirebaseImage && images.indices.contains(selectedIndex) {
                        let userImageIndex = selectedIndex - firebaseImageCount
                        images.remove(at: selectedIndex)
                        if imagePaths.indices.contains(userImageIndex) {
                            imagePaths.remove(at: userImageIndex)
                        }
                        if selectedItems.indices.contains(userImageIndex) {
                            selectedItems.remove(at: userImageIndex)
                        }
                        if images.isEmpty {
                            isPresented = false
                        } else if selectedIndex >= images.count {
                            selectedIndex = images.count - 1
                        }
                    }
                }) {
                    Image(systemName: "trash")
                        .foregroundColor(isFirebaseImage ? .gray : .red)
                        .font(.title2)
                }
                .disabled(isFirebaseImage)
            }
            .padding()
            Spacer()
            if images.indices.contains(selectedIndex) {
                ZStack {
                    ZoomableImage(
                        image: images[selectedIndex],
                        isZoomed: $isZoomed,
                        scale: $scale,
                        lastScale: $lastScale,
                        offset: $offset,
                        lastOffset: $lastOffset
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .contentShape(Rectangle())
                .offset(x: dragOffset)
                .gesture(
                    isZoomed ? nil : DragGesture()
                        .onChanged { value in
                            dragOffset = value.translation.width
                        }
                        .onEnded { value in
                            let threshold: CGFloat = 100
                            if dragOffset < -threshold, selectedIndex < images.count - 1 {
                                selectedIndex += 1
                            } else if dragOffset > threshold, selectedIndex > 0 {
                                selectedIndex -= 1
                            }
                            dragOffset = 0
                        }
                )
                .onChange(of: selectedIndex) { _, _ in
                    // Reset zoom and pan state when changing photo
                    scale = 1.0
                    lastScale = 1.0
                    offset = .zero
                    lastOffset = .zero
                }
            }
            Spacer()
            ScrollView(.horizontal, showsIndicators: false) {
                HStack {
                    ForEach(images.indices, id: \.self) { idx in
                        Image(uiImage: images[idx])
                            .resizable()
                            .scaledToFill()
                            .frame(width: 60, height: 60)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(idx == selectedIndex ? Color.blue : Color.clear, lineWidth: 2)
                            )
                            .onTapGesture { selectedIndex = idx }
                    }
                }
                .padding(.horizontal)
            }
            .padding(.bottom)
        }
        .background(Color.black.opacity(0.95).ignoresSafeArea())
    }
}

struct ZoomableImage: View {
    let image: UIImage
    @Binding var isZoomed: Bool
    @Binding var scale: CGFloat
    @Binding var lastScale: CGFloat
    @Binding var offset: CGSize
    @Binding var lastOffset: CGSize

    var body: some View {
        GeometryReader { geometry in
            let imageSize = image.size
            let containerSize = geometry.size
            let minScale = min(containerSize.width / imageSize.width, containerSize.height / imageSize.height)
            let clampedScale = max(scale, minScale)

            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .scaleEffect(clampedScale)
                .offset(offset)
                .gesture(
                    SimultaneousGesture(
                        MagnificationGesture()
                            .onChanged { value in
                                let newScale = lastScale * value
                                scale = max(newScale, minScale)
                                isZoomed = scale > minScale + 0.01
                            }
                            .onEnded { value in
                                let newScale = lastScale * value
                                scale = max(newScale, minScale)
                                lastScale = scale
                                isZoomed = scale > minScale + 0.01
                            },
                        DragGesture()
                            .onChanged { value in
                                offset = CGSize(
                                    width: lastOffset.width + value.translation.width,
                                    height: lastOffset.height + value.translation.height
                                )
                            }
                            .onEnded { value in
                                lastOffset = offset
                            }
                    )
                )
                .animation(.easeInOut, value: clampedScale)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
