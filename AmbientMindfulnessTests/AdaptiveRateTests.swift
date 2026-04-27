import XCTest
@testable import AmbientMindfulness

final class AdaptiveRateTests: XCTestCase {

    // 14:00 local on a fixed day — safely within waking hours in any timezone
    private let now = Calendar.current.date(bySettingHour: 14, minute: 0, second: 0,
        of: Date(timeIntervalSince1970: 1_700_000_000))!

    private func ages(_ minutesAgoList: [Double]) -> [TimeInterval] {
        minutesAgoList.map { $0 * 60 }
    }

    private func localTime(hour: Int, minute: Int = 0, dayOffset: Int = 0) -> Date {
        let day = Calendar.current.date(byAdding: .day, value: dayOffset, to: now)!
        return Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: day)!
    }

    // MARK: - Cold start

    func testNoDataProducesPriorOnlySpacing() {
        let result = AdaptiveRate.computeSpacing(responseAges: [])
        let expectedRate = 0.5 * (AdaptiveRate.pseudoCount / (AdaptiveRate.hourWindow + AdaptiveRate.pseudoDuration))
                         + 0.5 * (AdaptiveRate.pseudoCount / (AdaptiveRate.dayWindow + AdaptiveRate.pseudoDuration))
        XCTAssertEqual(result.spacing, 1.0 / expectedRate, accuracy: 0.001)
        XCTAssertEqual(result.daysCount, 0)
        XCTAssertEqual(result.hoursCount, 0)
    }

    // MARK: - Convergence direction

    func testResponsesDecreaseSpacing() {
        let noData = AdaptiveRate.computeSpacing(responseAges: [])
        let withData = AdaptiveRate.computeSpacing(responseAges: ages((0..<10).map { Double($0 * 30) }))
        XCTAssertLessThan(withData.spacing, noData.spacing)
    }

    func testMoreResponsesProduceShorterSpacing() {
        let fewResult = AdaptiveRate.computeSpacing(responseAges: ages((0..<3).map { Double($0 * 60) }))
        let manyResult = AdaptiveRate.computeSpacing(responseAges: ages((0..<30).map { Double($0 * 60) }))
        XCTAssertLessThan(manyResult.spacing, fewResult.spacing)
    }

    // MARK: - Hour window reactivity

    func testRecentResponsesInHourWindowDecreaseSpacing() {
        let dayOnly = ages([120, 240, 360, 480, 600])
        let dayPlusHour = dayOnly + ages([5, 10, 15])
        let dayResult = AdaptiveRate.computeSpacing(responseAges: dayOnly)
        let hourResult = AdaptiveRate.computeSpacing(responseAges: dayPlusHour)
        XCTAssertLessThan(hourResult.spacing, dayResult.spacing)
    }

    // MARK: - Window boundaries

    func testResponsesBeyondDayWindowIgnored() {
        let awakeHoursPerDay = Double(AdaptiveRate.sleepHour - AdaptiveRate.wakeHour)
        let inWindow = ages([100])
        let beyondWindow = ages([100, awakeHoursPerDay * 60 * 6])
        let inResult = AdaptiveRate.computeSpacing(responseAges: inWindow)
        let outResult = AdaptiveRate.computeSpacing(responseAges: beyondWindow)
        XCTAssertEqual(inResult.spacing, outResult.spacing, accuracy: 0.001)
    }

    // MARK: - Clamping

    func testSpacingClampedToMin() {
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

    // MARK: - Awake-time ages

    func testAwakeAgeSameDay() {
        // 10:00 → 14:00 same day = 4h awake
        let age = AdaptiveRate.awakeAge(from: localTime(hour: 10), to: localTime(hour: 14))
        XCTAssertEqual(age, 4 * 3600, accuracy: 1)
    }

    func testAwakeAgeAcrossOneNight() {
        // Yesterday 21:30 → today 07:30 = 0.5h + 0.5h = 1h awake
        let age = AdaptiveRate.awakeAge(
            from: localTime(hour: 21, minute: 30, dayOffset: -1),
            to: localTime(hour: 7, minute: 30))
        XCTAssertEqual(age, 3600, accuracy: 1)
    }

    func testAwakeAgeMultipleDays() {
        // 3 days ago 21:00 → today 08:00 = 1h + 15h + 15h + 1h = 32h
        let age = AdaptiveRate.awakeAge(
            from: localTime(hour: 21, dayOffset: -3),
            to: localTime(hour: 8))
        XCTAssertEqual(age, 32 * 3600, accuracy: 1)
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
