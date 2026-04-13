import SwiftUI
import SwiftData

struct LogView: View {
    @Query(sort: \MindfulEntry.timestamp, order: .reverse) var entries: [MindfulEntry]

    var body: some View {
        NavigationStack {
            List(entries) { entry in
                HStack {
                    if let payload = entry.payload {
                        Text(payload.emoji)
                    }
                    Spacer()
                    VStack(alignment: .trailing) {
                        Text(entry.timestamp, style: .date)
                        Text(entry.timestamp, style: .time)
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Log")
            .overlay {
                if entries.isEmpty {
                    ContentUnavailableView(
                        "No entries yet",
                        systemImage: "bell",
                        description: Text("Responses from your watch will appear here")
                    )
                }
            }
        }
    }
}
