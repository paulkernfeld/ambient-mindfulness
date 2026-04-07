import XCTest
import SwiftData
@testable import AmbientMindfulness

final class MindfulEntryTests: XCTestCase {
    private func makeContext() throws -> ModelContext {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: MindfulEntry.self, configurations: config)
        return ModelContext(container)
    }

    func testInsertAndFetchResponse() throws {
        let context = try makeContext()
        let payload = EntryPayload.sentimentResponse(sentiment: .positive)
        let entry = MindfulEntry(
            timestamp: Date(timeIntervalSince1970: 1000),
            payloadJSON: try JSONEncoder().encode(payload)
        )
        context.insert(entry)
        try context.save()

        let results = try context.fetch(FetchDescriptor<MindfulEntry>())
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].payload, payload)
    }

    func testInsertAndFetchDelivered() throws {
        let context = try makeContext()
        let payload = EntryPayload.sentimentDelivered
        let entry = MindfulEntry(
            timestamp: Date(),
            payloadJSON: try JSONEncoder().encode(payload)
        )
        context.insert(entry)
        try context.save()

        let results = try context.fetch(FetchDescriptor<MindfulEntry>())
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].payload, .sentimentDelivered)
    }

    func testFetchSortedByTimestamp() throws {
        let context = try makeContext()
        let now = Date()
        let times: [TimeInterval] = [100, 0, 50]

        for offset in times {
            let entry = MindfulEntry(
                timestamp: now.addingTimeInterval(offset),
                payloadJSON: try JSONEncoder().encode(EntryPayload.sentimentDelivered)
            )
            context.insert(entry)
        }
        try context.save()

        let descriptor = FetchDescriptor<MindfulEntry>(sortBy: [SortDescriptor(\.timestamp)])
        let results = try context.fetch(descriptor)
        XCTAssertEqual(results.count, 3)
        XCTAssertEqual(results[0].timestamp, now)
        XCTAssertEqual(results[1].timestamp, now.addingTimeInterval(50))
        XCTAssertEqual(results[2].timestamp, now.addingTimeInterval(100))
    }
}
