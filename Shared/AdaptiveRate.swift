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
        let spacing: TimeInterval
    }

    struct RateResult {
        let scales: [ScaleResult]
        let spacing: TimeInterval
    }

    /// Compute notification spacing by blending multiple EWMA timescales.
    ///
    /// Each timescale independently computes spacing via the Bayesian formula
    /// (its own effective window and prior). Results are blended by weight.
    /// With no data, every timescale produces exactly defaultSpacing.
    static func computeSpacing(responseAges ages: [TimeInterval]) -> RateResult {
        let ln2 = log(2.0)
        var blendedSpacing = 0.0
        var scaleResults: [ScaleResult] = []

        for scale in timescales {
            var weightedResponses = 0.0
            for age in ages {
                weightedResponses += exp(-ln2 * age / scale.halfLife)
            }

            let effectiveWindow = scale.halfLife / ln2
            let priorCount = effectiveWindow / (defaultSpacing * targetRate)
            let effectiveResponses = weightedResponses + priorCount
            let responseInterval = effectiveWindow / effectiveResponses
            let spacing = responseInterval / targetRate

            scaleResults.append(ScaleResult(
                halfLife: scale.halfLife,
                weightedResponses: weightedResponses,
                priorCount: priorCount,
                spacing: spacing
            ))

            blendedSpacing += spacing * scale.weight
        }

        let clampedSpacing = min(max(blendedSpacing, minSpacing), maxSpacing)

        return RateResult(
            scales: scaleResults,
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
