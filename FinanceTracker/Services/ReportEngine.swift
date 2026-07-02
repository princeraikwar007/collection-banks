import Foundation

/// Aggregations for dashboards and reports. All pure functions, no I/O.
enum ReportEngine {
    struct Totals {
        var credit: Double
        var debit: Double
        var balance: Double { credit - debit }
        var count: Int
    }

    struct CategoryBreakdown: Identifiable {
        var id: String { category }
        var category: String
        var total: Double
        var count: Int
    }

    struct MonthlyBucket: Identifiable {
        var id: String { key }
        var key: String              // "yyyy-MM"
        var displayMonth: String     // e.g. "March 2026"
        var credit: Double
        var debit: Double
        var net: Double { credit - debit }
    }

    static func totals(_ transactions: [Transaction]) -> Totals {
        var credit = 0.0, debit = 0.0
        for t in transactions {
            if t.type == .credit { credit += t.amount } else { debit += t.amount }
        }
        return Totals(credit: credit, debit: debit, count: transactions.count)
    }

    static func byCategory(_ transactions: [Transaction], type: TransactionType? = nil) -> [CategoryBreakdown] {
        let filtered = type.map { t in transactions.filter { $0.type == t } } ?? transactions
        var buckets: [String: (Double, Int)] = [:]
        for t in filtered {
            let cur = buckets[t.categoryName] ?? (0, 0)
            buckets[t.categoryName] = (cur.0 + t.amount, cur.1 + 1)
        }
        return buckets
            .map { CategoryBreakdown(category: $0.key, total: $0.value.0, count: $0.value.1) }
            .sorted { $0.total > $1.total }
    }

    static func byMonth(_ transactions: [Transaction]) -> [MonthlyBucket] {
        let keyFmt = DateFormatter()
        keyFmt.dateFormat = "yyyy-MM"
        keyFmt.locale = Locale(identifier: "en_US_POSIX")

        var buckets: [String: MonthlyBucket] = [:]
        for t in transactions {
            let key = keyFmt.string(from: t.date)
            var bucket = buckets[key] ?? MonthlyBucket(
                key: key,
                displayMonth: DateFmt.monthYear.string(from: t.date),
                credit: 0,
                debit: 0
            )
            if t.type == .credit { bucket.credit += t.amount } else { bucket.debit += t.amount }
            buckets[key] = bucket
        }
        return buckets.values.sorted { $0.key > $1.key }
    }

    /// Human-readable text report suitable for CSV/txt export or share sheet.
    static func textReport(_ transactions: [Transaction], title: String = "Finance Report") -> String {
        let t = totals(transactions)
        let cats = byCategory(transactions)
        let months = byMonth(transactions)

        var out = ""
        out += "\(title)\n"
        out += String(repeating: "=", count: title.count) + "\n\n"
        out += "Generated: \(DateFmt.short.string(from: Date()))\n"
        out += "Transactions: \(t.count)\n"
        out += "Total Credit: \(Money.string(t.credit))\n"
        out += "Total Debit:  \(Money.string(t.debit))\n"
        out += "Balance:      \(Money.string(t.balance))\n\n"

        out += "By Category\n-----------\n"
        for c in cats {
            out += String(format: "%-20@ %10@ (%d)\n" as NSString,
                          c.category as NSString,
                          Money.string(c.total) as NSString,
                          c.count) as String
        }

        out += "\nBy Month\n--------\n"
        for m in months {
            out += "\(m.displayMonth): +\(Money.string(m.credit))  -\(Money.string(m.debit))  net \(Money.signedString(m.net))\n"
        }
        return out
    }
}
