import XCTest
@testable import AmbientMindfulness

final class EntryPayloadTests: XCTestCase {
    func testDeliveredRoundTrip() throws {
        let payload = EntryPayload.sentimentDelivered
        let data = try JSONEncoder().encode(payload)
        let decoded = try JSONDecoder().decode(EntryPayload.self, from: data)
        XCTAssertEqual(decoded, payload)
    }

    func testResponseRoundTrip() throws {
        for sentiment in Sentiment.allCases {
            let payload = EntryPayload.sentimentResponse(sentiment: sentiment)
            let data = try JSONEncoder().encode(payload)
            let decoded = try JSONDecoder().decode(EntryPayload.self, from: data)
            XCTAssertEqual(decoded, payload)
        }
    }

    func testDeliveredAndResponseAreDistinct() throws {
        let delivered = try JSONEncoder().encode(EntryPayload.sentimentDelivered)
        let response = try JSONEncoder().encode(EntryPayload.sentimentResponse(sentiment: .positive))
        XCTAssertNotEqual(delivered, response)
    }

    func testPermissionGrantedRoundTrip() throws {
        let payload = EntryPayload.permissionGranted
        let data = try JSONEncoder().encode(payload)
        let decoded = try JSONDecoder().decode(EntryPayload.self, from: data)
        XCTAssertEqual(decoded, payload)
    }

    func testPermissionDeniedRoundTrip() throws {
        let withError = EntryPayload.permissionDenied(error: "Not authorized")
        let data1 = try JSONEncoder().encode(withError)
        XCTAssertEqual(try JSONDecoder().decode(EntryPayload.self, from: data1), withError)

        let withoutError = EntryPayload.permissionDenied(error: nil)
        let data2 = try JSONEncoder().encode(withoutError)
        XCTAssertEqual(try JSONDecoder().decode(EntryPayload.self, from: data2), withoutError)
    }

    func testNotificationsScheduledRoundTrip() throws {
        let date = Date(timeIntervalSince1970: 1700000000)
        let withDate = EntryPayload.notificationsScheduled(count: 35, nextTime: date)
        let data1 = try JSONEncoder().encode(withDate)
        XCTAssertEqual(try JSONDecoder().decode(EntryPayload.self, from: data1), withDate)

        let withoutDate = EntryPayload.notificationsScheduled(count: 0, nextTime: nil)
        let data2 = try JSONEncoder().encode(withoutDate)
        XCTAssertEqual(try JSONDecoder().decode(EntryPayload.self, from: data2), withoutDate)
    }

    func testSchedulingErrorRoundTrip() throws {
        let payload = EntryPayload.schedulingError(error: "Something went wrong")
        let data = try JSONEncoder().encode(payload)
        let decoded = try JSONDecoder().decode(EntryPayload.self, from: data)
        XCTAssertEqual(decoded, payload)
    }

    func testTestNotificationScheduledRoundTrip() throws {
        let payload = EntryPayload.testNotificationScheduled
        let data = try JSONEncoder().encode(payload)
        let decoded = try JSONDecoder().decode(EntryPayload.self, from: data)
        XCTAssertEqual(decoded, payload)
    }

    func testIsSentiment() {
        XCTAssertTrue(EntryPayload.sentimentDelivered.isSentiment)
        XCTAssertTrue(EntryPayload.sentimentResponse(sentiment: .positive).isSentiment)
        XCTAssertFalse(EntryPayload.permissionGranted.isSentiment)
        XCTAssertFalse(EntryPayload.permissionDenied(error: nil).isSentiment)
        XCTAssertFalse(EntryPayload.notificationsScheduled(count: 5, nextTime: nil).isSentiment)
        XCTAssertFalse(EntryPayload.schedulingError(error: "fail").isSentiment)
        XCTAssertFalse(EntryPayload.testNotificationScheduled.isSentiment)
    }

    func testEmoji() {
        XCTAssertEqual(EntryPayload.sentimentDelivered.emoji, "📩")
        XCTAssertEqual(EntryPayload.sentimentResponse(sentiment: .positive).emoji, "😊")
        XCTAssertEqual(EntryPayload.permissionGranted.emoji, "🔓")
        XCTAssertEqual(EntryPayload.permissionDenied(error: nil).emoji, "🚫")
        XCTAssertEqual(EntryPayload.notificationsScheduled(count: 3, nextTime: nil).emoji, "📅 3")
        XCTAssertEqual(EntryPayload.schedulingError(error: "x").emoji, "⚠️")
        XCTAssertEqual(EntryPayload.testNotificationScheduled.emoji, "🧪")
    }

    func testLabel() {
        XCTAssertEqual(EntryPayload.sentimentDelivered.label, "Delivered")
        XCTAssertEqual(EntryPayload.sentimentResponse(sentiment: .veryPositive).label, "Response: 🤩")
        XCTAssertEqual(EntryPayload.permissionGranted.label, "Permission: OK")
        XCTAssertEqual(EntryPayload.permissionDenied(error: "nope").label, "Permission: DENIED nope")
        XCTAssertEqual(EntryPayload.permissionDenied(error: nil).label, "Permission: DENIED ")
        XCTAssertEqual(EntryPayload.notificationsScheduled(count: 35, nextTime: nil).label, "Scheduled: 35")
        XCTAssertEqual(EntryPayload.schedulingError(error: "boom").label, "Error: boom")
        XCTAssertEqual(EntryPayload.testNotificationScheduled.label, "Test scheduled")
    }

    func testAllCasesAreDistinct() throws {
        let cases: [EntryPayload] = [
            .sentimentDelivered,
            .sentimentResponse(sentiment: .positive),
            .permissionGranted,
            .permissionDenied(error: "test"),
            .notificationsScheduled(count: 5, nextTime: nil),
            .schedulingError(error: "test"),
            .testNotificationScheduled,
        ]
        let encoded = try cases.map { try JSONEncoder().encode($0) }
        for i in 0..<encoded.count {
            for j in (i + 1)..<encoded.count {
                XCTAssertNotEqual(encoded[i], encoded[j], "\(cases[i]) and \(cases[j]) should encode differently")
            }
        }
    }
}
