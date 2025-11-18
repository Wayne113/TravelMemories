import SwiftUI

struct FeatureCard: View {
    var memory: Memory

    var body: some View {
        Group {
            if memory.isFromFirebase, let imageURL = memory.firstImageURL {
                FirebaseImageView(imageURL: imageURL, placeholder: memory.image)
                    .aspectRatio(3 / 2, contentMode: .fit)
            } else {
                memory.image
                    .resizable()
                    .aspectRatio(3 / 2, contentMode: .fit)
            }
        }
        .overlay {
            TextOverlay(memory: memory)
        }
    }
}

struct TextOverlay: View {
    var memory: Memory
    
    var gradient: LinearGradient {
        .linearGradient(
            colors: [.black.opacity(0.6), .black.opacity(0)],
            startPoint: .bottom,
            endPoint: .center)
    }
    
    var body: some View {
        ZStack(alignment: .bottomLeading) {
            gradient
            VStack(alignment: .leading) {
                Text(memory.name)
                    .font(.title)
                    .bold()
                Text(memory.state.isEmpty ? memory.country : memory.state + ", " + memory.country)
            }
            .padding()
        }
        .foregroundStyle(.white)
    }
}

#Preview {
    FeatureCard(memory: ModelData().features[0])
}
