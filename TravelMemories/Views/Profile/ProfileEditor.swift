//
//  ProfileEditor.swift
//
//  Created by Wayne on 13/05/2025.
//

import SwiftUI

struct ProfileEditor: View {
    @Binding var profile : Profile
    
    var body: some View {
        List {
            HStack {
                Text("Username")
                Spacer()
                TextField("Username", text: $profile.username)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.trailing)
            }
            
            Toggle(isOn : $profile.prefersNotifications) {
                Text("Enable Notifications")
            }
        }
    }
}

#Preview {
    ProfileEditor(profile: .constant(.default))
}
