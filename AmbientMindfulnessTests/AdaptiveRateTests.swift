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

    // MARK: - Prior behavior

    func testNoDataProducesDefaultSpacing() {
        let result = AdaptiveRate.computeSpacing(entries: [], now: now)
        XCTAssertEqual(result.spacing, AdaptiveRate.defaultSpacing, accuracy: 1)
        XCTAssertEqual(result.weightedResponses, 0)
        XCTAssertGreaterThan(result.priorCount, 0)
    }

    func testPriorDominatesWithFewResponses() {
        // 1 recent response barely shifts from default
        let entries = [makeEntry(.sentimentResponse(sentiment: .positive), minutesAgo: 30)]
        let result = AdaptiveRate.computeSpacing(entries: entries, now: now)
        // Should be close to default (prior dominates)
        XCTAssertEqual(result.spacing, AdaptiveRate.defaultSpacing, accuracy: 600) // within 10 min
    }

    func testDataGraduallyOverridesPrior() {
        // More responses → spacing moves further from default
        let few = (0..<3).map { i in
            makeEntry(.sentimentResponse(sentiment: .positive), minutesAgo: Double(i * 60))
        }
        let many = (0..<30).map { i in
            makeEntry(.sentimentResponse(sentiment: .positive), minutesAgo: Double(i * 60))
        }
        let fewResult = AdaptiveRate.computeSpacing(entries: few, now: now)
        let manyResult = AdaptiveRate.computeSpacing(entries: many, now: now)
        // Both should differ from default, but many should differ more
        let fewDelta = abs(fewResult.spacing - AdaptiveRate.defaultSpacing)
        let manyDelta = abs(manyResult.spacing - AdaptiveRate.defaultSpacing)
        XCTAssertGreaterThan(manyDelta, fewDelta)
    }

    // MARK: - Convergence direction

    func testManyFrequentResponsesDecreasesSpacing() {
        // 50 responses every 30 min → much more than default rate → spacing should decrease
        let entries = (0..<50).map { i in
            makeEntry(.sentimentResponse(sentiment: .positive), minutesAgo: Double(i * 30))
        }
        let result = AdaptiveRate.computeSpacing(entries: entries, now: now)
        XCTAssertLessThan(result.spacing, AdaptiveRate.defaultSpacing)
    }

    func testManyResponsesProduceShorterSpacingThanFew() {
        let many = (0..<50).map { i in
            makeEntry(.sentimentResponse(sentiment: .positive), minutesAgo: Double(i * 30))
        }
        let few = (0..<6).map { i in
            makeEntry(.sentimentResponse(sentiment: .positive), minutesAgo: Double(i * 480))
        }
        let manyResult = AdaptiveRate.computeSpacing(entries: many, now: now)
        let fewResult = AdaptiveRate.computeSpacing(entries: few, now: now)
        XCTAssertLessThan(manyResult.spacing, fewResult.spacing)
    }

    // MARK: - Recency weighting

    func testRecentResponsesWeighMoreThanOld() {
        // Recent cluster + old cluster: spacing should be shorter than old-only
        let old = (0..<10).map { i in
            makeEntry(.sentimentResponse(sentiment: .positive), minutesAgo: 2880 + Double(i * 30))
        }
        let recent = (0..<10).map { i in
            makeEntry(.sentimentResponse(sentiment: .positive), minutesAgo: Double(i * 30))
        }
        let bothResult = AdaptiveRate.computeSpacing(entries: old + recent, now: now)
        let oldResult = AdaptiveRate.computeSpacing(entries: old, now: now)
        XCTAssertLessThan(bothResult.spacing, oldResult.spacing)
    }

    // MARK: - Clamping

    func testSpacingClampedToMin() {
        let entries = (0..<200).map { i in
            makeEntry(.sentimentResponse(sentiment: .positive), minutesAgo: Double(i))
        }
        let result = AdaptiveRate.computeSpacing(entries: entries, now: now)
        XCTAssertGreaterThanOrEqual(result.spacing, AdaptiveRate.minSpacing)
    }

    func testSpacingClampedToMax() {
        let result = AdaptiveRate.computeSpacing(entries: [], now: now)
        XCTAssertLessThanOrEqual(result.spacing, AdaptiveRate.maxSpacing)
    }

    // MARK: - Ignored entries

    func testNonResponseEntriesIgnored() {
        let entries = [
            makeEntry(.sentimentDelivered, minutesAgo: 10),
            makeEntry(.permissionGranted, minutesAgo: 20),
            makeEntry(.notificationsScheduled(count: 3, nextTime: nil), minutesAgo: 30),
        ]
        let result = AdaptiveRate.computeSpacing(entries: entries, now: now)
        XCTAssertEqual(result.weightedResponses, 0)
        XCTAssertEqual(result.spacing, AdaptiveRate.defaultSpacing, accuracy: 1)
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
