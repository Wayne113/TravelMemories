import SwiftUI


struct MemoryDetail: View {
    @Environment(ModelData.self) var modelData
    @Environment(\.dismiss) var dismiss
    var memory: Memory
    
    var memoryIndex: Int? {
        modelData.memories.firstIndex(where: { $0.id == memory.id })
    }
    
    var body: some View {
        @Bindable var modelData = modelData
        
        ScrollView {
            MapView(memory: memory)
                .frame(height: 300)

            CircleImage(image: memory.image)
                .frame(width: 200, height: 200)
                .offset(y: -100)
                .padding(.bottom, -100)

            VStack(alignment: .leading) {
                HStack {
                    Text(memory.name)
                        .font(.title)
                    Spacer()
                    if let index = memoryIndex {
                        FavoriteButton(isSet: $modelData.memories[index].isFavorite)
                    }
                }

                HStack {
                    Text(memory.state.isEmpty ? memory.country : memory.state + ", " + memory.country)
                    Spacer()
                    Text(memory.visitedDate ?? "Unknown Date")
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)

                Divider()

                Text("About \(memory.name)")
                    .font(.title2)
                Spacer()
                Text(memory.description)
            }
            .padding()
            .onChange(of: memory.isFavorite) { oldValue, newValue in
                if memoryIndex != nil {
                    saveMemories(memories: modelData.memories)
                    print("Memory favorite status changed for \(memory.name), saved memories from detail view.")
                }
            }
        }
        .navigationTitle(memory.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(role: .destructive) {
                    if let index = memoryIndex {
                        modelData.memories.remove(at: index)
                        saveMemories(memories: modelData.memories)
                        dismiss()
                    }
                } label: {
                    Label("Delete Memory", systemImage: "trash")
                }
            }
        }
    }
}

#Preview {
    let modelData = ModelData()
    return MemoryDetail(memory: modelData.memories[1])
        .environment(modelData)
}
