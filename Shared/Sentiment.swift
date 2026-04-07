import Foundation

enum Sentiment: String, Codable, CaseIterable {
    case veryPositive
    case positive
    case negative
    case veryNegative
    case other

    var emoji: String {
        switch self {
        case .veryPositive: "🤩"
        case .positive:     "😊"
        case .negative:     "😐"
        case .veryNegative: "😤"
        case .other:        "❓"
        }
    }
}
