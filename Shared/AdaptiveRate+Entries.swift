import Foundation

extension AdaptiveRate {
    static func responseAges(from entries: [MindfulEntry], now: Date = Date()) -> [TimeInterval] {
        entries.compactMap { entry in
            guard let payload = entry.payload, case .sentimentResponse = payload else { return nil }
            let age = now.timeIntervalSince(entry.timestamp)
            return age >= 0 ? age : nil
        }
    }
}
