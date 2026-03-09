import Foundation

struct SceneItem: Identifiable, Codable, Hashable {
    let id: UUID
    var entityId: String
    var emoji: String
    var displayName: String

    init(id: UUID = UUID(), entityId: String, emoji: String = "🎬", displayName: String) {
        self.id = id
        self.entityId = entityId
        self.emoji = emoji
        self.displayName = displayName
    }
}
