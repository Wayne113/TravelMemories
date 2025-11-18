import SwiftUI
import PhotosUI

struct ProfileEditor: View {
    @Binding var profile: Profile
    @State private var selectedPhoto: PhotosPickerItem? = nil
    @State private var profileUIImage: UIImage? = nil

    var body: some View {
        List {
            VStack {
                if let uiImage = profileUIImage ?? {
                    if let fileName = profile.profileImageFileName {
                        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent(fileName)
                        return UIImage(contentsOfFile: url.path)
                    }
                    return nil
                }() {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 120, height: 120)
                        .clipShape(Circle())

                } else {
                    Circle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 120, height: 120)
                        .overlay(
                            Image(systemName: "person.crop.circle")
                                .font(.largeTitle)
                                .foregroundColor(.gray)
                        )
                }
                PhotosPicker("Upload Photo", selection: $selectedPhoto, matching: .images)
                    .padding(.top, 8)
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
            .padding(.bottom, 40)
            .onChange(of: selectedPhoto) { _, newValue in
                Task {
                    if let newValue,
                       let data = try? await newValue.loadTransferable(type: Data.self),
                       let uiImage = UIImage(data: data) {
                        profileUIImage = uiImage
                        // Save image to disk
                        let fileName = "profile_photo_\(UUID().uuidString).jpg"
                        if let _ = saveImageToDocuments(uiImage, fileName: fileName) {
                            profile.profileImageFileName = fileName
                        }
                    }
                }
            }

            HStack {
                Text("Username")
                Spacer()
                TextField("Username", text: $profile.username)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.trailing)
            }

            Toggle(isOn: $profile.prefersNotifications) {
                Text("Enable Notifications")
            }
        }
    }
}

#Preview {
    ProfileEditor(profile: .constant(.default))
}
