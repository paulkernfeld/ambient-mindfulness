import XCTest
@testable import AmbientMindfulness

final class ArousalTests: XCTestCase {
    func testAllCasesCount() {
        XCTAssertEqual(Arousal.allCases.count, 5)
    }

    func testRawValues() {
        XCTAssertEqual(Arousal.grossDull.rawValue, "grossDull")
        XCTAssertEqual(Arousal.subtleDull.rawValue, "subtleDull")
        XCTAssertEqual(Arousal.subtleRestless.rawValue, "subtleRestless")
        XCTAssertEqual(Arousal.grossRestless.rawValue, "grossRestless")
        XCTAssertEqual(Arousal.other.rawValue, "other")
    }

    func testEmoji() {
        XCTAssertEqual(Arousal.grossDull.emoji, "😴")
        XCTAssertEqual(Arousal.subtleDull.emoji, "😪")
        XCTAssertEqual(Arousal.subtleRestless.emoji, "🐒")
        XCTAssertEqual(Arousal.grossRestless.emoji, "🤯")
        XCTAssertEqual(Arousal.other.emoji, "❓")
    }

    func testCodableRoundTrip() throws {
        for arousal in Arousal.allCases {
            let data = try JSONEncoder().encode(arousal)
            let decoded = try JSONDecoder().decode(Arousal.self, from: data)
            XCTAssertEqual(decoded, arousal)
        }
    }

    func testRawValuesDoNotCollideWithSentimentExceptOther() {
        // The "other" rawValue is intentionally shared across both axes;
        // disambiguation happens at the notification-category level.
        let sentimentValues = Set(Sentiment.allCases.map { $0.rawValue })
        let arousalValues = Set(Arousal.allCases.map { $0.rawValue })
        XCTAssertEqual(sentimentValues.intersection(arousalValues), ["other"])
    }
}
