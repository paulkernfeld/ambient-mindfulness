import Foundation
import SwiftData

enum EntryLogger {
    static func log(_ payload: EntryPayload, in context: ModelContext) {
        guard let data = try? JSONEncoder().encode(payload) else { return }
        let entry = MindfulEntry(timestamp: Date(), payloadJSON: data)
        context.insert(entry)
        try? context.save()
    }
}
