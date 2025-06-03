import Foundation

@Observable
class ModelData {
    var memories: [Memory] = loadMemories()
    var profile = Profile.default
    
    var features: [Memory] {
        memories.filter { $0.isFeatured }
    }
    
    var categories: [String: [Memory]] {
        Dictionary(
            grouping: memories,
            by: { $0.category.rawValue }
        )
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