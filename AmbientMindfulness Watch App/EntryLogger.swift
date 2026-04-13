import Foundation
import SwiftData
import os

private let logger = Logger(subsystem: "com.paulkernfeld.AmbientMindfulness", category: "EntryLogger")

enum EntryLogger {
    static func log(_ payload: EntryPayload, in context: ModelContext) {
        do {
            let data = try JSONEncoder().encode(payload)
            let entry = MindfulEntry(timestamp: Date(), payloadJSON: data)
            context.insert(entry)
            try context.save()
        } catch {
            logger.error("Failed to log entry: \(error.localizedDescription)")
        }
    }
}
