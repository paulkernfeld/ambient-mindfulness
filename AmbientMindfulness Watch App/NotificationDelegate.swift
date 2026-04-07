import Foundation
import UserNotifications
import SwiftData

final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    let modelContainer: ModelContainer

    init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        let context = ModelContext(modelContainer)
        EntryLogger.log(.sentimentDelivered, in: context)
        return [.sound]
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        guard response.actionIdentifier != UNNotificationDismissActionIdentifier,
              response.actionIdentifier != UNNotificationDefaultActionIdentifier,
              let sentiment = Sentiment(rawValue: response.actionIdentifier)
        else { return }

        let context = ModelContext(modelContainer)
        EntryLogger.log(.sentimentResponse(sentiment: sentiment), in: context)
    }
}
