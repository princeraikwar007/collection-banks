import Foundation

enum Money {
    /// Locale-aware currency formatter. Uses the device locale so it works fully offline.
    static let formatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.locale = Locale.current
        f.maximumFractionDigits = 2
        f.minimumFractionDigits = 2
        return f
    }()

    static func string(_ value: Double) -> String {
        formatter.string(from: NSNumber(value: value)) ?? String(format: "%.2f", value)
    }

    static func signedString(_ value: Double) -> String {
        let sign = value >= 0 ? "+" : "-"
        return sign + string(abs(value))
    }
}

enum DateFmt {
    static let short: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f
    }()

    static let monthYear: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "LLLL yyyy"
        return f
    }()

    static let iso: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()
}
