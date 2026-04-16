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
        let weightedResponses: Double
        let priorCount: Double
        let responseInterval: TimeInterval
        let spacing: TimeInterval
    }

    /// Compute notification spacing from response frequency using Bayesian blending.
    ///
    /// Takes an array of response ages (seconds since each response).
    /// Pure math — no iOS dependencies, testable via `swift test`.
    ///
    /// Uses a prior equivalent to the default rate (5/day). With no data, produces
    /// exactly defaultSpacing. As real responses accumulate, they smoothly override
    /// the prior. After ~3 days at the default rate, real data dominates.
    ///
    /// spacing = responseInterval / targetRate
    /// responseInterval = effectiveWindow / (weightedResponses + priorCount)
    static func computeSpacing(responseAges ages: [TimeInterval]) -> RateResult {
        let ln2 = log(2.0)
        var weightedResponses = 0.0

        for age in ages {
            weightedResponses += exp(-ln2 * age / halfLife)
        }

        let effectiveWindow = halfLife / ln2
        // Prior: virtual responses at the default rate. Derived so that
        // priorCount alone produces exactly defaultSpacing.
        let priorCount = effectiveWindow / (defaultSpacing * targetRate)
        let effectiveResponses = weightedResponses + priorCount
        let responseInterval = effectiveWindow / effectiveResponses
        let spacing = responseInterval / targetRate
        let clampedSpacing = min(max(spacing, minSpacing), maxSpacing)

        return RateResult(
            weightedResponses: weightedResponses,
            priorCount: priorCount,
            responseInterval: responseInterval,
            spacing: clampedSpacing
        )
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
