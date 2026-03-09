import Foundation

enum MenuListItem: Identifiable, Codable, Hashable {
    case scene(SceneItem)
    case divider(id: UUID)

    var id: String {
        switch self {
        case .scene(let scene):
            return scene.id.uuidString
        case .divider(let id):
            return "divider-\(id.uuidString)"
        }
    }

    static func newDivider() -> MenuListItem {
        .divider(id: UUID())
    }

    var sceneItem: SceneItem? {
        if case .scene(let item) = self { return item }
        return nil
    }
}
