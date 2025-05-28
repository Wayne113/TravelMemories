/*
See the LICENSE.txt file for this sample's licensing information.

Abstract:
A single row to be displayed in a list of memories.

This view shows a single memory in a list format.
*/

import SwiftUI

struct MemoryRow: View {
    var memory: Memory

    var body: some View {
        HStack {
            memory.image
                .resizable()
                .frame(width: 50, height: 50)
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
