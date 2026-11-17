import CoreText
import Foundation
import Testing
@testable import PawnShopCore

@Suite struct FontFileCacheTests {
    static let systemFont = URL(fileURLWithPath: "/System/Library/Fonts/Apple Braille Outline 6 Dot.ttf")

    @Test(.enabled(if: FileManager.default.fileExists(atPath: systemFont.path)))
    func readsEachFileOnceForEveryThread() async throws {
        let cache = FontFileCache()
        // Descriptors aren't Sendable, so each task returns which object it got; the cache keeps them alive.
        let read = await withTaskGroup(of: ObjectIdentifier?.self) { group in
            for _ in 0..<8 { group.addTask { cache.descriptor(for: Self.systemFont).map(ObjectIdentifier.init) } }
            return await group.reduce(into: []) { $0.append($1) }
        }
        let first = try #require(read.first ?? nil)
        #expect(read.count == 8 && read.allSatisfy { $0 == first })
    }

    @Test func remembersAFileItCannotRead() {
        let cache = FontFileCache()
        let missing = URL(fileURLWithPath: "/nonexistent/Missing.ttf")
        #expect(cache.descriptor(for: missing) == nil && cache.descriptor(for: missing) == nil)
    }
}
