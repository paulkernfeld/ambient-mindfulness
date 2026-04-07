import SwiftUI
import SwiftData

struct ContentView: View {
    @Query(sort: \MindfulEntry.timestamp, order: .reverse) var entries: [MindfulEntry]

    var body: some View {
        if let latest = entries.first, let payload = latest.payload {
            VStack(spacing: 8) {
                switch payload {
                case .sentimentDelivered:
                    Text("📩")
                        .font(.largeTitle)
                case .sentimentResponse(let sentiment):
                    Text(sentiment.emoji)
                        .font(.largeTitle)
                }
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
}
