import Foundation
import SwiftData

@Model
final class MindfulEntry {
    var timestamp: Date
    var payloadJSON: Data

    init(timestamp: Date, payloadJSON: Data) {
        self.timestamp = timestamp
        self.payloadJSON = payloadJSON
    }

    var payload: EntryPayload? {
        try? JSONDecoder().decode(EntryPayload.self, from: payloadJSON)
    }
}
