import Foundation

enum EntryPayload: Codable, Equatable {
    case sentimentDelivered
    case sentimentResponse(sentiment: Sentiment)
    case arousalDelivered
    case arousalResponse(arousal: Arousal)
    case permissionGranted
    case permissionDenied(error: String?)
    case notificationsScheduled(count: Int, nextTime: Date?)
    case schedulingError(error: String)
    case testNotificationScheduled

    var isResponse: Bool {
        switch self {
        case .sentimentResponse, .arousalResponse: return true
        case .sentimentDelivered, .arousalDelivered, .permissionGranted, .permissionDenied,
             .notificationsScheduled, .schedulingError, .testNotificationScheduled: return false
        }
    }

    var emoji: String {
        switch self {
        case .sentimentDelivered: return "📩"
        case .sentimentResponse(let s): return s.emoji
        case .arousalDelivered: return "📩"
        case .arousalResponse(let a): return a.emoji
        case .permissionGranted: return "🔓"
        case .permissionDenied: return "🚫"
        case .notificationsScheduled(let count, _): return "📅 \(count)"
        case .schedulingError: return "⚠️"
        case .testNotificationScheduled: return "🧪"
        }
    }

    var label: String {
        switch self {
        case .sentimentDelivered: return "Valence delivered"
        case .sentimentResponse(let s): return "Valence: \(s.emoji)"
        case .arousalDelivered: return "Activation delivered"
        case .arousalResponse(let a): return "Activation: \(a.emoji)"
        case .permissionGranted: return "Permission: OK"
        case .permissionDenied(let e): return "Permission: DENIED" + (e.map { " \($0)" } ?? "")
        case .notificationsScheduled(let c, _): return "Scheduled: \(c)"
        case .schedulingError(let e): return "Error: \(e)"
        case .testNotificationScheduled: return "Test scheduled"
        }
    }
}
