import Foundation

enum DayScheduler {
    static let wakeHour = 7
    static let sleepHour = 22
    static let promptsPerDay = 5

    /// Returns `promptsPerDay` sorted prompt times for the given date,
    /// deterministic: same date always produces the same times.
    static func promptTimes(for date: Date) -> [Date] {
        var rng = SeededGenerator(seed: seed(for: date))
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)

        guard let wake = calendar.date(bySettingHour: wakeHour, minute: 0, second: 0, of: startOfDay),
              let sleep = calendar.date(bySettingHour: sleepHour, minute: 0, second: 0, of: startOfDay)
        else { return [] }

        let windowSeconds = Int(sleep.timeIntervalSince(wake))

        return (0..<promptsPerDay)
            .map { _ in Int.random(in: 0..<windowSeconds, using: &rng) }
            .sorted()
            .map { wake.addingTimeInterval(Double($0)) }
    }

    private static func seed(for date: Date) -> UInt64 {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = .current
        let str = formatter.string(from: date)
        var hash: UInt64 = 5381
        for byte in str.utf8 {
            hash = hash &* 33 &+ UInt64(byte)
        }
        return hash
    }
}

struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed == 0 ? 1 : seed
    }

    mutating func next() -> UInt64 {
        state ^= state << 13
        state ^= state >> 7
        state ^= state << 17
        return state
    }
}
