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
        let watchSync = WatchSync(modelContainer: container)
        self.watchSync = watchSync
        let notificationDelegate = NotificationDelegate(modelContainer: container)
        notificationDelegate.watchSync = watchSync
        self.notificationDelegate = notificationDelegate

        UNUserNotificationCenter.current().delegate = notificationDelegate
        NotificationScheduler.registerCategories()
        Task {
            await NotificationScheduler.topUp(modelContainer: container)
        }
    }
}
