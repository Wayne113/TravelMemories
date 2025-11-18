import SwiftUI
import MapKit

struct MapView: View {
    var memory: Memory

    var body: some View {
        Map(position: .constant(.region(region))) {
            Marker(memory.name, coordinate: memory.locationCoordinate)
        }
    }

    private var region: MKCoordinateRegion {
        MKCoordinateRegion(
            center: memory.locationCoordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.2, longitudeDelta: 0.2)
        )
    }
}

#Preview {
    let memory = ModelData().memories[0]
    MapView(memory: memory)
}
