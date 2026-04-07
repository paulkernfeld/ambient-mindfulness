import Foundation
import WatchConnectivity
import SwiftData

final class WatchSync: NSObject, WCSessionDelegate {
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

    func sendAllEntries() {
        guard WCSession.default.activationState == .activated else { return }

        let context = ModelContext(modelContainer)
        let descriptor = FetchDescriptor<MindfulEntry>(sortBy: [SortDescriptor(\.timestamp)])
        guard let entries = try? context.fetch(descriptor) else { return }

        let encoded: [[String: Any]] = entries.compactMap { entry in
            [
                "timestamp": entry.timestamp.timeIntervalSince1970,
                "payload": [UInt8](entry.payloadJSON)
            ]
        }

        try? WCSession.default.updateApplicationContext(["entries": encoded])
    }
}
