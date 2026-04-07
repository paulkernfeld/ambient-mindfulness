import XCTest
@testable import AmbientMindfulness

final class DaySchedulerTests: XCTestCase {
    private func makeDate(_ year: Int, _ month: Int, _ day: Int) -> Date {
        Calendar.current.date(from: DateComponents(year: year, month: month, day: day))!
    }

    func testGeneratesFiveTimesPerDay() {
        let times = DayScheduler.promptTimes(for: makeDate(2026, 4, 7))
        XCTAssertEqual(times.count, 5)
    }

    func testTimesWithinWakingHours() {
        let times = DayScheduler.promptTimes(for: makeDate(2026, 4, 7))
        for time in times {
            let hour = Calendar.current.component(.hour, from: time)
            XCTAssertGreaterThanOrEqual(hour, 7, "Before wake hour: \(time)")
            XCTAssertLessThan(hour, 22, "At or after sleep hour: \(time)")
        }
    }

    func testTimesAreSorted() {
        let times = DayScheduler.promptTimes(for: makeDate(2026, 4, 7))
        XCTAssertEqual(times, times.sorted())
    }

    func testDeterministicForSameDate() {
        let date = makeDate(2026, 4, 7)
        XCTAssertEqual(
            DayScheduler.promptTimes(for: date),
            DayScheduler.promptTimes(for: date)
        )
    }

    func testDifferentDatesProduceDifferentTimes() {
        let a = DayScheduler.promptTimes(for: makeDate(2026, 4, 7))
        let b = DayScheduler.promptTimes(for: makeDate(2026, 4, 8))
        XCTAssertNotEqual(a, b)
    }

    func testTimesAreOnCorrectDay() {
        let times = DayScheduler.promptTimes(for: makeDate(2026, 4, 7))
        for time in times {
            XCTAssertEqual(Calendar.current.component(.year, from: time), 2026)
            XCTAssertEqual(Calendar.current.component(.month, from: time), 4)
            XCTAssertEqual(Calendar.current.component(.day, from: time), 7)
        }
    }

    func testWorksForManyDates() {
        let start = makeDate(2026, 1, 1)
        for dayOffset in 0..<100 {
            let date = Calendar.current.date(byAdding: .day, value: dayOffset, to: start)!
            let times = DayScheduler.promptTimes(for: date)
            XCTAssertEqual(times.count, 5)
            XCTAssertEqual(times, times.sorted())
        }
    }
}
