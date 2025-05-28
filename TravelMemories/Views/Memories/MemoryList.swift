/*
See the LICENSE.txt file for this sample's licensing information.

Abstract:
A view showing a list of memories.

This view displays a list of travel memories that can be filtered and favorited.
*/

import SwiftUI

struct MemoryList: View {
    @Environment(ModelData.self) var modelData
    @State private var showFavoritesOnly = false

    var filteredMemories: [Memory] {
        modelData.memories.filter { memory in
            (!showFavoritesOnly || memory.isFavorite)
        }
    }

    var body: some View {
        NavigationSplitView {
            List {
                Toggle(isOn: $showFavoritesOnly) {
                    Text("Favorites only")
                }

                ForEach(filteredMemories) { memory in
                    NavigationLink {
                        MemoryDetail(memory: memory)
                    } label: {
                        MemoryRow(memory: memory)
                    }
                }
            }
            .animation(.default, value: filteredMemories)
            .navigationTitle("Memories")
        } detail: {
            Text("Select a Memory")
        }
    }
}

#Preview {
    MemoryList()
        .environment(ModelData())
}
