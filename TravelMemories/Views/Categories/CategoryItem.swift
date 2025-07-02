import SwiftUI

struct CategoryItem: View {
    var memory: Memory
    
    var body: some View {
        VStack(alignment: .leading) {
            memory.image
                .renderingMode(.original)
                .resizable()
                .frame(width: 155, height: 155)
                .cornerRadius(5)
            Text(memory.name)
                .foregroundStyle(.primary)
                .font(.caption)
        }
        .padding(.leading, 15)
    }
}

#Preview {
    CategoryItem(memory: ModelData().memories[0])
}
