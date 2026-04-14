import Foundation
import UserNotifications
import SwiftData

enum NotificationScheduler {
    static let categoryIdentifier = "SENTIMENT_CHECK"

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

    /// Top up pending notifications to the buffer size.
    /// Safe to call from any trigger (app open, response, background).
    /// Idempotent — does nothing if buffer is already full.
    @MainActor
    static func topUp(modelContainer: ModelContainer) async {
        let context = ModelContext(modelContainer)
        let center = UNUserNotificationCenter.current()

        // Ensure permission
        let settings = await center.notificationSettings()
        if settings.authorizationStatus != .authorized {
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
        }

        // Check how many are already pending
        let pending = await center.pendingNotificationRequests()
        let sentimentPending = pending.filter { $0.identifier.hasPrefix("sentiment-") }
        let needed = AdaptiveRate.bufferSize - sentimentPending.count
        guard needed > 0 else { return }

        // Compute adaptive spacing from entry log
        var descriptor = FetchDescriptor<MindfulEntry>(sortBy: [SortDescriptor(\.timestamp, order: .reverse)])
        descriptor.fetchLimit = 200
        let entries = (try? context.fetch(descriptor)) ?? []
        let result = AdaptiveRate.computeSpacing(entries: entries)

        // Find the latest scheduled time (or now)
        let latestPending = sentimentPending
            .compactMap { ($0.trigger as? UNCalendarNotificationTrigger)?.nextTriggerDate() }
            .max()
        var last = max(latestPending ?? Date(), Date())

        // Schedule up to the buffer size
        var scheduledCount = 0
        for i in 0..<needed {
            let time = AdaptiveRate.nextTime(after: last, spacing: result.spacing)

            let content = UNMutableNotificationContent()
            content.title = "How are you?"
            content.body = "Tap to check in"
            content.categoryIdentifier = categoryIdentifier
            content.sound = .default

            let components = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute, .second],
                from: time
            )
            let trigger = UNCalendarNotificationTrigger(
                dateMatching: components,
                repeats: false
            )

            let request = UNNotificationRequest(
                identifier: "sentiment-\(Int(time.timeIntervalSince1970))-\(i)",
                content: content,
                trigger: trigger
            )

            do {
                try await center.add(request)
                scheduledCount += 1
                last = time
            } catch {
                EntryLogger.log(.schedulingError(error: error.localizedDescription), in: context)
            }
        }

        if scheduledCount > 0 {
            EntryLogger.log(.notificationsScheduled(count: scheduledCount, nextTime: last), in: context)
        }
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
