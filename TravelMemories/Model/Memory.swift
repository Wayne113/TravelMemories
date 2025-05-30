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
    var image: Image {
        Image(imageName)
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
}
