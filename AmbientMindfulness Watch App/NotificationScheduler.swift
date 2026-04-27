import Foundation
import UserNotifications
import SwiftData

enum CheckinAxis: String, CaseIterable {
    case sentiment
    case arousal

    var categoryIdentifier: String {
        switch self {
        case .sentiment: "SENTIMENT_CHECK"
        case .arousal:   "AROUSAL_CHECK"
        }
    }

    var title: String {
        switch self {
        case .sentiment: "Valence?"
        case .arousal:   "Activation?"
        }
    }

    var actions: [UNNotificationAction] {
        switch self {
        case .sentiment:
            return Sentiment.allCases.map {
                UNNotificationAction(identifier: $0.rawValue, title: $0.emoji, options: [])
            }
        case .arousal:
            return Arousal.allCases.map {
                UNNotificationAction(identifier: $0.rawValue, title: $0.emoji, options: [])
            }
        }
    }
}

enum NotificationScheduler {
    static func registerCategories() {
        let categories = CheckinAxis.allCases.map { axis in
            UNNotificationCategory(
                identifier: axis.categoryIdentifier,
                actions: axis.actions,
                intentIdentifiers: [],
                options: []
            )
        }
        UNUserNotificationCenter.current().setNotificationCategories(Set(categories))
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

        // Check how many are already pending (count any non-test scheduled checkin)
        let pending = await center.pendingNotificationRequests()
        let checkinPending = pending.filter { !$0.identifier.hasPrefix("test-") }
        let needed = AdaptiveRate.bufferSize - checkinPending.count
        guard needed > 0 else { return }

        // Compute adaptive spacing from entry log
        var descriptor = FetchDescriptor<MindfulEntry>(sortBy: [SortDescriptor(\.timestamp, order: .reverse)])
        descriptor.fetchLimit = 200
        let entries = (try? context.fetch(descriptor)) ?? []
        let ages = AdaptiveRate.responseAges(from: entries)
        let result = AdaptiveRate.computeSpacing(responseAges: ages)

        // Find the latest scheduled time (or now)
        let latestPending = checkinPending
            .compactMap { ($0.trigger as? UNCalendarNotificationTrigger)?.nextTriggerDate() }
            .max()
        var last = max(latestPending ?? Date(), Date())

        // Schedule up to the buffer size, picking a random axis per slot
        var scheduledCount = 0
        for i in 0..<needed {
            let time = AdaptiveRate.nextTime(after: last, spacing: result.spacing)
            let axis = CheckinAxis.allCases.randomElement()!

            let content = UNMutableNotificationContent()
            content.title = axis.title
            content.body = "Tap to check in"
            content.categoryIdentifier = axis.categoryIdentifier
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
                identifier: "checkin-\(Int(time.timeIntervalSince1970))-\(i)",
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
        let axis = CheckinAxis.allCases.randomElement()!

        let content = UNMutableNotificationContent()
        content.title = "Test: \(axis.title)"
        content.body = "Tap to check in"
        content.categoryIdentifier = axis.categoryIdentifier
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
