import SwiftUI
import MapKit

struct MapTabView: View {
    @Environment(ModelData.self) var modelData

    // default region
    var region: MKCoordinateRegion {
        if let first = modelData.memories.first {
            return MKCoordinateRegion(
                center: first.locationCoordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.5, longitudeDelta: 0.5)
            )
        } else {
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 0, longitude: 0),
                span: MKCoordinateSpan(latitudeDelta: 60, longitudeDelta: 60)
            )
        }
    }

    var body: some View {
        Map(initialPosition: .region(region)) {
            ForEach(modelData.memories) { memory in
                Marker(memory.name, coordinate: memory.locationCoordinate)
            }
        }
        .edgesIgnoringSafeArea(.all)
    }
}

#Preview {
    MapTabView()
        .environment(ModelData())
}
