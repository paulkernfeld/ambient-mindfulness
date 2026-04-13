import Foundation
import WatchConnectivity
import SwiftData
import os

private let logger = Logger(subsystem: "com.paulkernfeld.AmbientMindfulness", category: "WatchSync")

final class WatchSync: NSObject, WCSessionDelegate {
    let modelContainer: ModelContainer

    init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
        super.init()
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {}

    @MainActor
    func sendAllEntries() {
        guard WCSession.default.activationState == .activated else { return }

        let context = ModelContext(modelContainer)
        let descriptor = FetchDescriptor<MindfulEntry>(sortBy: [SortDescriptor(\.timestamp)])

        do {
            let entries = try context.fetch(descriptor)
            let encoded: [[String: Any]] = entries.compactMap { entry in
                [
                    "timestamp": entry.timestamp.timeIntervalSince1970,
                    "payload": entry.payloadJSON
                ]
            }
            try WCSession.default.updateApplicationContext(["entries": encoded])
        } catch {
            logger.error("Failed to sync entries: \(error.localizedDescription)")
        }
    }
}
