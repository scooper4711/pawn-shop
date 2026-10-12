import Foundation
import Testing
@testable import PawnShopCore

@Suite struct BoundedCacheTests {
    @Test func makesAValueOnceAndKeepsIt() {
        let cache = BoundedCache<String>(countLimit: 4)
        var made = 0
        for _ in 0..<3 {
            #expect(cache.value(for: "a") { made += 1; return "A" } == "A")
        }
        #expect(made == 1)
    }

    @Test func keepsNoMissingValueAndForgetsOnRequest() {
        let cache = BoundedCache<String>(countLimit: 4)
        var made = 0
        _ = cache.value(for: "a") { made += 1; return nil }
        _ = cache.value(for: "a") { made += 1; return nil }
        _ = cache.value(for: "b") { made += 1; return "B" }
        cache.removeAll()
        _ = cache.value(for: "b") { made += 1; return "B" }
        #expect(made == 4)
    }

    @Test func dropsValuesBeyondItsLimits() {
        let cache = BoundedCache<Int>(countLimit: 100, totalCostLimit: 10) { $0 }
        _ = cache.value(for: "big") { 8 }
        _ = cache.value(for: "bigger") { 8 }
        var remade = false
        _ = cache.value(for: "big") { remade = true; return 8 }
        #expect(remade)
    }
}
