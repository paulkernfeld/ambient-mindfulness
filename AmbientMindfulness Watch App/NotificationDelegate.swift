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
        await logSyncAndTopUp(.sentimentDelivered)
        return [.banner, .list, .sound]
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        guard response.actionIdentifier != UNNotificationDismissActionIdentifier,
              response.actionIdentifier != UNNotificationDefaultActionIdentifier,
              let sentiment = Sentiment(rawValue: response.actionIdentifier)
        else { return }

        await logSyncAndTopUp(.sentimentResponse(sentiment: sentiment))
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
