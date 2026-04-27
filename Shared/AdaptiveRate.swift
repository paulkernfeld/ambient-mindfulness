import Foundation

enum AdaptiveRate {
    static let minSpacing: TimeInterval = 60 // 1 minute
    static let maxSpacing: TimeInterval = 12 * 3600 // 12 hours
    static let wakeHour = 7
    static let sleepHour = 22
    static let bufferSize = 3

    static let awakePerDay = TimeInterval((sleepHour - wakeHour) * 3600) // 15h
    static let hourWindow: TimeInterval = 3600 // 1 awake hour
    static let dayWindow: TimeInterval = 5 * awakePerDay // 5 awake days (75h)
    static let pseudoCount = 1.0
    static let pseudoDuration: TimeInterval = 3 * 3600 // 3h

    struct RateResult {
        let daysCount: Int
        let hoursCount: Int
        let rate: Double // pooled response rate (responses per awake-second)
        let spacing: TimeInterval
    }

    /// Blended rate from two rectangular windows (1h reactive, 5d stable), each with its own prior.
    /// Ages are in awake-seconds (sleep hours excluded).
    static func computeSpacing(responseAges ages: [TimeInterval]) -> RateResult {
        let daysCount = ages.filter { $0 < dayWindow }.count
        let hoursCount = ages.filter { $0 < hourWindow }.count
        let hourRate = (Double(hoursCount) + pseudoCount) / (hourWindow + pseudoDuration)
        let dayRate = (Double(daysCount) + pseudoCount) / (dayWindow + pseudoDuration)
        let rate = 0.5 * hourRate + 0.5 * dayRate
        let spacing = min(max(1.0 / rate, minSpacing), maxSpacing)
        return RateResult(daysCount: daysCount, hoursCount: hoursCount, rate: rate, spacing: spacing)
    }

    /// Awake seconds elapsed at a given time-of-day (seconds from midnight).
    /// Clamps to [wakeHour, sleepHour] so sleep-time inputs map to boundaries.
    private static func awakeSeconds(at secondsFromMidnight: TimeInterval) -> TimeInterval {
        let wake = TimeInterval(wakeHour * 3600)
        let sleep = TimeInterval(sleepHour * 3600)
        return min(max(secondsFromMidnight, wake), sleep) - wake
    }

    /// Elapsed awake time between two dates, excluding sleep hours.
    /// Each day contributes at most (sleepHour − wakeHour) hours.
    static func awakeAge(from start: Date, to end: Date) -> TimeInterval {
        let cal = Calendar.current
        let startDay = cal.startOfDay(for: start)
        let endDay = cal.startOfDay(for: end)
        let days = cal.dateComponents([.day], from: startDay, to: endDay).day ?? 0
        let awakePerDay = TimeInterval((sleepHour - wakeHour) * 3600)
        return Double(days) * awakePerDay
            + awakeSeconds(at: end.timeIntervalSince(endDay))
            - awakeSeconds(at: start.timeIntervalSince(startDay))
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
