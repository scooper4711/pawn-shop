import Foundation

/// Values kept by key, at most `countLimit` of them and `totalCostLimit` in total cost, which the system also
/// empties when memory runs short. Read PDFs and decoded pictures are kept this way, so that a library of
/// thousands of pawns doesn't hold every PDF it has drawn from open at once.
final class BoundedCache<Value> {
    /// An `NSCache` holds only objects.
    private final class Box {
        let value: Value

        init(_ value: Value) { self.value = value }
    }

    private let cache = NSCache<NSString, Box>()
    private let cost: (Value) -> Int

    /// `cost` measures a value against `totalCostLimit`, such as a picture's bytes; 0 sets no limit.
    init(countLimit: Int, totalCostLimit: Int = 0, cost: @escaping (Value) -> Int = { _ in 0 }) {
        cache.countLimit = countLimit
        cache.totalCostLimit = totalCostLimit
        self.cost = cost
    }

    /// The value for `key`: the kept one, or else the one `make` makes, kept unless it is nil.
    func value(for key: String, make: () -> Value?) -> Value? {
        if let kept = cache.object(forKey: key as NSString) { return kept.value }
        guard let value = make() else { return nil }
        cache.setObject(Box(value), forKey: key as NSString, cost: cost(value))
        return value
    }

    func removeAll() {
        cache.removeAllObjects()
    }
}
