import Foundation
import WatchConnectivity
import SwiftData

final class PhoneSync: NSObject, WCSessionDelegate {
    let modelContainer: ModelContainer

    init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
        super.init()
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {}

    func sessionDidBecomeInactive(_ session: WCSession) {}

    func sessionDidDeactivate(_ session: WCSession) {
        WCSession.default.activate()
    }

    func session(
        _ session: WCSession,
        didReceiveApplicationContext applicationContext: [String: Any]
    ) {
        guard let rawEntries = applicationContext["entries"] as? [[String: Any]] else { return }

        let context = ModelContext(modelContainer)

        if let existing = try? context.fetch(FetchDescriptor<MindfulEntry>()) {
            existing.forEach { context.delete($0) }
        }

        for raw in rawEntries {
            guard let timestamp = raw["timestamp"] as? TimeInterval,
                  let payloadBytes = raw["payload"] as? [UInt8]
            else { continue }

            let entry = MindfulEntry(
                timestamp: Date(timeIntervalSince1970: timestamp),
                payloadJSON: Data(payloadBytes)
            )
            context.insert(entry)
        }

        try? context.save()
    }
}
