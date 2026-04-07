import SwiftUI
import SwiftData

@main
struct AmbientMindfulnessApp: App {
    let container: ModelContainer
    private let phoneSync: PhoneSync

    var body: some Scene {
        WindowGroup {
            LogView()
        }
        .modelContainer(container)
    }

    init() {
        let container = try! ModelContainer(for: MindfulEntry.self)
        self.container = container
        self.phoneSync = PhoneSync(modelContainer: container)
    }
}
