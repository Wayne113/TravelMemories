import Foundation

struct Profile: Codable, Equatable {
    var username: String
    var prefersNotifications = true
    var profileImageFileName: String? = nil
    
    static let `default` = Profile(username: "wayne113_")
    
}
