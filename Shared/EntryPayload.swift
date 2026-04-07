import Foundation

enum EntryPayload: Codable, Equatable {
    case sentimentDelivered
    case sentimentResponse(sentiment: Sentiment)
}
