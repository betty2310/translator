import Foundation

/// Subsequence matching for the language picker and the action panel (D19). Pure, tested.
enum FuzzyMatcher {
    /// A score for `query` against `candidate`, higher is better, or nil when the query's characters don't
    /// all appear in order. Case- and diacritic-insensitive. An empty query matches everything with 0.
    static func score(_ query: String, in candidate: String) -> Int? {
        let q = Array(fold(query))
        let c = Array(fold(candidate))
        guard !q.isEmpty else { return 0 }
        guard q.count <= c.count else { return nil }
        // Fast path: a whole-string match beats any subsequence.
        if c.starts(with: q) { return 1000 + 10 * q.count - c.count }
        var score = 0
        var qi = 0
        var previousMatch = -2
        for (ci, ch) in c.enumerated() where qi < q.count && ch == q[qi] {
            var gain = 1
            if ci == 0 || c[ci - 1] == " " || c[ci - 1] == "(" { gain += 8 } // word start
            if ci == previousMatch + 1 { gain += 4 }                        // consecutive
            score += gain
            previousMatch = ci
            qi += 1
        }
        guard qi == q.count else { return nil }
        return score - c.count / 8
    }

    /// `items` whose `key` matches `query`, best first; order preserved for equal scores.
    static func filter<T>(_ items: [T], query: String, key: (T) -> String) -> [T] {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return items }
        return items.enumerated()
            .compactMap { index, item in score(trimmed, in: key(item)).map { (index, item, $0) } }
            .sorted { $0.2 != $1.2 ? $0.2 > $1.2 : $0.0 < $1.0 }
            .map { $0.1 }
    }

    private static func fold(_ s: String) -> String {
        s.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
    }
}
