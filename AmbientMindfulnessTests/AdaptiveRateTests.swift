import XCTest
@testable import AmbientMindfulness

final class AdaptiveRateTests: XCTestCase {

    private func makeEntry(_ payload: EntryPayload, minutesAgo: Double) -> MindfulEntry {
        let data = try! JSONEncoder().encode(payload)
        return MindfulEntry(
            timestamp: Date().addingTimeInterval(-minutesAgo * 60),
            payloadJSON: data
        )
    }

    func testNoDataReturnsDefaults() {
        let result = AdaptiveRate.computeRate(entries: [])
        XCTAssertEqual(result.rate, AdaptiveRate.targetRate)
        XCTAssertEqual(result.spacing, AdaptiveRate.defaultSpacing)
    }

    func testPerfectResponseRateDecreasesSpacing() {
        // All deliveries have responses → rate > target → spacing decreases
        let entries = [
            makeEntry(.sentimentDelivered, minutesAgo: 60),
            makeEntry(.sentimentResponse(sentiment: .positive), minutesAgo: 59),
            makeEntry(.sentimentDelivered, minutesAgo: 120),
            makeEntry(.sentimentResponse(sentiment: .positive), minutesAgo: 119),
        ]
        let result = AdaptiveRate.computeRate(entries: entries)
        XCTAssertGreaterThan(result.rate, AdaptiveRate.targetRate)
        XCTAssertLessThan(result.spacing, AdaptiveRate.defaultSpacing)
    }

    func testZeroResponseRateIncreasesSpacing() {
        // Deliveries but no responses → rate < target → spacing increases
        let entries = [
            makeEntry(.sentimentDelivered, minutesAgo: 60),
            makeEntry(.sentimentDelivered, minutesAgo: 120),
            makeEntry(.sentimentDelivered, minutesAgo: 180),
        ]
        let result = AdaptiveRate.computeRate(entries: entries)
        XCTAssertLessThan(result.rate, AdaptiveRate.targetRate)
        XCTAssertGreaterThan(result.spacing, AdaptiveRate.defaultSpacing)
    }

    func testExactTargetRateKeepsDefaultSpacing() {
        // 4 out of 5 deliveries responded to (80%) at same recency
        let entries = [
            makeEntry(.sentimentDelivered, minutesAgo: 10),
            makeEntry(.sentimentResponse(sentiment: .positive), minutesAgo: 9),
            makeEntry(.sentimentDelivered, minutesAgo: 20),
            makeEntry(.sentimentResponse(sentiment: .positive), minutesAgo: 19),
            makeEntry(.sentimentDelivered, minutesAgo: 30),
            makeEntry(.sentimentResponse(sentiment: .positive), minutesAgo: 29),
            makeEntry(.sentimentDelivered, minutesAgo: 40),
            makeEntry(.sentimentResponse(sentiment: .positive), minutesAgo: 39),
            makeEntry(.sentimentDelivered, minutesAgo: 50),
            // no response for this one
        ]
        let result = AdaptiveRate.computeRate(entries: entries)
        // Rate should be close to 0.8, spacing close to default
        XCTAssertEqual(result.rate, 0.8, accuracy: 0.05)
        XCTAssertEqual(result.spacing, AdaptiveRate.defaultSpacing, accuracy: 600)
    }

    func testRecentEntriesWeighMoreThanOld() {
        // Recent: all responses. Old: no responses.
        // Rate should be > 0.5 (tilted toward recent)
        let entries = [
            makeEntry(.sentimentDelivered, minutesAgo: 30),
            makeEntry(.sentimentResponse(sentiment: .positive), minutesAgo: 29),
            makeEntry(.sentimentDelivered, minutesAgo: 60),
            makeEntry(.sentimentResponse(sentiment: .positive), minutesAgo: 59),
            // Old entries: delivered but no response (2 days ago)
            makeEntry(.sentimentDelivered, minutesAgo: 2880),
            makeEntry(.sentimentDelivered, minutesAgo: 2940),
        ]
        let result = AdaptiveRate.computeRate(entries: entries)
        XCTAssertGreaterThan(result.rate, 0.5)
    }

