/*
See the LICENSE.txt file for this sample's licensing information.

Abstract:
A view showing the list of memories.

This view displays the main list of travel memories.
*/

import SwiftUI

/// A view showing the list of memories.
///
/// This view displays the main list of travel memories.

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
