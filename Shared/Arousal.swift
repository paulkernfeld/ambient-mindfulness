import Foundation

enum Arousal: String, Codable, CaseIterable {
    case grossDull
    case subtleDull
    case subtleRestless
    case grossRestless
    case other

    var emoji: String {
        switch self {
        case .grossDull:       "😴"
        case .subtleDull:      "😪"
        case .subtleRestless:  "🐒"
        case .grossRestless:   "🤯"
        case .other:           "❓"
        }
    }
}
