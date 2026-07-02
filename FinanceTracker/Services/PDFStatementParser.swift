import Foundation
import PDFKit

/// On-device bank statement PDF parser.
///
/// Uses PDFKit (Apple framework, no network) to extract text from the PDF,
/// then applies heuristics to detect transaction rows in common statement layouts.
/// Handles:
///  * Date detection in several regional formats (dd/MM/yyyy, MM/dd/yyyy,
///    yyyy-MM-dd, dd MMM yyyy, MMM dd yyyy).
///  * Amount detection at end of line with optional currency symbol / thousands separators.
///  * CR / DR / +/- / parenthesis conventions for credit vs debit.
enum PDFStatementParser {
    struct ParsedTransaction {
        var date: Date
        var desc: String
        var amount: Double
        var type: TransactionType
    }

    struct ParseReport {
        var transactions: [ParsedTransaction]
        var totalLinesScanned: Int
        var linesMatched: Int
        var sourceName: String
    }

    static func parse(fileURL: URL) -> ParseReport? {
        guard let doc = PDFDocument(url: fileURL) else { return nil }
        var text = ""
        for i in 0..<doc.pageCount {
            if let page = doc.page(at: i), let s = page.string {
                text.append(s)
                text.append("\n")
            }
        }
        return parse(text: text, sourceName: fileURL.lastPathComponent)
    }

    static func parse(text: String, sourceName: String) -> ParseReport {
        let lines = text
            .replacingOccurrences(of: "\r", with: "\n")
            .components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        var results: [ParsedTransaction] = []
        var matched = 0

        for line in lines {
            guard let tx = extractTransaction(from: line) else { continue }
            matched += 1
            results.append(tx)
        }

        return ParseReport(
            transactions: results,
            totalLinesScanned: lines.count,
            linesMatched: matched,
            sourceName: sourceName
        )
    }

    // MARK: - Line-level extraction

    private static func extractTransaction(from line: String) -> ParsedTransaction? {
        guard let (date, dateRange) = firstDate(in: line) else { return nil }
        guard let (amount, isNegative, amountRange) = lastAmount(in: line) else { return nil }
        guard amountRange.lowerBound > dateRange.upperBound else { return nil }

        // Description is what's between the matched date and the matched amount.
        let descStart = dateRange.upperBound
        let descEnd = amountRange.lowerBound
        var desc = String(line[descStart..<descEnd])
            .trimmingCharacters(in: .whitespaces)

        // Detect explicit CR / DR markers around amount.
        var isCredit = !isNegative
        let tail = String(line[amountRange.upperBound...]).uppercased()
        let headLower = String(line[descStart..<amountRange.lowerBound]).uppercased()
        if tail.contains(" CR") || tail.hasPrefix("CR") || headLower.contains(" CR ") {
            isCredit = true
        } else if tail.contains(" DR") || tail.hasPrefix("DR") || headLower.contains(" DR ") {
            isCredit = false
        }

        // Clean stray CR/DR from description.
        desc = desc.replacingOccurrences(of: " CR", with: "", options: .caseInsensitive)
                   .replacingOccurrences(of: " DR", with: "", options: .caseInsensitive)
                   .trimmingCharacters(in: .whitespaces)

        if desc.isEmpty { desc = "Imported transaction" }

        return ParsedTransaction(
            date: date,
            desc: desc,
            amount: amount,
            type: isCredit ? .credit : .debit
        )
    }

    // MARK: - Date detection

