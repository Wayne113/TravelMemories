import SwiftUI


struct MemoryDetail: View {
    @Environment(ModelData.self) var modelData
    var memory: Memory
    
    var memoryIndex: Int {
        modelData.memories.firstIndex(where: { $0.id == memory.id })!
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
                    FavoriteButton(isSet: $modelData.memories[memoryIndex].isFavorite)
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
            .onChange(of: modelData.memories[memoryIndex].isFavorite) { oldValue, newValue in
                saveMemories(memories: modelData.memories)
            }
        }
        .navigationTitle(memory.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    let modelData = ModelData()
    return MemoryDetail(memory: modelData.memories[1])
        .environment(modelData)
}
