import Foundation

enum AdaptiveRate {
    static let targetRate = 0.8
    static let halfLife: TimeInterval = 24 * 3600 // 24 hours
    static let defaultSpacing: TimeInterval = 3 * 3600 // 3 hours (~ 5/day)
    static let minSpacing: TimeInterval = 60 // 1 minute
    static let maxSpacing: TimeInterval = 12 * 3600 // 12 hours
    static let wakeHour = 7
    static let sleepHour = 22
    static let bufferSize = 3

    struct RateResult {
        let rate: Double // 0...1
        let spacing: TimeInterval
    }

    /// Compute time-weighted response rate from entry log, derive notification spacing.
    static func computeRate(entries: [MindfulEntry], now: Date = Date()) -> RateResult {
        let ln2 = log(2.0)
        var weightedDeliveries = 0.0
        var weightedResponses = 0.0

        for entry in entries {
            guard let payload = entry.payload else { continue }
            let age = now.timeIntervalSince(entry.timestamp)
            if age < 0 { continue }
            let weight = exp(-ln2 * age / halfLife)

            switch payload {
            case .sentimentDelivered:
                weightedDeliveries += weight
            case .sentimentResponse:
                weightedResponses += weight
            default:
                continue
            }
        }

        guard weightedDeliveries > 2.0 else {
            // Not enough data — use defaults (avoids cold-start death spiral)
            return RateResult(rate: targetRate, spacing: defaultSpacing)
        }

        let rate = min(weightedResponses / weightedDeliveries, 1.0)
        let clampedRate = max(rate, 0.05) // floor to prevent spacing explosion
        let spacing = defaultSpacing * targetRate / clampedRate
        let clampedSpacing = min(max(spacing, minSpacing), maxSpacing)

        return RateResult(rate: rate, spacing: clampedSpacing)
    }

    /// Given a spacing, compute the next notification time after `after`,
    /// skipping sleep hours.
    static func nextTime(after: Date, spacing: TimeInterval) -> Date {
        let calendar = Calendar.current
        var candidate = after.addingTimeInterval(spacing)

        let hour = calendar.component(.hour, from: candidate)
        if hour >= sleepHour || hour < wakeHour {
            // Push to next wake time
            let nextDay = hour >= sleepHour
                ? calendar.date(byAdding: .day, value: 1, to: candidate)!
                : candidate
            candidate = calendar.date(bySettingHour: wakeHour, minute: 0, second: 0, of: nextDay)!
        }

        return candidate
    }
}
