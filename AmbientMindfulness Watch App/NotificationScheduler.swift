import Foundation
import UserNotifications
import SwiftData

enum NotificationScheduler {
    static let categoryIdentifier = "SENTIMENT_CHECK"
    private static let daysToSchedule = 7

    static func registerCategory() {
        let actions = Sentiment.allCases.map { sentiment in
            UNNotificationAction(
                identifier: sentiment.rawValue,
                title: sentiment.emoji,
                options: []
            )
        }

        let category = UNNotificationCategory(
            identifier: categoryIdentifier,
            actions: actions,
            intentIdentifiers: [],
            options: []
        )

        UNUserNotificationCenter.current().setNotificationCategories([category])
    }

    @MainActor
    static func scheduleUpcoming(modelContainer: ModelContainer) async {
        let context = ModelContext(modelContainer)
        let center = UNUserNotificationCenter.current()

        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound])
            if granted {
                EntryLogger.log(.permissionGranted, in: context)
            } else {
                EntryLogger.log(.permissionDenied(error: nil), in: context)
                return
            }
        } catch {
            EntryLogger.log(.permissionDenied(error: error.localizedDescription), in: context)
            return
        }

        center.removeAllPendingNotificationRequests()

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        var scheduledCount = 0
        var firstTime: Date?

        for dayOffset in 0..<daysToSchedule {
            guard let date = calendar.date(byAdding: .day, value: dayOffset, to: today) else { continue }
            let times = DayScheduler.promptTimes(for: date)

            for (index, time) in times.enumerated() {
                guard time > Date() else { continue }

                let content = UNMutableNotificationContent()
                content.title = "How are you?"
                content.body = "Tap to check in"
                content.categoryIdentifier = categoryIdentifier
                content.sound = .default

                let components = calendar.dateComponents(
                    [.year, .month, .day, .hour, .minute, .second],
                    from: time
                )
                let trigger = UNCalendarNotificationTrigger(
                    dateMatching: components,
                    repeats: false
                )

                let request = UNNotificationRequest(
                    identifier: "sentiment-d\(dayOffset)-\(index)",
                    content: content,
                    trigger: trigger
                )

                do {
                    try await center.add(request)
                    scheduledCount += 1
                    if firstTime == nil { firstTime = time }
                } catch {
                    EntryLogger.log(.schedulingError(error: error.localizedDescription), in: context)
                }
            }
        }

        EntryLogger.log(.notificationsScheduled(count: scheduledCount, nextTime: firstTime), in: context)
    }

    @MainActor
    static func scheduleTestNotification(modelContainer: ModelContainer) async {
        let context = ModelContext(modelContainer)
        let center = UNUserNotificationCenter.current()

        let content = UNMutableNotificationContent()
        content.title = "Test notification"
        content.body = "Tap to check in"
        content.categoryIdentifier = categoryIdentifier
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)
        let request = UNNotificationRequest(
            identifier: "test-\(Date().timeIntervalSince1970)",
            content: content,
            trigger: trigger
        )

        do {
            try await center.add(request)
            EntryLogger.log(.testNotificationScheduled, in: context)
        } catch {
            EntryLogger.log(.schedulingError(error: error.localizedDescription), in: context)
        }
    }
}
