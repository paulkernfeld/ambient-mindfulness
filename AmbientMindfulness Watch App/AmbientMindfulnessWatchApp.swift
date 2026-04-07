import SwiftUI
import SwiftData

@main
struct AmbientMindfulnessWatchApp: App {
    let container: ModelContainer
    private let notificationDelegate: NotificationDelegate
    private let watchSync: WatchSync

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(container)
    }

    init() {
        let container = try! ModelContainer(for: MindfulEntry.self)
        self.container = container
        self.notificationDelegate = NotificationDelegate(modelContainer: container)
        self.watchSync = WatchSync(modelContainer: container)

        UNUserNotificationCenter.current().delegate = notificationDelegate
        NotificationScheduler.registerCategory()
        Task {
            await NotificationScheduler.scheduleUpcoming()
        }
    }
}
