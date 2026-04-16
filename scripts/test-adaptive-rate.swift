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

// Compute expected spacing from first principles — same blending as production.
let ln2 = log(2.0)

func expectedSpacingUnclamped(_ ages: [TimeInterval]) -> Double {
    var blended = 0.0
    for scale in AdaptiveRate.timescales {
        var w = 0.0
        for age in ages { w += exp(-ln2 * age / scale.halfLife) }
        let ew = scale.halfLife / ln2
        let prior = ew / (AdaptiveRate.defaultSpacing * AdaptiveRate.targetRate)
        let spacing = ew / (w + prior) / AdaptiveRate.targetRate
        blended += spacing * scale.weight
    }
    return blended
}

func expectedSpacing(_ ages: [TimeInterval]) -> Double {
    return min(max(expectedSpacingUnclamped(ages),
                   AdaptiveRate.minSpacing), AdaptiveRate.maxSpacing)
}

// ── Tests ──

func testNoData() {
    let r = AdaptiveRate.computeSpacing(responseAges: [])
    checkEq(r.spacing, AdaptiveRate.defaultSpacing, accuracy: 0.001, "no data → default spacing")
    check(r.scales.count == 2, "two timescales")
    for s in r.scales {
        checkEq(s.spacing, AdaptiveRate.defaultSpacing, accuracy: 0.001,
                "no data → default for each scale")
        check(s.weightedResponses == 0, "no data → 0 responses per scale")
    }
}

func testOneResponse() {
    let ages: [TimeInterval] = [30.0 * 60]
    let r = AdaptiveRate.computeSpacing(responseAges: ages)
    checkEq(r.spacing, expectedSpacing(ages), accuracy: 0.001, "1 response → exact expected")
}

func testShortScaleReactsMoreToRecentData() {
    // 5 responses in the last 30 min — 1h scale should produce shorter spacing
    // because its effective window is smaller so the same responses represent higher density
    let ages = (0..<5).map { TimeInterval($0 * 6 * 60) } // every 6 min
    let r = AdaptiveRate.computeSpacing(responseAges: ages)
    let shortScale = r.scales.first { $0.halfLife == 1 * 3600 }!
    let longScale = r.scales.first { $0.halfLife == 24 * 3600 }!
    check(shortScale.spacing < longScale.spacing,
          "short scale produces shorter spacing for recent activity")
    // Short scale's prior is smaller (shorter effective window)
    check(shortScale.priorCount < longScale.priorCount,
          "short scale has smaller prior")
}

func testDataOverridesPrior() {
    let fewAges = (0..<3).map { TimeInterval($0 * 3600) }
    let manyAges = (0..<30).map { TimeInterval($0 * 3600) }
    let fewR = AdaptiveRate.computeSpacing(responseAges: fewAges)
    let manyR = AdaptiveRate.computeSpacing(responseAges: manyAges)
    check(abs(manyR.spacing - AdaptiveRate.defaultSpacing) >
          abs(fewR.spacing - AdaptiveRate.defaultSpacing),
          "more data → further from default")
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
testShortScaleReactsMoreToRecentData()
testDataOverridesPrior()
testFrequentResponsesDecreaseSpacing()
testManyVsFew()
testRecencyWeighting()
testClampMin()
testClampMax()

print("\(passed) passed, \(failed) failed")
if failed > 0 { exit(1) }
