import Foundation
import UserNotifications
import SwiftData

final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate, @unchecked Sendable {
    let modelContainer: ModelContainer
    @MainActor var watchSync: WatchSync?

    init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        // Delivery is logged at schedule time, not here.
        // This just ensures foreground notifications are visible.
        return [.banner, .list, .sound]
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        guard response.actionIdentifier != UNNotificationDismissActionIdentifier else { return }

        if response.actionIdentifier == UNNotificationDefaultActionIdentifier {
            // User tapped notification body (no emoji button) — still engagement
            await logSyncAndTopUp(.sentimentResponse(sentiment: .other))
        } else if let sentiment = Sentiment(rawValue: response.actionIdentifier) {
            await logSyncAndTopUp(.sentimentResponse(sentiment: sentiment))
        }
    }

    @MainActor
    private func logSyncAndTopUp(_ payload: EntryPayload) {
        let context = ModelContext(modelContainer)
        EntryLogger.log(payload, in: context)
        watchSync?.sendAllEntries()
        Task {
            await NotificationScheduler.topUp(modelContainer: modelContainer)
        }
    }
}
