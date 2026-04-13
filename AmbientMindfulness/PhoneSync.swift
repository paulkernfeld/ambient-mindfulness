import Foundation
import WatchConnectivity
import SwiftData
import os

private let logger = Logger(subsystem: "com.paulkernfeld.AmbientMindfulness", category: "PhoneSync")

@MainActor
final class PhoneSync: NSObject, WCSessionDelegate {
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

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}

    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        WCSession.default.activate()
    }

    nonisolated func session(
        _ session: WCSession,
        didReceiveApplicationContext applicationContext: [String: Any]
    ) {
        let container = modelContainer
        Task { @MainActor in
            guard let rawEntries = applicationContext["entries"] as? [[String: Any]] else { return }

            let context = ModelContext(container)

            do {
                let existing = try context.fetch(FetchDescriptor<MindfulEntry>())
                existing.forEach { context.delete($0) }
            } catch {
                logger.error("Failed to fetch existing entries: \(error.localizedDescription)")
            }

            for raw in rawEntries {
                guard let timestamp = raw["timestamp"] as? TimeInterval,
                      let payloadData = raw["payload"] as? Data
                else { continue }

                let entry = MindfulEntry(
                    timestamp: Date(timeIntervalSince1970: timestamp),
                    payloadJSON: payloadData
                )
                context.insert(entry)
            }

            do {
                try context.save()
            } catch {
                logger.error("Failed to save synced entries: \(error.localizedDescription)")
            }
        }
    }
}
