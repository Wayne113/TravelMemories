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
    
    var category: Category
    enum Category: String, CaseIterable, Codable {
        case beachIsland = "Beach & Island"
        case travel = "Travel"
        case hiking = "Hiking"
    }

    private var imageName: String
    var imagePath: String?
    
    var image: Image {
        if let imagePath = imagePath,
           let uiImage = UIImage(contentsOfFile: imagePath) {
            return Image(uiImage: uiImage)
        } else if UIImage(named: imageName) != nil {
            return Image(imageName)
        } else {
            return Image(systemName: "photo") // fallback system image
        }
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

    // Custom initializer to allow creating new Memory instances
    init(id: Int, name: String, country: String, state: String, description: String, isFavorite: Bool, isFeatured: Bool, visitedDate: String?, category: Category, imageName: String, coordinates: Coordinates, imagePath: String? = nil) {
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
    }
}
