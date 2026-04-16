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

// Derive expected spacing from first principles — same formula as production,
// so we're testing the code matches the math, not guessing tolerances.
let ln2 = log(2.0)
let ew = AdaptiveRate.halfLife / ln2
let prior = ew / (AdaptiveRate.defaultSpacing * AdaptiveRate.targetRate)

func expectedSpacingUnclamped(_ ages: [TimeInterval]) -> Double {
    var w = 0.0
    for age in ages { w += exp(-ln2 * age / AdaptiveRate.halfLife) }
    return ew / (w + prior) / AdaptiveRate.targetRate
}

func expectedSpacing(_ ages: [TimeInterval]) -> Double {
    return min(max(expectedSpacingUnclamped(ages),
                   AdaptiveRate.minSpacing), AdaptiveRate.maxSpacing)
}

// ── Tests ──

func testNoData() {
    let r = AdaptiveRate.computeSpacing(responseAges: [])
    checkEq(r.spacing, AdaptiveRate.defaultSpacing, accuracy: 0.001, "no data → exactly default spacing")
    check(r.weightedResponses == 0, "no data → 0 weighted responses")
    checkEq(r.priorCount, prior, accuracy: 0.001, "prior count matches formula")
}

func testOneResponse() {
    let ages: [TimeInterval] = [30 * 60]
    let r = AdaptiveRate.computeSpacing(responseAges: ages)
    checkEq(r.spacing, expectedSpacing(ages), accuracy: 0.001, "1 response → exact expected")
    check(r.spacing < AdaptiveRate.defaultSpacing, "1 response shifts below default")
}

func testDataGraduallyOverridesPrior() {
    let fewAges = (0..<3).map { TimeInterval($0 * 3600) }
    let manyAges = (0..<30).map { TimeInterval($0 * 3600) }
    let fewR = AdaptiveRate.computeSpacing(responseAges: fewAges)
    let manyR = AdaptiveRate.computeSpacing(responseAges: manyAges)
    check(abs(manyR.spacing - AdaptiveRate.defaultSpacing) >
          abs(fewR.spacing - AdaptiveRate.defaultSpacing),
          "more data → further from default")
    checkEq(fewR.spacing, expectedSpacing(fewAges), accuracy: 0.001, "few → exact")
    checkEq(manyR.spacing, expectedSpacing(manyAges), accuracy: 0.001, "many → exact")
}

func testFrequentResponsesDecreaseSpacing() {
    let ages = (0..<50).map { TimeInterval($0 * 30 * 60) }
    let r = AdaptiveRate.computeSpacing(responseAges: ages)
    check(r.spacing < AdaptiveRate.defaultSpacing, "frequent responses → shorter spacing")
    checkEq(r.spacing, expectedSpacing(ages), accuracy: 0.001, "frequent → exact")
}

func testManyVsFew() {
    let manyAges = (0..<50).map { TimeInterval($0 * 30 * 60) }
    let fewAges = (0..<6).map { TimeInterval($0 * 480 * 60) }
    let manyR = AdaptiveRate.computeSpacing(responseAges: manyAges)
    let fewR = AdaptiveRate.computeSpacing(responseAges: fewAges)
    check(manyR.spacing < fewR.spacing, "many < few spacing")
}

func testRecencyWeighting() {
    let oldAges = (0..<10).map { TimeInterval((2880 + $0 * 30) * 60) }
    let recentAges = (0..<10).map { TimeInterval($0 * 30 * 60) }
    let bothR = AdaptiveRate.computeSpacing(responseAges: oldAges + recentAges)
    let oldR = AdaptiveRate.computeSpacing(responseAges: oldAges)
    check(bothR.spacing < oldR.spacing, "recent responses weigh more")
}

func testClampMin() {
    // 10000 responses all at age 0 — drives unclamped well below floor
    let ages = Array(repeating: 0.0 as TimeInterval, count: 10000)
    let r = AdaptiveRate.computeSpacing(responseAges: ages)
    let unclamped = expectedSpacingUnclamped(ages)
    check(unclamped < AdaptiveRate.minSpacing, "unclamped value below min: \(unclamped)")
    checkEq(r.spacing, AdaptiveRate.minSpacing, accuracy: 0.001, "clamped to min")
}

func testClampMax() {
    let r = AdaptiveRate.computeSpacing(responseAges: [])
    check(r.spacing <= AdaptiveRate.maxSpacing, "at or below max")
}

// ── Run ──

testNoData()
testOneResponse()
testDataGraduallyOverridesPrior()
testFrequentResponsesDecreaseSpacing()
testManyVsFew()
testRecencyWeighting()
testClampMin()
testClampMax()

print("\(passed) passed, \(failed) failed")
if failed > 0 { exit(1) }
