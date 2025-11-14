//
//  FirebaseService.swift
//  TravelMemories
//
//  Firebase service layer for Firestore and Storage operations
//

import Foundation
import FirebaseFirestore
import FirebaseStorage
import UIKit

class FirebaseService {
    static let shared = FirebaseService()
    
    private let db = Firestore.firestore()
    private let storage = Storage.storage()
    
    private init() {}
    
    // MARK: - Firestore Operations
    
    /// Save a memory to Firestore
    func saveMemory(_ memory: Memory, images: [UIImage]) async throws -> String {
        // First upload images to Storage
        let imageURLs = try await uploadImages(images, memoryId: "\(memory.id)")
        
        // Prepare memory data for Firestore
        var memoryData: [String: Any] = [
            "id": memory.id,
            "name": memory.name,
            "country": memory.country,
            "state": memory.state,
            "description": memory.description,
            "isFavorite": memory.isFavorite,
            "isFeatured": memory.isFeatured,
            "category": memory.category.rawValue,
            "latitude": memory.locationCoordinate.latitude,
            "longitude": memory.locationCoordinate.longitude,
            "imageURLs": imageURLs,
            "createdAt": FieldValue.serverTimestamp()
        ]
        
        if let visitedDate = memory.visitedDate {
            memoryData["visitedDate"] = visitedDate
        }
        
        // Save to Firestore
        let docRef = try await db.collection("memories").addDocument(data: memoryData)
        return docRef.documentID
    }
    
    /// Update an existing memory in Firestore
    func updateMemory(_ memory: Memory, newImages: [UIImage]?) async throws -> [String] {
        guard let documentId = memory.firestoreDocumentId else {
            throw NSError(domain: "FirebaseService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Document ID is required for update"])
        }
        
        let docRef = db.collection("memories").document(documentId)
        
        // Get existing document to check current images
        let existingDoc = try await docRef.getDocument()
        guard existingDoc.exists, let existingData = existingDoc.data() else {
            throw NSError(domain: "FirebaseService", code: 404, userInfo: [NSLocalizedDescriptionKey: "Memory document not found"])
        }
        
        var imageURLs: [String] = []
        
        // Handle image updates
        if let newImages = newImages, !newImages.isEmpty {
            // Delete old images from Storage
            if let oldImageURLs = existingData["imageURLs"] as? [String] {
                print("Deleting \(oldImageURLs.count) old images from Storage")
                try await deleteImages(oldImageURLs)
            }
            
            // Upload new images
            imageURLs = try await uploadImages(newImages, memoryId: "\(memory.id)")
        } else {
            // Keep existing images
            imageURLs = existingData["imageURLs"] as? [String] ?? []
        }
        
        // Prepare updated memory data
        var memoryData: [String: Any] = [
            "id": memory.id,
            "name": memory.name,
            "country": memory.country,
            "state": memory.state,
            "description": memory.description,
            "isFavorite": memory.isFavorite,
            "isFeatured": memory.isFeatured,
            "category": memory.category.rawValue,
            "latitude": memory.locationCoordinate.latitude,
            "longitude": memory.locationCoordinate.longitude,
            "imageURLs": imageURLs,
            "updatedAt": FieldValue.serverTimestamp()
        ]
        
        if let visitedDate = memory.visitedDate {
            memoryData["visitedDate"] = visitedDate
        }
        
        // Update document in Firestore
        try await docRef.updateData(memoryData)
        print("Successfully updated memory: \(documentId)")
        
