// Local test runner for AdaptiveRate — compiles actual Shared/AdaptiveRate.swift.
// Usage: ./scripts/test-swift.sh

import Foundation

var passed = 0
var failed = 0

func check(_ condition: Bool, _ msg: String, line: Int = #line) {
    if condition { passed += 1 }
    else { failed += 1; print("FAIL (\(line)): \(msg)") }
}

func checkEq(_ a: Double, _ b: Double, accuracy: Double, _ msg: String, line: Int = #line) {
    if abs(a - b) <= accuracy { passed += 1 }
    else { failed += 1; print("FAIL (\(line)): \(msg): \(a) != \(b) +/- \(accuracy)") }
}

// Expected spacing from first principles:
// rate = 0.5 * hourRate + 0.5 * dayRate, each with its own prior
func expectedSpacing(_ ages: [TimeInterval]) -> Double {
    let daysCount = Double(ages.filter { $0 < AdaptiveRate.dayWindow }.count)
    let hoursCount = Double(ages.filter { $0 < AdaptiveRate.hourWindow }.count)
    let hourRate = (hoursCount + AdaptiveRate.pseudoCount) / (AdaptiveRate.hourWindow + AdaptiveRate.pseudoDuration)
    let dayRate = (daysCount + AdaptiveRate.pseudoCount) / (AdaptiveRate.dayWindow + AdaptiveRate.pseudoDuration)
    let rate = 0.5 * hourRate + 0.5 * dayRate
    return min(max(1.0 / rate, AdaptiveRate.minSpacing), AdaptiveRate.maxSpacing)
}

// ── Tests ──

func testNoData() {
    let r = AdaptiveRate.computeSpacing(responseAges: [])
    checkEq(r.spacing, expectedSpacing([]), accuracy: 0.001, "no data → prior-only spacing")
    check(r.daysCount == 0, "no data → 0 days count")
    check(r.hoursCount == 0, "no data → 0 hours count")
}

func testOneResponse() {
    let ages: [TimeInterval] = [30.0 * 60]
    let r = AdaptiveRate.computeSpacing(responseAges: ages)
    checkEq(r.spacing, expectedSpacing(ages), accuracy: 0.001, "1 response → exact expected")
    check(r.daysCount == 1, "1 response in day window")
    check(r.hoursCount == 1, "1 response also in hour window")
}

func testResponsesDecreaseSpacing() {
    let noData = AdaptiveRate.computeSpacing(responseAges: [])
    let ages = (0..<10).map { TimeInterval($0 * 30 * 60) }
    let withData = AdaptiveRate.computeSpacing(responseAges: ages)
    check(withData.spacing < noData.spacing, "responses decrease spacing")
}

func testMoreResponsesShorterSpacing() {
    let fewAges = (0..<3).map { TimeInterval($0 * 3600) }
    let manyAges = (0..<30).map { TimeInterval($0 * 3600) }
    let fewR = AdaptiveRate.computeSpacing(responseAges: fewAges)
    let manyR = AdaptiveRate.computeSpacing(responseAges: manyAges)
    check(manyR.spacing < fewR.spacing, "more responses → shorter spacing")
}

func testHourWindowReactivity() {
    let dayOnly: [TimeInterval] = [7200, 14400, 21600]
    let dayPlusHour: [TimeInterval] = [300, 600, 900, 7200, 14400, 21600]
    let dayR = AdaptiveRate.computeSpacing(responseAges: dayOnly)
    let hourR = AdaptiveRate.computeSpacing(responseAges: dayPlusHour)
    check(hourR.spacing < dayR.spacing, "hour window responses decrease spacing further")
}

func testBeyondDayWindowIgnored() {
    let inWindow: [TimeInterval] = [6000]
    let beyondWindow: [TimeInterval] = [6000, AdaptiveRate.dayWindow + 3600]
    let inR = AdaptiveRate.computeSpacing(responseAges: inWindow)
    let outR = AdaptiveRate.computeSpacing(responseAges: beyondWindow)
    checkEq(inR.spacing, outR.spacing, accuracy: 0.001, "beyond-window response ignored")
}

func testClampMin() {
    let ages = Array(repeating: 0.0 as TimeInterval, count: 10000)
    let r = AdaptiveRate.computeSpacing(responseAges: ages)
    checkEq(r.spacing, AdaptiveRate.minSpacing, accuracy: 0.001, "clamped to min")
}

func testClampMax() {
    let r = AdaptiveRate.computeSpacing(responseAges: [])
    check(r.spacing <= AdaptiveRate.maxSpacing, "at or below max")
}

func testExactFormula() {
    let ages: [TimeInterval] = [60, 300, 1800, 7200, 36000]
    let r = AdaptiveRate.computeSpacing(responseAges: ages)
    checkEq(r.spacing, expectedSpacing(ages), accuracy: 0.001, "matches first-principles formula")
}

// ── Run ──

testNoData()
testOneResponse()
testResponsesDecreaseSpacing()
testMoreResponsesShorterSpacing()
testHourWindowReactivity()
testBeyondDayWindowIgnored()
testClampMin()
testClampMax()
testExactFormula()

print("\(passed) passed, \(failed) failed")
if failed > 0 { exit(1) }
