import Foundation
import UIKit

@Observable
class ModelData {
    var memories: [Memory] = []
    var profile: Profile
    var isLoadingFromFirebase = false

    init() {
        self.profile = ModelData.loadProfile()
        // Load local memories first (for fallback)
        self.memories = loadMemories()
        sortMemories() // Sort initial memories
        // Then load from Firebase
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
    
    /// Sort memories alphabetically by name
    private func sortMemories() {
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

    /// Load memories from Firebase
    func loadMemoriesFromFirebase() async {
        isLoadingFromFirebase = true
        do {
            let firebaseMemories = try await FirebaseService.shared.loadMemories()
            // Merge with local memories (Firebase takes priority)
            await MainActor.run {
                self.memories = firebaseMemories + self.memories.filter { localMemory in
                    !firebaseMemories.contains(where: { $0.id == localMemory.id })
                }
                sortMemories() // Sort after loading from Firebase
                isLoadingFromFirebase = false
            }
        } catch {
            print("Error loading memories from Firebase: \(error)")
            await MainActor.run {
                isLoadingFromFirebase = false
            }
        }
    }

    /// Add a new memory to Firebase
    func addMemory(_ memory: Memory, images: [UIImage]) async throws {
        let documentId = try await FirebaseService.shared.saveMemory(memory, images: images)

        // Update local array
        var updatedMemory = memory
        updatedMemory.firestoreDocumentId = documentId
        updatedMemory.isFromFirebase = true

        await MainActor.run {
            self.memories.append(updatedMemory)
            sortMemories() // Sort immediately after adding
        }
    }

    /// Update an existing memory in Firebase
    func updateMemory(_ memory: Memory, newImages: [UIImage]?) async throws {
        var updatedMemory = memory
        var updatedImageURLs: [String]? = nil
        
        // If memory has a firestoreDocumentId and is from Firebase, update it
        if memory.isFromFirebase, let documentId = memory.firestoreDocumentId {
            updatedImageURLs = try await FirebaseService.shared.updateMemory(memory, newImages: newImages)
            // Update imageNames if we got new URLs
            if let imageURLs = updatedImageURLs {
                updatedMemory.imageNames = imageURLs
            }
        }
        
        // Update local array
        await MainActor.run {
            if let index = self.memories.firstIndex(where: { $0.id == memory.id }) {
                self.memories[index] = updatedMemory
                sortMemories() // Re-sort after update
            }
        }
    }

    /// Delete a memory from Firebase
    func deleteMemory(_ memory: Memory) async throws {
        // If memory has a firestoreDocumentId, use it (most efficient)
        // Otherwise, if it's marked as from Firebase, query by id
        // If neither, just remove locally
        if let documentId = memory.firestoreDocumentId {
            print("Deleting memory '\(memory.name)' using document ID: \(documentId)")
            try await FirebaseService.shared.deleteMemoryByDocumentId(documentId)
        } else if memory.isFromFirebase {
            print("Deleting memory '\(memory.name)' using id: \(memory.id)")
            try await FirebaseService.shared.deleteMemory(id: memory.id)
        } else {
            print("Memory '\(memory.name)' is not from Firebase, removing locally only")
        }

        // Remove from local array and save
        await MainActor.run {
            self.memories.removeAll { $0.id == memory.id }
            saveMemories(memories: self.memories)
        }
    }
}

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
            print("Attempting to load from bundle instead...")
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