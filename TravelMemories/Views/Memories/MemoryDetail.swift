import SwiftUI
import PhotosUI

struct MemoryDetail: View {
    @Environment(ModelData.self) var modelData
    @Environment(\.dismiss) var dismiss
    var memory: Memory
    
    @State private var selectedItems: [PhotosPickerItem] = []
    @State private var selectedImages: [UIImage] = []
    @State private var firebaseImages: [UIImage] = []
    @State private var showPhotoPreview = false
    @State private var selectedPhotoIndex = 0
    @State private var showEditMemory = false
    
    var memoryIndex: Int? {
        modelData.memories.firstIndex(where: { $0.id == memory.id })
    }
    
    var currentMemory: Memory? {
        modelData.memories.first(where: { $0.id == memory.id })
    }
    
    var body: some View {
        @Bindable var modelData = modelData
        
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

                // Grid layout for all images
                let columns = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]
                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(firebaseImages.indices, id: \.self) { idx in
                        Image(uiImage: firebaseImages[idx])
                            .resizable()
                            .scaledToFill()
                            .frame(width: 100, height: 100)
                            .clipped()
                            .cornerRadius(8)
                            .onTapGesture {
                                selectedPhotoIndex = idx
                                showPhotoPreview = true
                            }
                    }
                    
                    ForEach(selectedImages.indices, id: \.self) { idx in
                        let image = selectedImages[idx]
                        if image.size.width > 0 && image.size.height > 0 {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 100, height: 100)
                                .clipped()
                                .cornerRadius(8)
                                .onTapGesture {
                                    selectedPhotoIndex = firebaseImages.count + idx
                                    showPhotoPreview = true
                                }
                        }
                    }
                    
            
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
                        guard !newItems.isEmpty else { return }
                        
                        var loadedImages: [Int: UIImage] = [:]
                        var savedPaths: [String] = []
                        var loadedCount = 0
                        let totalCount = newItems.count
                        
                        for (index, item) in newItems.enumerated() {
                            item.loadTransferable(type: Data.self) { result in
                                switch result {
                                case .success(let data):
                                    if let data, let uiImage = UIImage(data: data), uiImage.size.width > 0 && uiImage.size.height > 0 {
                                        DispatchQueue.main.async {
                                            loadedImages[index] = uiImage
                                            
                                            let fileName = "memory_\(memory.id)_userphoto_\(index)_\(UUID().uuidString).jpg"
                                            if let path = saveImageToDocuments(uiImage, fileName: fileName) {
                                                savedPaths.append(path)
                                            }
                                            
                                            loadedCount += 1
                                            
                                            if loadedCount == totalCount {
                                                let newImagesInOrder = (0..<totalCount).compactMap { loadedImages[$0] }
                                                let existingImages = selectedImages.filter { $0.size.width > 0 && $0.size.height > 0 }
                                                selectedImages = existingImages + newImagesInOrder
                                                
                                                if let memoryIndex = memoryIndex {
                                                    let existingPaths = modelData.memories[memoryIndex].userImagePaths ?? []
                                                    modelData.memories[memoryIndex].userImagePaths = existingPaths + savedPaths
                                                    saveMemories(memories: modelData.memories)
                                                    
                                                    let displayMemory = currentMemory ?? memory
                                                    if displayMemory.isFromFirebase {
                                                        let capturedIndex = memoryIndex
                                                        Task {
                                                            do {
                                                                let allURLs = try await FirebaseService.shared.appendImages(newImagesInOrder, to: displayMemory)
                                                                await MainActor.run {
                                                                    modelData.memories[capturedIndex].imageNames = allURLs
                                                                    modelData.memories[capturedIndex].userImagePaths = nil
                                                                    saveMemories(memories: modelData.memories)
                                                                    
                                                                    // Keep new images in selectedImages temporarily until Firebase loads
                                                                    selectedImages = existingImages + newImagesInOrder
                                                                    
                                                                    // Reload from Firebase using the new URLs directly
                                                                    loadFirebaseImagesWithURLs(allURLs)
                                                                }
                                                            } catch {
                                                                print("Upload error: \(error)")
                                                            }
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                case .failure(let error):
                                    print("Failed to load image: \(error)")
                                    loadedCount += 1
                                }
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical)
                .onAppear {
                    let displayMemory = currentMemory ?? memory
                    
                    // Load display picture first if exists
                    var initialImages: [UIImage] = []
                    if let imagePath = displayMemory.imagePath, let profileImage = UIImage(contentsOfFile: imagePath) {
                        initialImages.append(profileImage)
                    }
                    firebaseImages = initialImages
                    
                    // Load user added images from local paths
                    if let paths = displayMemory.userImagePaths {
                        selectedImages = paths.compactMap { loadImageFromDocuments(path: $0) }
                    } else {
                        selectedImages = []
                    }
                    
                    loadFirebaseImages()
                }
            }
            .padding()
            .onChange(of: displayMemory.isFavorite) { oldValue, newValue in
                if memoryIndex != nil {
                    saveMemories(memories: modelData.memories)
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
                                try await modelData.deleteMemory(displayMemory)
                                await MainActor.run {
                                    dismiss()
                                }
                            } catch {
                                print("Error deleting memory: \(error)")
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
                // Reload images after editing
                let displayMemory = currentMemory ?? memory
                
                // Load display picture first if exists
                var initialImages: [UIImage] = []
                if let imagePath = displayMemory.imagePath, let profileImage = UIImage(contentsOfFile: imagePath) {
                    initialImages.append(profileImage)
                }
                firebaseImages = initialImages
                
                // Load user added images from local paths
                if let paths = displayMemory.userImagePaths {
                    selectedImages = paths.compactMap { loadImageFromDocuments(path: $0) }
                } else {
                    selectedImages = []
                }
                
                loadFirebaseImages()
            }
        }
        .onChange(of: displayMemory.imageNames) { _, _ in
            loadFirebaseImages()
        }
        .onChange(of: displayMemory.imagePath) { _, _ in
            loadFirebaseImages()
        }
        .sheet(isPresented: $showPhotoPreview) {
            let allImages = firebaseImages + selectedImages
            if allImages.indices.contains(selectedPhotoIndex) {
                PhotoPreviewModal(
                    images: Binding(
                        get: { firebaseImages + selectedImages },
                        set: { newImages in
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
                    firebaseImageCount: firebaseImages.count,
                    memory: displayMemory,
                    firebaseImagesBinding: $firebaseImages,
                    selectedImagesBinding: $selectedImages,
                    onDelete: { deletedIndex in
                        if let memoryIndex = memoryIndex {
                            loadFirebaseImages()
                        }
                    }
                )
            }
        }
    }
    
    private func loadFirebaseImages() {
        let displayMemory = currentMemory ?? memory
        guard let imageURLs = displayMemory.imageNames, !imageURLs.isEmpty else {
            return
        }
        loadFirebaseImagesWithURLs(imageURLs)
    }
    
    private func loadFirebaseImagesWithURLs(_ imageURLs: [String]) {
        let displayMemory = currentMemory ?? memory
        
        // Check if  should use local profile picture
        let hasLocalProfile = displayMemory.imagePath != nil
        var profileImage: UIImage? = nil
        
        if hasLocalProfile {
            // Always load from local path to avoid duplicates
            if let imagePath = displayMemory.imagePath, let img = UIImage(contentsOfFile: imagePath) {
                profileImage = img
            }
        }
        
        let urlsToLoad = hasLocalProfile && imageURLs.count > 0 ? Array(imageURLs.dropFirst()) : imageURLs
        
        Task {
            // Load images in parallel for faster loading
            let loadedImages = await withTaskGroup(of: (Int, UIImage?).self) { group in
                var results: [(Int, UIImage?)] = []
                
                for (index, imageURL) in urlsToLoad.enumerated() {
                    group.addTask {
                        // Try to load from cache first
                        if let cachedImage = loadCachedImage(url: imageURL) {
                            return (index, cachedImage)
                        }
                        
                        // Load from Firebase if not cached
                        if let url = URL(string: imageURL) {
                            do {
                                let (data, _) = try await URLSession.shared.data(from: url)
                                if let uiImage = UIImage(data: data) {
                                    // Cache the image for future use
                                    cacheImage(uiImage, url: imageURL)
                                    return (index, uiImage)
                                }
                            } catch {
                                print("Error loading Firebase image: \(error)")
                            }
                        }
                        return (index, nil)
                    }
                }
                
                for await result in group {
                    results.append(result)
                }
                
                return results.sorted { $0.0 < $1.0 }.compactMap { $0.1 }
            }
            
            await MainActor.run {
                // Profile picture should always be first if it exists
                if let profileImage = profileImage {
                    // Only set if current first image is not the profile (to avoid duplicates)
                    if firebaseImages.first?.size != profileImage.size {
                        firebaseImages = [profileImage] + loadedImages
                    } else {
                        // Profile already exists, just update the rest
                        let currentProfile = firebaseImages.first!
                        firebaseImages = [currentProfile] + loadedImages
                    }
                    // Clear selectedImages after Firebase images are loaded
                    selectedImages = []
                } else {
                    firebaseImages = loadedImages
                    // Clear selectedImages after Firebase images are loaded
                    selectedImages = []
                }
            }
        }
    }
    
    private func cacheImage(_ image: UIImage, url: String) {
        guard let data = image.jpegData(compressionQuality: 0.8) else { return }
        let cacheKey = url.replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: ":", with: "_")
        let cacheURL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("image_cache_\(cacheKey).jpg")
        
        try? data.write(to: cacheURL)
    }
    
    private func loadCachedImage(url: String) -> UIImage? {
        let cacheKey = url.replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: ":", with: "_")
        let cacheURL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("image_cache_\(cacheKey).jpg")
        
        return UIImage(contentsOfFile: cacheURL.path)
    }
}

#Preview {
    let modelData = ModelData()
    return MemoryDetail(memory: modelData.memories[1])
        .environment(modelData)
}

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
    var firebaseImageCount: Int = 0
    var memory: Memory
    @Binding var firebaseImagesBinding: [UIImage]
    @Binding var selectedImagesBinding: [UIImage]
    var onDelete: (Int) -> Void
    @Environment(ModelData.self) var modelData
    @State private var isZoomed: Bool = false
    @State private var dragOffset: CGFloat = 0.0
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    
    private var isFirebaseImage: Bool {
        selectedIndex < firebaseImageCount
    }
    
    private var isProfilePicture: Bool {
        selectedIndex == 0
    }
    
    private var canDelete: Bool {
        !isProfilePicture && images.indices.contains(selectedIndex)
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
                    if canDelete {
                        if isFirebaseImage && memory.isFromFirebase {
                            // Delete from Firebase
                            Task {
                                do {
                                    let firebaseIndex = selectedIndex
                                    let updatedURLs = try await FirebaseService.shared.removeImage(at: firebaseIndex, from: memory)
                                    
                                    await MainActor.run {
                                        if let memoryIndex = modelData.memories.firstIndex(where: { $0.id == memory.id }) {
                                            modelData.memories[memoryIndex].imageNames = updatedURLs
                                            saveMemories(memories: modelData.memories)
                                        }
                                        
                                        // Update firebaseImages directly - check bounds first
                                        guard selectedIndex < firebaseImagesBinding.count else {
                                            return
                                        }
                                        
                                        firebaseImagesBinding.remove(at: selectedIndex)
                                        
                                        // Calculate new total count after deletion
                                        let newTotalCount = firebaseImagesBinding.count + selectedImagesBinding.count
                                        
                                        // Adjust selectedIndex if needed
                                        if newTotalCount == 0 {
                                            isPresented = false
                                        } else if selectedIndex >= newTotalCount {
                                            selectedIndex = max(0, newTotalCount - 1)
                                        }
                                        
                                        onDelete(selectedIndex)
                                    }
                                } catch {
                                    print("Error deleting image: \(error)")
                                }
                            }
                        } else {

                            let userImageIndex = selectedIndex - firebaseImageCount
                            
                            guard userImageIndex >= 0 && userImageIndex < selectedImagesBinding.count else {
                                return
                            }
                            
                            selectedImagesBinding.remove(at: userImageIndex)
                            
                            if userImageIndex < imagePaths.count {
                                imagePaths.remove(at: userImageIndex)
                            }
                            
                            if userImageIndex < selectedItems.count {
                                selectedItems.remove(at: userImageIndex)
                            }
                            
                            // Calculate new total count after deletion
                            let newTotalCount = firebaseImagesBinding.count + selectedImagesBinding.count
                            
                            // Adjust selectedIndex if needed
                            if newTotalCount == 0 {
                                isPresented = false
                            } else if selectedIndex >= newTotalCount {
                                selectedIndex = max(0, newTotalCount - 1)
                            }
                        }
                    }
                }) {
                    Image(systemName: "trash")
                        .foregroundColor(canDelete ? .red : .gray)
                        .font(.title2)
                }
                .disabled(!canDelete)
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

// zoom
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
