import Foundation
import UIKit

@Observable
class ModelData {
    var memories: [Memory] = []
    var profile: Profile
    var isLoadingFromFirebase = false

    init() {
        self.memories = loadMemories()
        self.profile = ModelData.loadProfile()
        sortMemories()
        Task {
            await loadMemoriesFromFirebase()
        }
    }
    
    var features: [Memory] {
        memories.filter { $0.isFeatured }
    }
    
    var categories: [String: [Memory]] {
        Dictionary(
            grouping: memories,
            by: { $0.category.rawValue }
        )
    }
    

    func sortMemories() {
        memories.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    func saveProfile() {
        if let encoded = try? JSONEncoder().encode(profile) {
            UserDefaults.standard.set(encoded, forKey: "userProfile")
        }
    }
    
    static func loadProfile() -> Profile {
        if let data = UserDefaults.standard.data(forKey: "userProfile"),
           let profile = try? JSONDecoder().decode(Profile.self, from: data) {
            return profile
        }
        return Profile.default
    }

    
    // Firebase
    func loadMemoriesFromFirebase() async {
        isLoadingFromFirebase = true
        do {
            let firebaseMemories = try await FirebaseService.shared.loadMemories()
            await MainActor.run {
                self.memories = firebaseMemories + self.memories.filter { localMemory in
                    !firebaseMemories.contains(where: { $0.id == localMemory.id })
                }
                sortMemories()
                isLoadingFromFirebase = false
            }
        } catch {
            print("Error loading memories from Firebase: \(error)")
            await MainActor.run {
                isLoadingFromFirebase = false
            }
        }
    }

    func addMemory(_ memory: Memory, images: [UIImage]) async throws {
        let documentId = try await FirebaseService.shared.saveMemory(memory, images: images)

        var updatedMemory = memory
        updatedMemory.firestoreDocumentId = documentId
        updatedMemory.isFromFirebase = true

        await MainActor.run {
            self.memories.append(updatedMemory)
            sortMemories()
        }
    }

    func updateMemory(_ memory: Memory, newImages: [UIImage]?) async throws {
        var updatedMemory = memory
        var updatedImageURLs: [String]? = nil
        
        if memory.isFromFirebase {
            updatedImageURLs = try await FirebaseService.shared.updateMemory(memory, newImages: newImages)
            if let imageURLs = updatedImageURLs {
                updatedMemory.imageNames = imageURLs
            }
        }
        
        await MainActor.run {
            if let index = self.memories.firstIndex(where: { $0.id == memory.id }) {
                if memory.imagePath != self.memories[index].imagePath {
                    updatedMemory.imagePath = memory.imagePath
                }
                self.memories[index] = updatedMemory
                saveMemories(memories: self.memories)
                sortMemories()
            }
        }
    }

    func deleteMemory(_ memory: Memory) async throws {
        if let documentId = memory.firestoreDocumentId {
            try await FirebaseService.shared.deleteMemoryByDocumentId(documentId)
        } else if memory.isFromFirebase {
            try await FirebaseService.shared.deleteMemory(id: memory.id)
        } else {
            print("Memory '\(memory.name)' is not from Firebase, removing locally only")
        }
        
        await MainActor.run {
            self.memories.removeAll { $0.id == memory.id }
            saveMemories(memories: self.memories)
        }
    }
}


// to local JSON (first launch)
func loadMemories() -> [Memory] {
    let filename = "memories.json"
    let urls = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
    let fileURL = urls[0].appendingPathComponent(filename)

    if FileManager.default.fileExists(atPath: fileURL.path) {
        do {
            let data = try Data(contentsOf: fileURL)
            let decoder = JSONDecoder()
            return try decoder.decode([Memory].self, from: data)
        } catch {
            print("Error loading memories from Documents: \(error)")
        }
    }

    guard let bundleURL = Bundle.main.url(forResource: "memoryData", withExtension: "json") else {
        fatalError("Couldn't find memoryData.json in main bundle.")
    }

    do {
        let data = try Data(contentsOf: bundleURL)
        let decoder = JSONDecoder()
        return try decoder.decode([Memory].self, from: data)
    } catch {
        fatalError("Couldn't load memoryData.json from main bundle: \(error)")
    }
}

func saveMemories(memories: [Memory]) {
    let filename = "memories.json"
    let urls = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
    guard let fileURL = urls.first?.appendingPathComponent(filename) else {
        fatalError("Couldn't create URL for \(filename) in Documents directory.")
    }

    let encoder = JSONEncoder()
    encoder.outputFormatting = .prettyPrinted

    do {
        let data = try encoder.encode(memories)
        try data.write(to: fileURL)
        print("Memories successfully saved to \(fileURL.path)")
    } catch {
        print("Error saving memories: \(error)")
    }
}
