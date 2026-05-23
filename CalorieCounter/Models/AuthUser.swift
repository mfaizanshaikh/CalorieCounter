import Foundation
import SwiftData

enum AuthProvider: String, Codable {
    case google
    case apple
}

@Model
final class AuthUser {
    @Attribute(.unique) var id: UUID
    var email: String
    var name: String?
    var photoURL: String?
    var provider: AuthProvider
    var providerSubject: String
    var createdAt: Date
    var lastSignedInAt: Date

    init(
        id: UUID = UUID(),
        email: String,
        name: String? = nil,
        photoURL: String? = nil,
        provider: AuthProvider,
        providerSubject: String,
        createdAt: Date = Date(),
        lastSignedInAt: Date = Date()
    ) {
        self.id = id
        self.email = email
        self.name = name
        self.photoURL = photoURL
        self.provider = provider
        self.providerSubject = providerSubject
        self.createdAt = createdAt
        self.lastSignedInAt = lastSignedInAt
    }
}
