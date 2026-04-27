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
        let category = notification.request.content.categoryIdentifier
        let payload: EntryPayload = category == CheckinAxis.arousal.categoryIdentifier
            ? .arousalDelivered
            : .sentimentDelivered
        await logAndSync(payload)
        return [.banner, .list, .sound]
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        guard response.actionIdentifier != UNNotificationDismissActionIdentifier else { return }

        let category = response.notification.request.content.categoryIdentifier
        let isArousal = category == CheckinAxis.arousal.categoryIdentifier

        if response.actionIdentifier == UNNotificationDefaultActionIdentifier {
            // Tapped notification body (no emoji button) — log as "other" on the right axis
            let payload: EntryPayload = isArousal
                ? .arousalResponse(arousal: .other)
                : .sentimentResponse(sentiment: .other)
            await logSyncAndTopUp(payload)
        } else if isArousal, let arousal = Arousal(rawValue: response.actionIdentifier) {
            await logSyncAndTopUp(.arousalResponse(arousal: arousal))
        } else if let sentiment = Sentiment(rawValue: response.actionIdentifier) {
            await logSyncAndTopUp(.sentimentResponse(sentiment: sentiment))
        }
    }

    @MainActor
    private func logAndSync(_ payload: EntryPayload) {
        let context = ModelContext(modelContainer)
        EntryLogger.log(payload, in: context)
        watchSync?.sendAllEntries()
    }

    @MainActor
    private func logSyncAndTopUp(_ payload: EntryPayload) {
        logAndSync(payload)
        Task {
            await NotificationScheduler.topUp(modelContainer: modelContainer)
        }
    }
}
