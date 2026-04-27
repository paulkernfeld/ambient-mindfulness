import Foundation

extension AdaptiveRate {
    static func responseAges(from entries: [MindfulEntry], now: Date = Date()) -> [TimeInterval] {
        entries.compactMap { entry in
            guard let payload = entry.payload, payload.isResponse else { return nil }
            let age = awakeAge(from: entry.timestamp, to: now)
            return age >= 0 ? age : nil
        }
    }
}
