import XCTest
@testable import AmbientMindfulness

final class AdaptiveRateTests: XCTestCase {

    private let now = Date(timeIntervalSince1970: 1_700_000_000)

    private func ages(_ minutesAgoList: [Double]) -> [TimeInterval] {
        minutesAgoList.map { $0 * 60 }
    }

    // MARK: - Prior behavior

    func testNoDataProducesDefaultSpacing() {
        let result = AdaptiveRate.computeSpacing(responseAges: [])
        XCTAssertEqual(result.spacing, AdaptiveRate.defaultSpacing, accuracy: 1)
        XCTAssertEqual(result.weightedResponses, 0)
        XCTAssertGreaterThan(result.priorCount, 0)
    }

    func testPriorDominatesWithFewResponses() {
        let result = AdaptiveRate.computeSpacing(responseAges: ages([30]))
        XCTAssertEqual(result.spacing, AdaptiveRate.defaultSpacing, accuracy: 750)
    }

    func testDataGraduallyOverridesPrior() {
        let fewResult = AdaptiveRate.computeSpacing(responseAges: ages((0..<3).map { Double($0 * 60) }))
        let manyResult = AdaptiveRate.computeSpacing(responseAges: ages((0..<30).map { Double($0 * 60) }))
        let fewDelta = abs(fewResult.spacing - AdaptiveRate.defaultSpacing)
        let manyDelta = abs(manyResult.spacing - AdaptiveRate.defaultSpacing)
        XCTAssertGreaterThan(manyDelta, fewDelta)
    }

    // MARK: - Convergence direction

    func testManyFrequentResponsesDecreasesSpacing() {
        let result = AdaptiveRate.computeSpacing(responseAges: ages((0..<50).map { Double($0 * 30) }))
        XCTAssertLessThan(result.spacing, AdaptiveRate.defaultSpacing)
    }

    func testManyResponsesProduceShorterSpacingThanFew() {
        let manyResult = AdaptiveRate.computeSpacing(responseAges: ages((0..<50).map { Double($0 * 30) }))
        let fewResult = AdaptiveRate.computeSpacing(responseAges: ages((0..<6).map { Double($0 * 480) }))
        XCTAssertLessThan(manyResult.spacing, fewResult.spacing)
    }

    // MARK: - Recency weighting

    func testRecentResponsesWeighMoreThanOld() {
        let oldAges = ages((0..<10).map { 2880.0 + Double($0 * 30) })
        let recentAges = ages((0..<10).map { Double($0 * 30) })
        let bothResult = AdaptiveRate.computeSpacing(responseAges: oldAges + recentAges)
        let oldResult = AdaptiveRate.computeSpacing(responseAges: oldAges)
        XCTAssertLessThan(bothResult.spacing, oldResult.spacing)
    }

    // MARK: - Clamping

    func testSpacingClampedToMin() {
        // 10000 responses all at age 0 drives unclamped well below floor
        let result = AdaptiveRate.computeSpacing(responseAges: Array(repeating: 0.0, count: 10000))
        XCTAssertEqual(result.spacing, AdaptiveRate.minSpacing, accuracy: 0.001)
    }

    func testSpacingClampedToMax() {
        let result = AdaptiveRate.computeSpacing(responseAges: [])
        XCTAssertLessThanOrEqual(result.spacing, AdaptiveRate.maxSpacing)
    }

    // MARK: - Ignored entries (via responseAges extraction)

    func testResponseAgesExtraction() {
        let data = try! JSONEncoder().encode(EntryPayload.sentimentResponse(sentiment: .positive))
        let response = MindfulEntry(timestamp: now.addingTimeInterval(-1800), payloadJSON: data)

        let deliveredData = try! JSONEncoder().encode(EntryPayload.sentimentDelivered)
        let delivered = MindfulEntry(timestamp: now.addingTimeInterval(-600), payloadJSON: deliveredData)

        let permData = try! JSONEncoder().encode(EntryPayload.permissionGranted)
        let perm = MindfulEntry(timestamp: now.addingTimeInterval(-1200), payloadJSON: permData)

        let extracted = AdaptiveRate.responseAges(from: [response, delivered, perm], now: now)
        XCTAssertEqual(extracted.count, 1)
        XCTAssertEqual(extracted[0], 1800, accuracy: 1)
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
