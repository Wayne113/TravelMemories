import SwiftUIzz
import PhotosUI

struct AddMemory: View {
    @Environment(ModelData.self) var modelData
    @Environment(\.dismiss) var dismiss
    
    @State private var name = ""
    @State private var city = ""
    @State private var state = ""
    @State private var description = ""
    @State private var category: Memory.Category = .beachIsland
    @State private var visitedDate = Date()
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var image: Image?
    
    var body: some View {
        NavigationView {
            Form {
                // Image section moved to top
                Section {
                    VStack {
                        if let image = image {
                            image
                                .resizable()
                                .scaledToFill()
                                .frame(width: 120, height: 120)
                                .clipShape(Circle())
                        } else {
                            Circle()
                                .fill(Color.gray.opacity(0.3))
                                .frame(width: 120, height: 120)
                                .overlay(
                                    Image(systemName: "photo")
                                        .font(.largeTitle)
                                        .foregroundColor(.gray)
                                )
                        }
                        PhotosPicker("Choose Photo", selection: $selectedPhoto, matching: .images)
                            .padding(.top, 8)
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                }
                
                Section(header: Text("Details")) {
                    TextField("Name", text: $name)
                    TextField("City", text: $city)
                    TextField("State", text: $state)
                    TextField("Description", text: $description)
                    Picker("Category", selection: $category) {
                        ForEach(Memory.Category.allCases, id: \.self) { cat in
                            Text(cat.rawValue).tag(cat)
                        }
                    }
                    DatePicker("Visited Date", selection: $visitedDate, displayedComponents: .date)
                }
            }
            .navigationTitle("Add Memory")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(action: {
                        // Add your logic to save the new memory here!
                        dismiss()
                    }) {
                        Image(systemName: "checkmark")
                    }
                }
            }
            .onChange(of: selectedPhoto) { _, newValue in
                Task {
                    if let data = try? await newValue?.loadTransferable(type: Data.self),
                       let uiImage = UIImage(data: data) {
                        image = Image(uiImage: uiImage)
                    }
                }
            }
        }
    }
}

#Preview {
    AddMemory()
        .environment(ModelData())
}