    private static let datePatterns: [(String, String)] = [
        (#"\b(\d{4}-\d{2}-\d{2})\b"#,                            "yyyy-MM-dd"),
        (#"\b(\d{2}/\d{2}/\d{4})\b"#,                            "dd/MM/yyyy"),
        (#"\b(\d{2}-\d{2}-\d{4})\b"#,                            "dd-MM-yyyy"),
        (#"\b(\d{2}\.\d{2}\.\d{4})\b"#,                          "dd.MM.yyyy"),
        (#"\b(\d{1,2}\s+[A-Za-z]{3,9}\s+\d{2,4})\b"#,            "d MMM yyyy"),
        (#"\b([A-Za-z]{3,9}\s+\d{1,2},?\s+\d{2,4})\b"#,          "MMM d, yyyy"),
        (#"\b(\d{2}/\d{2}/\d{2})\b"#,                            "dd/MM/yy")
    ]

    private static let dateFormatters: [String: DateFormatter] = {
        var map: [String: DateFormatter] = [:]
        for (_, fmt) in datePatterns {
            let df = DateFormatter()
            df.locale = Locale(identifier: "en_US_POSIX")
            df.dateFormat = fmt
            map[fmt] = df
        }
        return map
    }()

    private static func firstDate(in line: String) -> (Date, Range<String.Index>)? {
        for (pattern, fmt) in datePatterns {
            guard let regex = try? NSRegularExpression(pattern: pattern) else { continue }
            let ns = line as NSString
            let range = NSRange(location: 0, length: ns.length)
            guard let match = regex.firstMatch(in: line, range: range), match.numberOfRanges >= 2 else { continue }
            let matched = ns.substring(with: match.range(at: 1))
            if let d = dateFormatters[fmt]?.date(from: matched),
               let swiftRange = Range(match.range(at: 1), in: line) {
                // Also try alternate month/day interpretation for ambiguous US dates.
                return (d, swiftRange)
            }
            // Try alternate parse if primary failed (e.g., MM/dd for a slash pattern).
            if fmt == "dd/MM/yyyy" {
                let alt = DateFormatter(); alt.dateFormat = "MM/dd/yyyy"; alt.locale = Locale(identifier: "en_US_POSIX")
                if let d = alt.date(from: matched),
                   let swiftRange = Range(match.range(at: 1), in: line) {
                    return (d, swiftRange)
                }
            }
        }
        return nil
    }

    // MARK: - Amount detection

    /// Finds the RIGHTMOST monetary amount on the line.
    /// Returns absolute value, whether it was negative, and its range within the line.
    private static func lastAmount(in line: String) -> (Double, Bool, Range<String.Index>)? {
        // Matches: optional -, optional currency prefix, digits with , or . separators, optional decimals.
        // Also matches trailing minus and parenthesized negatives.
        let pattern = #"(?:\(?\-?\s*(?:[\$€£¥₹])?\s*\d{1,3}(?:[,\s]\d{3})*(?:\.\d{1,2})?\)?|\-?\d+\.\d{2})"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let ns = line as NSString
        let matches = regex.matches(in: line, range: NSRange(location: 0, length: ns.length))
        guard let last = matches.last, let swiftRange = Range(last.range, in: line) else { return nil }

        var raw = String(line[swiftRange])
        var isNegative = false
        if raw.hasPrefix("(") && raw.hasSuffix(")") {
            isNegative = true
            raw = String(raw.dropFirst().dropLast())
        }
        if raw.contains("-") {
            isNegative = true
            raw = raw.replacingOccurrences(of: "-", with: "")
        }
        // Strip currency symbols and spaces.
        for ch in ["$", "€", "£", "¥", "₹", " "] {
            raw = raw.replacingOccurrences(of: ch, with: "")
        }
        // Normalize thousands/decimal: assume last '.' or ',' as decimal.
        raw = normalizeNumberString(raw)
        guard let value = Double(raw), value > 0 else { return nil }
        return (value, isNegative, swiftRange)
    }

    private static func normalizeNumberString(_ s: String) -> String {
        // If both separators present, the last one is the decimal separator.
        let lastDot = s.lastIndex(of: ".")
        let lastComma = s.lastIndex(of: ",")
        switch (lastDot, lastComma) {
        case (let d?, let c?):
            if d > c {
                // '.' is decimal → strip commas
                return s.replacingOccurrences(of: ",", with: "")
            } else {
                // ',' is decimal → strip dots, replace comma with dot
                return s.replacingOccurrences(of: ".", with: "")
                        .replacingOccurrences(of: ",", with: ".")
            }
        case (nil, let c?):
            // Only comma present: treat as decimal if 1-2 digits after it, else thousands sep.
            let after = s.distance(from: c, to: s.endIndex) - 1
            if after == 1 || after == 2 {
                return s.replacingOccurrences(of: ",", with: ".")
            } else {
                return s.replacingOccurrences(of: ",", with: "")
            }
        default:
            return s
        }
    }

    // MARK: - Categorization heuristic

    /// Simple keyword-based categorization. Runs on-device, no ML/network.
    static func suggestCategory(for desc: String, type: TransactionType, available: [Category]) -> String {
        let d = desc.lowercased()
        let rules: [(String, [String])] = [
            ("Salary",       ["salary", "payroll", "wages"]),
            ("Refunds",      ["refund", "reversal", "reversed"]),
            ("Interest",     ["interest", "int cr", "int.cr"]),
            ("Fees",         ["fee", "charge", "atm fee"]),
            ("Rent",         ["rent"]),
            ("Utilities",    ["electric", "water bill", "gas bill", "internet", "broadband", "power", "utility"]),
            ("Groceries",    ["grocery", "supermarket", "walmart", "tesco", "aldi", "kroger", "lidl", "sainsbury"]),
            ("Food",         ["restaurant", "cafe", "starbucks", "mcdonald", "kfc", "uber eats", "doordash", "swiggy", "zomato"]),
            ("Transport",    ["uber", "lyft", "ola", "taxi", "metro", "bus", "fuel", "gasoline", "petrol", "shell", "bp "]),
            ("Shopping",     ["amazon", "flipkart", "ebay", "shopping", "mall"]),
            ("Health",       ["pharmacy", "hospital", "clinic", "doctor", "medic"]),
            ("Entertainment",["netflix", "spotify", "cinema", "movie", "prime video", "hulu"])
        ]
        for (cat, keys) in rules {
            if keys.contains(where: { d.contains($0) }) {
                if available.contains(where: { $0.name == cat }) { return cat }
            }
        }
        return "Uncategorized"
    }
}
