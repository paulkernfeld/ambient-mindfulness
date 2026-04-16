import Foundation

enum AdaptiveRate {
    static let targetRate = 0.8
    static let defaultSpacing: TimeInterval = 3 * 3600 // 3 hours (~ 5/day)
    static let minSpacing: TimeInterval = 60 // 1 minute
    static let maxSpacing: TimeInterval = 12 * 3600 // 12 hours
    static let wakeHour = 7
    static let sleepHour = 22
    static let bufferSize = 3

    struct Timescale {
        let halfLife: TimeInterval
        let weight: Double
    }

    static let timescales: [Timescale] = [
        Timescale(halfLife: 1 * 3600, weight: 0.5),   // 1 hour — reactive
        Timescale(halfLife: 24 * 3600, weight: 0.5),   // 24 hours — stable baseline
    ]

    struct ScaleResult {
        let halfLife: TimeInterval
        let weightedResponses: Double
        let priorCount: Double
        let rate: Double // notifications per second for this scale
    }

    struct RateResult {
        let scales: [ScaleResult]
        let blendedRate: Double // weighted sum of per-scale rates
        let spacing: TimeInterval
    }

    /// Compute notification spacing by blending rates from multiple EWMA timescales.
    ///
    /// Each timescale computes a rate (notifications/sec) from its own effective
    /// window and Bayesian prior. Rates are blended by weight, then converted to
    /// spacing once at the end. With no data, every scale produces 1/defaultSpacing.
    static func computeSpacing(responseAges ages: [TimeInterval]) -> RateResult {
        let ln2 = log(2.0)
        var blendedRate = 0.0
        var scaleResults: [ScaleResult] = []

        for scale in timescales {
            var weightedResponses = 0.0
            for age in ages {
                weightedResponses += exp(-ln2 * age / scale.halfLife)
            }

            let effectiveWindow = scale.halfLife / ln2
            let priorCount = effectiveWindow / (defaultSpacing * targetRate)
            let rate = targetRate * (weightedResponses + priorCount) / effectiveWindow

            scaleResults.append(ScaleResult(
                halfLife: scale.halfLife,
                weightedResponses: weightedResponses,
                priorCount: priorCount,
                rate: rate
            ))

            blendedRate += rate * scale.weight
        }

        let spacing = min(max(1.0 / blendedRate, minSpacing), maxSpacing)

        return RateResult(
            scales: scaleResults,
            blendedRate: blendedRate,
            spacing: spacing
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
