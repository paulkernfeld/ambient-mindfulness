import XCTest
@testable import AmbientMindfulness

final class SentimentTests: XCTestCase {
    func testAllCasesCount() {
        XCTAssertEqual(Sentiment.allCases.count, 5)
    }

    func testRawValues() {
        XCTAssertEqual(Sentiment.veryPositive.rawValue, "veryPositive")
        XCTAssertEqual(Sentiment.positive.rawValue, "positive")
        XCTAssertEqual(Sentiment.negative.rawValue, "negative")
        XCTAssertEqual(Sentiment.veryNegative.rawValue, "veryNegative")
        XCTAssertEqual(Sentiment.other.rawValue, "other")
    }

    func testEmoji() {
        XCTAssertEqual(Sentiment.veryPositive.emoji, "🤩")
        XCTAssertEqual(Sentiment.positive.emoji, "😊")
        XCTAssertEqual(Sentiment.negative.emoji, "😐")
        XCTAssertEqual(Sentiment.veryNegative.emoji, "😤")
        XCTAssertEqual(Sentiment.other.emoji, "❓")
    }

    func testCodableRoundTrip() throws {
        for sentiment in Sentiment.allCases {
            let data = try JSONEncoder().encode(sentiment)
            let decoded = try JSONDecoder().decode(Sentiment.self, from: data)
            XCTAssertEqual(decoded, sentiment)
        }
    }
}
