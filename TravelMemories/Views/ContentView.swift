import SwiftUI

struct ContentView: View {
    @State private var modelData = ModelData()
    
    var body: some View {
        TabView {
            CategoryHome()
                .tabItem {
                    Label("Home", systemImage: "house")
                }
            
            MapTabView()
                .tabItem {
                    Label("Map", systemImage: "map")
                }
            
            MemoryList()
                .tabItem {
                    Label("List", systemImage: "list.bullet")
                }
        }
        .environment(modelData)
    }
}

#Preview {
    ContentView()
}
