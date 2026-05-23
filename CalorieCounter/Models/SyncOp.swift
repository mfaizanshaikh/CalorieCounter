import Foundation
import SwiftData

enum SyncEntityType: String, Codable {
    case meal
    case foodItem
    case savedFood
    case userSettings
    case photo
}

enum SyncOpType: String, Codable {
    case upsert
    case delete
}

/// Durable per-mutation record. SyncService drains these and POSTs to the
/// backend; on success the row is deleted. On failure attempts is bumped and
/// retried with exponential backoff.
@Model
final class SyncOp {
    @Attribute(.unique) var id: UUID
    var entityTypeRaw: String
    var entityId: UUID
    var opTypeRaw: String
    /// JSON payload (UTF-8). For photo uploads, the payload references a meal
    /// id whose `imageData` is read directly from SwiftData at flush time.
    var payload: Data
    var createdAt: Date
    var attempts: Int
    var lastError: String?
    /// Earliest time this op is eligible to retry. Bumped on failure.
    var nextAttemptAt: Date

    init(
        id: UUID = UUID(),
        entityType: SyncEntityType,
        entityId: UUID,
        opType: SyncOpType,
        payload: Data,
        createdAt: Date = Date(),
        attempts: Int = 0,
        lastError: String? = nil,
        nextAttemptAt: Date = Date()
    ) {
        self.id = id
        self.entityTypeRaw = entityType.rawValue
        self.entityId = entityId
        self.opTypeRaw = opType.rawValue
        self.payload = payload
        self.createdAt = createdAt
        self.attempts = attempts
        self.lastError = lastError
        self.nextAttemptAt = nextAttemptAt
    }

    var entityType: SyncEntityType {
        SyncEntityType(rawValue: entityTypeRaw) ?? .meal
    }

    var opType: SyncOpType {
        SyncOpType(rawValue: opTypeRaw) ?? .upsert
    }
}
