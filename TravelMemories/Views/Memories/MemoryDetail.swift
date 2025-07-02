import SwiftUI
import PhotosUI

struct MemoryDetail: View {
    @Environment(ModelData.self) var modelData
    @Environment(\.dismiss) var dismiss
    var memory: Memory
    
    @State private var selectedItems: [PhotosPickerItem] = []
    @State private var selectedImages: [UIImage] = []
    @State private var showPhotoPreview = false
    @State private var selectedPhotoIndex = 0
    
    var memoryIndex: Int? {
        modelData.memories.firstIndex(where: { $0.id == memory.id })
    }
    
    var body: some View {
        @Bindable var modelData = modelData
        
        ScrollView {
            MapView(memory: memory)
                .frame(height: 300)

            CircleImage(image: memory.image)
                .frame(width: 200, height: 200)
                .offset(y: -100)
                .padding(.bottom, -100)

            VStack(alignment: .leading) {
                HStack {
                    Text(memory.name)
                        .font(.title)
                    Spacer()
                    if let index = memoryIndex {
                        FavoriteButton(isSet: $modelData.memories[index].isFavorite)
                    }
                }

                HStack {
                    Text(memory.state.isEmpty ? memory.country : memory.state + ", " + memory.country)
                    Spacer()
                    Text(memory.visitedDate ?? "Unknown Date")
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)

                Divider()

                Text("About \(memory.name)")
                    .font(.title2)
                Spacer()
                Text(memory.description)

                Divider()
                Text("Photos")
                    .font(.title2)

                // Grid layout for selected images and '+' button
                let columns = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]
                LazyVGrid(columns: columns, spacing: 8) {
                    // Show selected images
                    ForEach(selectedImages.indices, id: \.self) { idx in
                        Image(uiImage: selectedImages[idx])
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
                    // '+' button as grid item
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
                    if let paths = memory.userImagePaths {
                        selectedImages = paths.compactMap { loadImageFromDocuments(path: $0) }
                    }
                }

                // Existing code for imageNames if you want to keep it
                if let imageNames = memory.imageNames, !imageNames.isEmpty {
                    VStack(alignment: .leading) {
                        Text("More Photos")
                            .font(.title2)
                            .padding(.top)

                        ForEach(imageNames, id: \.self) {
                            imageName in
                            Image(imageName)
                                .resizable()
                                .scaledToFit()
                                .cornerRadius(10)
                                .padding(.bottom, 5)
                        }
                    }
                }
            }
            .padding()
            .onChange(of: memory.isFavorite) { oldValue, newValue in
                if memoryIndex != nil {
                    saveMemories(memories: modelData.memories)
                    print("Memory favorite status changed for \(memory.name), saved memories from detail view.")
                }
            }
        }
        .navigationTitle(memory.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(role: .destructive) {
                    if let index = memoryIndex {
                        modelData.memories.remove(at: index)
                        saveMemories(memories: modelData.memories)
                        dismiss()
                    }
                } label: {
                    Label("Delete Memory", systemImage: "trash")
                }
            }
        }
        .sheet(isPresented: $showPhotoPreview) {
            if selectedImages.indices.contains(selectedPhotoIndex) {
                PhotoPreviewModal(
                    images: $selectedImages,
                    imagePaths: Binding(
                        get: { memory.userImagePaths ?? [] },
                        set: { newPaths in
                            if let memoryIndex = memoryIndex {
                                modelData.memories[memoryIndex].userImagePaths = newPaths
                                saveMemories(memories: modelData.memories)
                            }
                        }
                    ),
                    selectedIndex: $selectedPhotoIndex,
                    isPresented: $showPhotoPreview,
                    selectedItems: $selectedItems
                )
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
    @State private var isZoomed: Bool = false
    @State private var dragOffset: CGFloat = 0.0
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

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
                    if images.indices.contains(selectedIndex) {
                        images.remove(at: selectedIndex)
                        if imagePaths.indices.contains(selectedIndex) {
                            imagePaths.remove(at: selectedIndex)
                        }
                        if selectedItems.indices.contains(selectedIndex) {
                            selectedItems.remove(at: selectedIndex)
                        }
                        if images.isEmpty {
                            isPresented = false
                        } else if selectedIndex >= images.count {
                            selectedIndex = images.count - 1
                        }
                    }
                }) {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                        .font(.title2)
                }
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
