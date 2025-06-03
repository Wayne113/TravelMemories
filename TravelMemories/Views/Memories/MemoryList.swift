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
        .sorted { memory1, memory2 in
            // Sort favorites first
            if memory1.isFavorite && !memory2.isFavorite {
                return true // memory1 (favorite) comes before memory2 (not favorite)
            } else if !memory1.isFavorite && memory2.isFavorite {
                return false // memory2 (favorite) comes before memory1 (not favorite)
            } else {
                return false // Maintain original order for memories with the same favorite status
            }
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
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            if let index = modelData.memories.firstIndex(where: { $0.id == memory.id }) {
                                modelData.memories.remove(at: index)
                                saveMemories(memories: modelData.memories)
                            }
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
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
