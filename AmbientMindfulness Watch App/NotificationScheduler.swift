import Foundation
import UserNotifications

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

    static func scheduleUpcoming() async {
        let center = UNUserNotificationCenter.current()

        let granted = (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
        guard granted else { return }

        center.removeAllPendingNotificationRequests()

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        for dayOffset in 0..<daysToSchedule {
            guard let date = calendar.date(byAdding: .day, value: dayOffset, to: today) else { continue }
            let times = DayScheduler.promptTimes(for: date)

            for (index, time) in times.enumerated() {
                guard time > Date() else { continue }

                let content = UNMutableNotificationContent()
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

                try? await center.add(request)
            }
        }
    }
}
