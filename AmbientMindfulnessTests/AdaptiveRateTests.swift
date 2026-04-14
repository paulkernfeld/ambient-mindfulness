import XCTest
@testable import AmbientMindfulness

final class AdaptiveRateTests: XCTestCase {

    private let now = Date(timeIntervalSince1970: 1_700_000_000)

    private func makeEntry(_ payload: EntryPayload, minutesAgo: Double) -> MindfulEntry {
        let data = try! JSONEncoder().encode(payload)
        return MindfulEntry(
            timestamp: now.addingTimeInterval(-minutesAgo * 60),
            payloadJSON: data
        )
    }

    func testNoDataReturnsDefaults() {
        let result = AdaptiveRate.computeSpacing(entries: [], now: now)
        XCTAssertNil(result.responseInterval)
        XCTAssertEqual(result.spacing, AdaptiveRate.defaultSpacing)
    }

    func testFrequentResponsesDecreaseSpacing() {
        // Responses every ~30 min → should schedule more frequently than default 3h
        let entries = (0..<10).map { i in
            makeEntry(.sentimentResponse(sentiment: .positive), minutesAgo: Double(i * 30))
        }
        let result = AdaptiveRate.computeSpacing(entries: entries, now: now)
        XCTAssertLessThan(result.spacing, AdaptiveRate.defaultSpacing)
    }

    func testInfrequentResponsesIncreaseSpacing() {
        // Only 1 response in last day → few responses → wider spacing
        // Need > 1.0 weighted responses to get past cold-start threshold
        // Two responses: one recent, one 20h ago (still within half-life)
        let entries = [
            makeEntry(.sentimentResponse(sentiment: .positive), minutesAgo: 60),
            makeEntry(.sentimentResponse(sentiment: .positive), minutesAgo: 1200),
        ]
        let result = AdaptiveRate.computeSpacing(entries: entries, now: now)
        XCTAssertGreaterThan(result.spacing, AdaptiveRate.defaultSpacing)
    }

    func testColdStartUsesDefaults() {
        // One response → weighted count < 1.0 threshold... actually one recent response
        // has weight ≈ 1.0, so let's use an old one
        let entries = [
            makeEntry(.sentimentResponse(sentiment: .positive), minutesAgo: 2000),
        ]
        let result = AdaptiveRate.computeSpacing(entries: entries, now: now)
        XCTAssertNil(result.responseInterval)
        XCTAssertEqual(result.spacing, AdaptiveRate.defaultSpacing)
    }

    func testRecentResponsesWeighMore() {
        // Many old responses (2 days ago) + few recent → spacing should reflect recent frequency
        let old = (0..<20).map { i in
            makeEntry(.sentimentResponse(sentiment: .positive), minutesAgo: 2880 + Double(i * 30))
        }
        let recent = [
            makeEntry(.sentimentResponse(sentiment: .positive), minutesAgo: 30),
            makeEntry(.sentimentResponse(sentiment: .positive), minutesAgo: 60),
        ]
        let result = AdaptiveRate.computeSpacing(entries: old + recent, now: now)
        // Recent responses contribute more weight → spacing should be shorter than
        // if we only had old infrequent data
        let oldOnly = AdaptiveRate.computeSpacing(entries: old, now: now)
        XCTAssertLessThan(result.spacing, oldOnly.spacing)
    }

    func testSpacingClampedToMin() {
        let entries = (0..<200).map { i in
            makeEntry(.sentimentResponse(sentiment: .positive), minutesAgo: Double(i))
        }
        let result = AdaptiveRate.computeSpacing(entries: entries, now: now)
        XCTAssertGreaterThanOrEqual(result.spacing, AdaptiveRate.minSpacing)
    }

    func testSpacingClampedToMax() {
        // Very few responses, far apart
        let entries = [
            makeEntry(.sentimentResponse(sentiment: .positive), minutesAgo: 60),
            makeEntry(.sentimentResponse(sentiment: .positive), minutesAgo: 1380),
        ]
        let result = AdaptiveRate.computeSpacing(entries: entries, now: now)
        XCTAssertLessThanOrEqual(result.spacing, AdaptiveRate.maxSpacing)
    }

    func testNonResponseEntriesIgnored() {
        let entries = [
            makeEntry(.sentimentDelivered, minutesAgo: 10),
            makeEntry(.permissionGranted, minutesAgo: 20),
            makeEntry(.notificationsScheduled(count: 3, nextTime: nil), minutesAgo: 30),
        ]
        let result = AdaptiveRate.computeSpacing(entries: entries, now: now)
        XCTAssertNil(result.responseInterval)
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
