import XCTest
@testable import AmbientMindfulness

final class EntryPayloadTests: XCTestCase {
    func testDeliveredRoundTrip() throws {
        let payload = EntryPayload.sentimentDelivered
        let data = try JSONEncoder().encode(payload)
        let decoded = try JSONDecoder().decode(EntryPayload.self, from: data)
        XCTAssertEqual(decoded, payload)
    }

    func testArousalDeliveredRoundTrip() throws {
        let payload = EntryPayload.arousalDelivered
        let data = try JSONEncoder().encode(payload)
        let decoded = try JSONDecoder().decode(EntryPayload.self, from: data)
        XCTAssertEqual(decoded, payload)
    }

    func testSentimentResponseRoundTrip() throws {
        for sentiment in Sentiment.allCases {
            let payload = EntryPayload.sentimentResponse(sentiment: sentiment)
            let data = try JSONEncoder().encode(payload)
            let decoded = try JSONDecoder().decode(EntryPayload.self, from: data)
            XCTAssertEqual(decoded, payload)
        }
    }

    func testArousalResponseRoundTrip() throws {
        for arousal in Arousal.allCases {
            let payload = EntryPayload.arousalResponse(arousal: arousal)
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

    func testSentimentAndArousalResponsesAreDistinct() throws {
        let s = try JSONEncoder().encode(EntryPayload.sentimentResponse(sentiment: .other))
        let a = try JSONEncoder().encode(EntryPayload.arousalResponse(arousal: .other))
        XCTAssertNotEqual(s, a, "Same 'other' raw value across axes must encode distinctly via case discriminator")
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

    func testIsResponse() {
        XCTAssertTrue(EntryPayload.sentimentResponse(sentiment: .positive).isResponse)
        XCTAssertTrue(EntryPayload.arousalResponse(arousal: .grossDull).isResponse)
        XCTAssertFalse(EntryPayload.sentimentDelivered.isResponse)
        XCTAssertFalse(EntryPayload.arousalDelivered.isResponse)
        XCTAssertFalse(EntryPayload.permissionGranted.isResponse)
        XCTAssertFalse(EntryPayload.permissionDenied(error: nil).isResponse)
        XCTAssertFalse(EntryPayload.notificationsScheduled(count: 5, nextTime: nil).isResponse)
        XCTAssertFalse(EntryPayload.schedulingError(error: "fail").isResponse)
        XCTAssertFalse(EntryPayload.testNotificationScheduled.isResponse)
    }

    func testEmoji() {
        XCTAssertEqual(EntryPayload.sentimentDelivered.emoji, "📩")
        XCTAssertEqual(EntryPayload.arousalDelivered.emoji, "📩")
        XCTAssertEqual(EntryPayload.sentimentResponse(sentiment: .positive).emoji, "😊")
        XCTAssertEqual(EntryPayload.arousalResponse(arousal: .grossRestless).emoji, "🤯")
        XCTAssertEqual(EntryPayload.permissionGranted.emoji, "🔓")
        XCTAssertEqual(EntryPayload.permissionDenied(error: nil).emoji, "🚫")
        XCTAssertEqual(EntryPayload.notificationsScheduled(count: 3, nextTime: nil).emoji, "📅 3")
        XCTAssertEqual(EntryPayload.schedulingError(error: "x").emoji, "⚠️")
        XCTAssertEqual(EntryPayload.testNotificationScheduled.emoji, "🧪")
    }

    func testLabel() {
        XCTAssertEqual(EntryPayload.sentimentDelivered.label, "Valence delivered")
        XCTAssertEqual(EntryPayload.sentimentResponse(sentiment: .veryPositive).label, "Valence: 🤩")
        XCTAssertEqual(EntryPayload.arousalDelivered.label, "Activation delivered")
        XCTAssertEqual(EntryPayload.arousalResponse(arousal: .subtleDull).label, "Activation: 😪")
        XCTAssertEqual(EntryPayload.permissionGranted.label, "Permission: OK")
        XCTAssertEqual(EntryPayload.permissionDenied(error: "nope").label, "Permission: DENIED nope")
        XCTAssertEqual(EntryPayload.permissionDenied(error: nil).label, "Permission: DENIED")
        XCTAssertEqual(EntryPayload.notificationsScheduled(count: 35, nextTime: nil).label, "Scheduled: 35")
        XCTAssertEqual(EntryPayload.schedulingError(error: "boom").label, "Error: boom")
        XCTAssertEqual(EntryPayload.testNotificationScheduled.label, "Test scheduled")
    }

    func testAllCasesAreDistinct() throws {
        let cases: [EntryPayload] = [
            .sentimentDelivered,
            .sentimentResponse(sentiment: .positive),
            .arousalDelivered,
            .arousalResponse(arousal: .grossDull),
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
