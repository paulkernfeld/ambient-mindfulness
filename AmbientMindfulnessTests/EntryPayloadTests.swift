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
}
