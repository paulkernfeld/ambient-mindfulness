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
        let responseInterval: TimeInterval? // average time between responses (nil = no data)
        let spacing: TimeInterval
    }

    /// Compute notification spacing from response frequency.
    /// Only counts user responses — no need to track deliveries.
    /// If user responds every 15min, and target is 80%, spacing = 15min * 0.8 = 12min.
    static func computeSpacing(entries: [MindfulEntry], now: Date = Date()) -> RateResult {
        let ln2 = log(2.0)
        var weightedResponses = 0.0

        for entry in entries {
            guard let payload = entry.payload else { continue }
            let age = now.timeIntervalSince(entry.timestamp)
            if age < 0 { continue }
            let weight = exp(-ln2 * age / halfLife)

            if case .sentimentResponse = payload {
                weightedResponses += weight
            }
        }

        guard weightedResponses > 1.0 else {
            // Not enough data — use defaults
            return RateResult(responseInterval: nil, spacing: defaultSpacing)
        }

        // Effective time window: how much "time" the weights represent
        // For exponential decay, the effective window ≈ halfLife / ln(2)
        // But we want the interval between responses, which is:
        // effectiveWindow / weightedResponses
        let effectiveWindow = halfLife / ln2
        let responseInterval = effectiveWindow / weightedResponses
        let spacing = responseInterval * targetRate
        let clampedSpacing = min(max(spacing, minSpacing), maxSpacing)

        return RateResult(responseInterval: responseInterval, spacing: clampedSpacing)
    }

    /// Compute the next notification time after `after`, skipping sleep hours.
    static func nextTime(after: Date, spacing: TimeInterval) -> Date {
        let calendar = Calendar.current
        var candidate = after.addingTimeInterval(spacing)

        let hour = calendar.component(.hour, from: candidate)
        if hour >= sleepHour || hour < wakeHour {
            let nextDay = hour >= sleepHour
                ? calendar.date(byAdding: .day, value: 1, to: candidate)!
                : candidate
            candidate = calendar.date(bySettingHour: wakeHour, minute: 0, second: 0, of: nextDay)!
        }

        return candidate
    }
}
