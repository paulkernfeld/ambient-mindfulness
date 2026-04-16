import SwiftUI
import SwiftData
import UserNotifications

struct ContentView: View {
    @Query(sort: \MindfulEntry.timestamp, order: .reverse) var entries: [MindfulEntry]
    @Environment(\.modelContext) private var modelContext
    @State private var permissionStatus: String = "..."
    @State private var pendingCount: Int = 0
    @State private var nextNotification: Date?
    @State private var adaptiveInfo: String = "..."

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                latestEntryView
                debugStatusView
                testButton
            }
            .padding(.horizontal)
        }
        .task { await refreshStatus() }
    }

    @ViewBuilder
    private var latestEntryView: some View {
        if let latest = entries.first(where: { $0.payload?.isSentiment == true }),
           let payload = latest.payload {
            VStack(spacing: 4) {
                Text(payload.emoji)
                    .font(.largeTitle)
                Text(latest.timestamp, style: .time)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } else {
            Text("Waiting for first check-in")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var debugStatusView: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Status")
                .font(.headline)

            LabeledContent("Permission", value: permissionStatus)
            LabeledContent("Pending", value: "\(pendingCount)")
            Text(adaptiveInfo)
                .font(.caption2)
                .foregroundStyle(.secondary)

            if let next = nextNotification {
                LabeledContent("Next") {
                    Text(next, style: .relative)
                }
            }

            let logEntries = entries.prefix(5)
            if !logEntries.isEmpty {
                Text("Recent log")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
                ForEach(Array(logEntries), id: \.id) { entry in
                    if let payload = entry.payload {
                        HStack {
                            Text(payload.label)
                                .font(.caption2)
                            Spacer()
                            Text(entry.timestamp, style: .time)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .font(.caption)
    }

    private var testButton: some View {
        Button("Test Notification (5s)") {
            let container = modelContext.container
            Task {
                await NotificationScheduler.scheduleTestNotification(modelContainer: container)
                await refreshStatus()
            }
        }
        .buttonStyle(.borderedProminent)
        .tint(.orange)
    }

    private func refreshStatus() async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized: permissionStatus = "Granted"
        case .denied: permissionStatus = "DENIED"
        case .notDetermined: permissionStatus = "Not asked"
        case .provisional: permissionStatus = "Provisional"
        case .ephemeral: permissionStatus = "Ephemeral"
        @unknown default: permissionStatus = "Unknown"
        }

        let pending = await center.pendingNotificationRequests()
        pendingCount = pending.count
        nextNotification = pending
            .compactMap { ($0.trigger as? UNCalendarNotificationTrigger)?.nextTriggerDate() }
            .min()

        let ages = AdaptiveRate.responseAges(from: Array(entries))
        let r = AdaptiveRate.computeSpacing(responseAges: ages)
        func fmt(_ t: TimeInterval) -> String {
            let m = Int(t / 60)
            return m >= 60 ? "\(m / 60)h \(m % 60)m" : "\(m)m"
        }
        let dataRatio = r.weightedResponses / (r.weightedResponses + r.priorCount) * 100
        adaptiveInfo = "Spacing: \(fmt(r.spacing)) (interval \(fmt(r.responseInterval)) / \(AdaptiveRate.targetRate))\n\(String(format: "%.1f", r.weightedResponses)) responses + \(String(format: "%.0f", r.priorCount)) prior (\(String(format: "%.0f", dataRatio))% data)"
    }

}
