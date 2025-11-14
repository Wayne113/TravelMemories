import Foundation
import SwiftUI
import CoreLocation

struct Memory: Hashable, Codable, Identifiable {
    var id: Int
    var name: String
    var country: String
    var state: String
    var description: String
    var isFavorite: Bool
    var isFeatured: Bool
    var visitedDate: String?
    var firestoreDocumentId: String? // Firebase document ID
    var isFromFirebase: Bool = false // Track if memory is from Firebase
    
    var category: Category
    enum Category: String, CaseIterable, Codable {
        case beachIsland = "Beach & Island"
        case travel = "Travel"
        case hiking = "Hiking"


    }

    private var imageName: String
    var imagePath: String?
    
    var image: Image {
        // Priority: Firebase URL > Local path > Asset name > Placeholder
        if isFromFirebase, let firstImageURL = imageNames?.first {
            // For Firebase images, we'll use FirebaseImageView instead
            // This property is kept for backward compatibility
            return Image(systemName: "photo")
        } else if let imagePath = imagePath,
           let uiImage = UIImage(contentsOfFile: imagePath) {
            return Image(uiImage: uiImage)
        } else if UIImage(named: imageName) != nil {
            return Image(imageName)
        } else {
            return Image(systemName: "photo") // fallback system image
        }
    }

    // Helper to get the first image URL for Firebase memories
    var firstImageURL: String? {
        return imageNames?.first
    }

    private var coordinates: Coordinates
    var locationCoordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(
            latitude: coordinates.latitude,
            longitude: coordinates.longitude)
    }

    struct Coordinates: Hashable, Codable {
        var latitude: Double
        var longitude: Double
    }

    var imageNames: [String]?
    var userImagePaths: [String]?

    // Custom initializer to allow creating new Memory instances
    init(id: Int, name: String, country: String, state: String, description: String, isFavorite: Bool, isFeatured: Bool, visitedDate: String?, category: Category, imageName: String, coordinates: Coordinates, imagePath: String? = nil, imageNames: [String]? = nil, userImagePaths: [String]? = nil, firestoreDocumentId: String? = nil, isFromFirebase: Bool = false) {
        self.id = id
        self.name = name
        self.country = country
        self.state = state
        self.description = description
        self.isFavorite = isFavorite
        self.isFeatured = isFeatured
        self.visitedDate = visitedDate
        self.category = category
        self.imageName = imageName
        self.coordinates = coordinates
        self.imagePath = imagePath
        self.imageNames = imageNames
        self.userImagePaths = userImagePaths
        self.firestoreDocumentId = firestoreDocumentId
        self.isFromFirebase = isFromFirebase
    }

    // Custom Codable implementation to handle missing Firebase fields in old JSON
    enum CodingKeys: String, CodingKey {
        case id, name, country, state, description, isFavorite, isFeatured, visitedDate
        case firestoreDocumentId, isFromFirebase
        case category, imageName, coordinates, imagePath, imageNames, userImagePaths
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        country = try container.decode(String.self, forKey: .country)
        state = try container.decode(String.self, forKey: .state)
        description = try container.decode(String.self, forKey: .description)
        isFavorite = try container.decode(Bool.self, forKey: .isFavorite)
        isFeatured = try container.decode(Bool.self, forKey: .isFeatured)
        visitedDate = try container.decodeIfPresent(String.self, forKey: .visitedDate)

        // Firebase fields with defaults for backward compatibility
        firestoreDocumentId = try container.decodeIfPresent(String.self, forKey: .firestoreDocumentId)
        isFromFirebase = try container.decodeIfPresent(Bool.self, forKey: .isFromFirebase) ?? false

        category = try container.decode(Category.self, forKey: .category)
        imageName = try container.decode(String.self, forKey: .imageName)
        coordinates = try container.decode(Coordinates.self, forKey: .coordinates)
        imagePath = try container.decodeIfPresent(String.self, forKey: .imagePath)
        imageNames = try container.decodeIfPresent([String].self, forKey: .imageNames)
        userImagePaths = try container.decodeIfPresent([String].self, forKey: .userImagePaths)
    }
}