    func testSpacingClampedToMin() {
        // Extremely high response rate shouldn't produce sub-minute spacing
        let entries = (0..<100).flatMap { i -> [MindfulEntry] in
            [
                makeEntry(.sentimentDelivered, minutesAgo: Double(i * 10)),
                makeEntry(.sentimentResponse(sentiment: .positive), minutesAgo: Double(i * 10) - 1),
            ]
        }
        let result = AdaptiveRate.computeRate(entries: entries)
        XCTAssertGreaterThanOrEqual(result.spacing, AdaptiveRate.minSpacing)
    }

    func testSpacingClampedToMax() {
        // Very low response rate shouldn't produce multi-day spacing
        let entries = (0..<20).map { i in
            makeEntry(.sentimentDelivered, minutesAgo: Double(i * 60))
        }
        let result = AdaptiveRate.computeRate(entries: entries)
        XCTAssertLessThanOrEqual(result.spacing, AdaptiveRate.maxSpacing)
    }

    func testColdStartUsesDefaults() {
        // One delivery, no response — should use defaults, not jump to max spacing
        let entries = [
            makeEntry(.sentimentDelivered, minutesAgo: 5),
        ]
        let result = AdaptiveRate.computeRate(entries: entries)
        XCTAssertEqual(result.rate, AdaptiveRate.targetRate)
        XCTAssertEqual(result.spacing, AdaptiveRate.defaultSpacing)
    }

    func testFewDeliveriesStillUsesDefaults() {
        // Two deliveries, one response — weighted deliveries still under threshold
        let entries = [
            makeEntry(.sentimentDelivered, minutesAgo: 5),
            makeEntry(.sentimentResponse(sentiment: .positive), minutesAgo: 4),
            makeEntry(.sentimentDelivered, minutesAgo: 60),
        ]
        let result = AdaptiveRate.computeRate(entries: entries)
        // With only ~2 weighted deliveries, should still be at defaults
        XCTAssertEqual(result.spacing, AdaptiveRate.defaultSpacing)
    }

    func testNonSentimentEntriesIgnored() {
        let entries = [
            makeEntry(.permissionGranted, minutesAgo: 10),
            makeEntry(.notificationsScheduled(count: 3, nextTime: nil), minutesAgo: 20),
            makeEntry(.schedulingError(error: "test"), minutesAgo: 30),
        ]
        let result = AdaptiveRate.computeRate(entries: entries)
        // No delivery/response data → defaults
        XCTAssertEqual(result.rate, AdaptiveRate.targetRate)
        XCTAssertEqual(result.spacing, AdaptiveRate.defaultSpacing)
    }

    // MARK: - nextTime

    func testNextTimeDuringWakingHours() {
        let calendar = Calendar.current
        let noon = calendar.date(bySettingHour: 12, minute: 0, second: 0, of: Date())!
        let next = AdaptiveRate.nextTime(after: noon, spacing: 3600)
        let hour = calendar.component(.hour, from: next)
        XCTAssertGreaterThanOrEqual(hour, AdaptiveRate.wakeHour)
        XCTAssertLessThan(hour, AdaptiveRate.sleepHour)
    }

    func testNextTimeSkipsSleepHours() {
        let calendar = Calendar.current
        let lateNight = calendar.date(bySettingHour: 21, minute: 30, second: 0, of: Date())!
        let next = AdaptiveRate.nextTime(after: lateNight, spacing: 3600)
        // 21:30 + 1h = 22:30 which is during sleep → should push to next day's wake hour
        let hour = calendar.component(.hour, from: next)
        XCTAssertEqual(hour, AdaptiveRate.wakeHour)
    }

    func testNextTimePreservesSpacingDuringDay() {
        let calendar = Calendar.current
        let morning = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: Date())!
        let next = AdaptiveRate.nextTime(after: morning, spacing: 7200)
        let expected = morning.addingTimeInterval(7200)
        XCTAssertEqual(next.timeIntervalSince1970, expected.timeIntervalSince1970, accuracy: 1)
    }
}
