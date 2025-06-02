import SwiftUI
import PhotosUI
import MapKit

class SearchCompleterDelegate: NSObject, MKLocalSearchCompleterDelegate {
    var onResultsUpdate: (([MKLocalSearchCompletion]) -> Void)?

    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        onResultsUpdate?(completer.results)
    }

    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        onResultsUpdate?([])
    }
}

struct AddMemory: View {
    @Environment(ModelData.self) var modelData
    @Environment(\.dismiss) var dismiss
    
    @State private var name = ""
    @State private var country = ""
    @State private var state = ""
    @State private var description = ""
    @State private var category: Memory.Category = .beachIsland
    @State private var visitedDate = Date()
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var image: Image?
    @State private var isFeatured = false
    @State private var isFavorite = false
    
    // Location search states
    @State private var searchResults: [MKLocalSearchCompletion] = []
    @State private var searchCompleter = MKLocalSearchCompleter()
    private var searchCompleterDelegate = SearchCompleterDelegate()
    @State private var isSearching = false
    @State private var ignoreNameChange = false
    @State private var coordinates: Memory.Coordinates?
    @State private var savedImagePath: String?
    
    var body: some View {
        NavigationView {
            Form {
                // Image section moved to top
                Section {
                    VStack {
                        if let image = image {
                            image
                                .resizable()
                                .scaledToFill()
                                .frame(width: 120, height: 120)
                                .clipShape(Circle())
                        } else {
                            Circle()
                                .fill(Color.gray.opacity(0.3))
                                .frame(width: 120, height: 120)
                                .overlay(
                                    Image(systemName: "photo")
                                        .font(.largeTitle)
                                        .foregroundColor(.gray)
                                )
                        }
                        PhotosPicker("Choose Photo", selection: $selectedPhoto, matching: .images)
                            .padding(.top, 8)
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                }
                
                Section(header: Text("Details")) {
                    TextField("Name", text: $name)
                        .onChange(of: name) { _, newValue in
                            if ignoreNameChange {
                                ignoreNameChange = false
                                return
                            }
                            if !newValue.isEmpty {
                                searchCompleter.queryFragment = newValue
                                isSearching = true
                            } else {
                                searchResults = []
                                isSearching = false
                            }
                        }
                    
                    if isSearching && !searchResults.isEmpty {
                        ForEach(searchResults, id: \.self) { result in
                            Button(action: {
                                selectLocation(result)
                            }) {
                                VStack(alignment: .leading) {
                                    Text(result.title)
                                        .foregroundColor(.primary)
                                    Text(result.subtitle)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                    
                    TextField("State", text: $state)
                    TextField("Country", text: $country)
                    TextField("Description", text: $description)
                    Picker("Category", selection: $category) {
                        ForEach(Memory.Category.allCases, id: \.self) { cat in
                            Text(cat.rawValue).tag(cat)
                        }
                    }
                    DatePicker("Visited Date", selection: $visitedDate, displayedComponents: .date)
                }
                
                Section(header: Text("Status")) {
                    Toggle("Favorite", isOn: $isFavorite)
                    Toggle("Featured", isOn: $isFeatured)
                }
            }
            .navigationTitle("Add Memory")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(action: {
                        saveMemory()
                        dismiss()
                    }) {
                        Image(systemName: "checkmark")
                    }
                }
            }
            .onChange(of: selectedPhoto) { _, newValue in
                Task {
                    if let data = try? await newValue?.loadTransferable(type: Data.self),
                       let uiImage = UIImage(data: data) {
                        let squared = cropToSquare(image: uiImage)
                        let displaySize: CGFloat = 200
                        let scale = UIScreen.main.scale
                        let scaledSize = displaySize * scale
                        let resized = resizeImage(squared, targetSize: CGSize(width: scaledSize, height: scaledSize))
                        image = Image(uiImage: resized)
                        // Save image to disk
                        if let path = saveImageToDocuments(uiImage: resized) {
                            savedImagePath = path
                        }
                    }
                }
            }
        }
        .onAppear {
            searchCompleter.delegate = searchCompleterDelegate
            searchCompleterDelegate.onResultsUpdate = { results in
                self.searchResults = results
            }
        }
    }
    
    private func saveMemory() {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .long
        let formattedDate = dateFormatter.string(from: visitedDate)
        
        let newMemory = Memory(
            id: modelData.memories.count + 1000, // Generate a new ID
            name: name,
            country: country,
            state: state,
            description: description,
            isFavorite: isFavorite,
            isFeatured: isFeatured,
            visitedDate: formattedDate,
            category: category,
            imageName: "placeholder", // fallback asset
            coordinates: coordinates ?? Memory.Coordinates(latitude: 0, longitude: 0),
            imagePath: savedImagePath // use the saved path
        )
        
        modelData.memories.append(newMemory)
    }
    
    private func selectLocation(_ result: MKLocalSearchCompletion) {
        //after location selection, the search bar dismissed
        DispatchQueue.main.async {
            self.searchResults = []
            self.isSearching = false
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        }

        let searchRequest = MKLocalSearch.Request(completion: result)
        let search = MKLocalSearch(request: searchRequest)

        search.start { response, error in
            guard let response = response, error == nil else { return }

            if let item = response.mapItems.first {
                let placemark = item.placemark

                // Prevent onChange from firing
                ignoreNameChange = true
                name = result.title
                state = placemark.administrativeArea ?? ""
                country = placemark.country ?? ""
                
                // Save coordinates
                coordinates = Memory.Coordinates(
                    latitude: placemark.coordinate.latitude,
                    longitude: placemark.coordinate.longitude
                )
            }
        }
    }
    
    // Helper to save image to disk
    private func saveImageToDocuments(uiImage: UIImage) -> String? {
        guard let data = uiImage.jpegData(compressionQuality: 0.8) else { return nil }
        let filename = UUID().uuidString + ".jpg"
        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent(filename)
        do {
            try data.write(to: url)
            return url.path
        } catch {
            print("Error saving image: \(error)")
            return nil
        }
    }
    
    // Helper to resize image to a target size
    private func resizeImage(_ image: UIImage, targetSize: CGSize) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
    }
    
    // Helper to crop image to a square
    private func cropToSquare(image: UIImage) -> UIImage {
        let originalWidth  = image.size.width
        let originalHeight = image.size.height
        let edge = min(originalWidth, originalHeight)
        let posX = (originalWidth  - edge) / 2.0
        let posY = (originalHeight - edge) / 2.0
        let cropSquare = CGRect(x: posX, y: posY, width: edge, height: edge)
        if let cgImage = image.cgImage?.cropping(to: cropSquare) {
            return UIImage(cgImage: cgImage, scale: image.scale, orientation: image.imageOrientation)
        }
        return image
    }
}

#Preview {
    AddMemory()
        .environment(ModelData())
}
