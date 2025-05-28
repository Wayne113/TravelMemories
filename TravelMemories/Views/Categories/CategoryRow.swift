import SwiftUI

struct CategoryRow: View {
    var categoryName: String
    var items: [Memory]
    
    var body: some View {
        VStack(alignment: .leading) {
            Text(categoryName)
                .font(.headline)
                .padding(.leading, 15)
                .padding(.top, 5)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 0) {
                    ForEach(items) { memory in
                        NavigationLink {
                            MemoryDetail(memory: memory)
                        } label: {
                            CategoryItem(memory: memory)
                        }
                    }
                }
            }
            .frame(height: 185)
        }
    }
}

#Preview {
    let memories = ModelData().memories
    let beachMemories = memories.filter { $0.category.rawValue == "Beach & Island" }

    return CategoryRow(
        categoryName: "Beach & Island",
        items: beachMemories
    )
}