        return imageURLs
    }
    
    /// Load all memories from Firestore
    func loadMemories() async throws -> [Memory] {
        let snapshot = try await db.collection("memories").getDocuments()
        
        var memories: [Memory] = []
        
        for document in snapshot.documents {
            let data = document.data()
            
            guard let id = data["id"] as? Int,
                  let name = data["name"] as? String,
                  let country = data["country"] as? String,
                  let state = data["state"] as? String,
                  let description = data["description"] as? String,
                  let isFavorite = data["isFavorite"] as? Bool,
                  let isFeatured = data["isFeatured"] as? Bool,
                  let categoryString = data["category"] as? String,
                  let category = Memory.Category(rawValue: categoryString),
                  let latitude = data["latitude"] as? Double,
                  let longitude = data["longitude"] as? Double else {
                continue
            }
            
            let visitedDate = data["visitedDate"] as? String
            let imageURLs = data["imageURLs"] as? [String] ?? []
            
            let memory = Memory(
                id: id,
                name: name,
                country: country,
                state: state,
                description: description,
                isFavorite: isFavorite,
                isFeatured: isFeatured,
                visitedDate: visitedDate,
                category: category,
                imageName: "", // Not used for Firebase memories
                coordinates: Memory.Coordinates(latitude: latitude, longitude: longitude),
                imagePath: nil,
                imageNames: imageURLs,
                userImagePaths: nil,
                firestoreDocumentId: document.documentID, // Set the Firebase document ID
                isFromFirebase: true // Mark as from Firebase
            )
            
            memories.append(memory)
        }
        
        return memories
    }
    
    /// Delete a memory from Firestore by document ID (more efficient)
    func deleteMemoryByDocumentId(_ documentId: String) async throws {
        print("Deleting memory by document ID: \(documentId)")
        let docRef = db.collection("memories").document(documentId)
        
        // Get document data to delete images from Storage
        let document = try await docRef.getDocument()
        if document.exists, let data = document.data() {
            if let imageURLs = data["imageURLs"] as? [String] {
                print("Deleting \(imageURLs.count) images from Storage")
                try await deleteImages(imageURLs)
            }
        } else {
            print("Warning: Document \(documentId) does not exist")
        }
        
        // Delete document from Firestore
        try await docRef.delete()
        print("Successfully deleted document: \(documentId)")
    }
    
    /// Delete a memory from Firestore by memory id (fallback method)
    func deleteMemory(id: Int) async throws {
        print("Deleting memory by id: \(id)")
        let snapshot = try await db.collection("memories")
            .whereField("id", isEqualTo: id)
            .getDocuments()
        
        print("Found \(snapshot.documents.count) document(s) with id \(id)")
        
        guard !snapshot.documents.isEmpty else {
            throw NSError(domain: "FirebaseService", code: 404, userInfo: [NSLocalizedDescriptionKey: "No memory found with id \(id)"])
        }
        
        for document in snapshot.documents {
            print("Deleting document: \(document.documentID)")
            // Delete images from Storage first
            if let imageURLs = document.data()["imageURLs"] as? [String] {
                print("Deleting \(imageURLs.count) images from Storage")
                try await deleteImages(imageURLs)
            }
            
            // Delete document from Firestore
            try await document.reference.delete()
            print("Successfully deleted document: \(document.documentID)")
        }
    }
    
    // MARK: - Storage Operations
    
    /// Upload images to Firebase Storage
    private func uploadImages(_ images: [UIImage], memoryId: String) async throws -> [String] {
        var imageURLs: [String] = []
        
        for (index, image) in images.enumerated() {
            guard let imageData = image.jpegData(compressionQuality: 0.8) else {
                continue
            }
            
            let imagePath = "memories/\(memoryId)/image_\(index).jpg"
            let storageRef = storage.reference().child(imagePath)
            
            // Upload data using async/await
            _ = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<StorageMetadata, Error>) in
                storageRef.putData(imageData, metadata: nil) { metadata, error in
                    if let error = error {
                        continuation.resume(throwing: error)
                    } else if let metadata = metadata {
                        continuation.resume(returning: metadata)
                    } else {
                        continuation.resume(throwing: NSError(domain: "FirebaseService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Unknown error uploading image"]))
                    }
                }
            }
            
            // Get download URL using async/await
            let downloadURL = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<URL, Error>) in
                storageRef.downloadURL { url, error in
                    if let error = error {
                        continuation.resume(throwing: error)
                    } else if let url = url {
                        continuation.resume(returning: url)
                    } else {
                        continuation.resume(throwing: NSError(domain: "FirebaseService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Unknown error getting download URL"]))
                    }
                }
            }
            imageURLs.append(downloadURL.absoluteString)
        }
        
        return imageURLs
    }
    
    /// Delete images from Firebase Storage
    private func deleteImages(_ imageURLs: [String]) async throws {
        for urlString in imageURLs {
            guard let url = URL(string: urlString) else { continue }
            let storageRef = storage.reference(forURL: url.absoluteString)
            
            // Delete using async/await
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                storageRef.delete { error in
                    if let error = error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume()
                    }
                }
            }
        }
    }
}

