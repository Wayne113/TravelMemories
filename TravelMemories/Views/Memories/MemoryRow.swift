import SwiftUI

struct MemoryRow: View {
    var memory: Memory

    var body: some View {
        HStack {
            if memory.isFromFirebase, let imageURL = memory.firstImageURL {
                FirebaseImageView(imageURL: imageURL, placeholder: memory.image)
                    .frame(width: 50, height: 50)
                    .clipShape(RoundedRectangle(cornerRadius: 5))
            } else {
                memory.image
                    .resizable()
                    .frame(width: 50, height: 50)
            }
            Text(memory.name)

            Spacer()

            if memory.isFavorite {
                Image(systemName: "star.fill")
                    .foregroundStyle(.yellow)
            }
        }
    }
}

#Preview {
    let memories = ModelData().memories
    return Group {
        MemoryRow(memory: memories[0])
        MemoryRow(memory: memories[1])
    }
}
