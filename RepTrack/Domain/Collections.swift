import Foundation

extension Sequence {
    /// Sorts like Kotlin's `sortedWith`: elements that compare equal keep their original order.
    /// (Swift's `sorted` is not guaranteed to be stable.)
    func stableSorted(by areInIncreasingOrder: (Element, Element) -> Bool) -> [Element] {
        enumerated()
            .sorted { lhs, rhs in
                if areInIncreasingOrder(lhs.element, rhs.element) { return true }
                if areInIncreasingOrder(rhs.element, lhs.element) { return false }
                return lhs.offset < rhs.offset
            }
            .map(\.element)
    }

    /// Groups like Kotlin's `groupBy`: groups appear in the order their first element was seen.
    func orderedGroups<Key: Hashable>(by key: (Element) -> Key) -> [(key: Key, values: [Element])] {
        var order: [Key] = []
        var groups: [Key: [Element]] = [:]
        for element in self {
            let k = key(element)
            if groups[k] == nil {
                order.append(k)
                groups[k] = [element]
            } else {
                groups[k]?.append(element)
            }
        }
        return order.map { (key: $0, values: groups[$0] ?? []) }
    }
}
