import Foundation

/// Turns transactions into CSV and writes to a temp file for share/export.
enum CSVExporter {
    static func csv(from transactions: [Transaction]) -> String {
        var out = "id,date,type,amount,category,description,notes,source\n"
        for t in transactions {
            let row = [
                t.id.uuidString,
                DateFmt.iso.string(from: t.date),
                t.type.rawValue,
                String(format: "%.2f", t.amount),
                escape(t.categoryName),
                escape(t.desc),
                escape(t.notes),
                escape(t.source)
            ].joined(separator: ",")
            out.append(row)
            out.append("\n")
        }
        return out
    }

    static func writeTempFile(_ csv: String, name: String) throws -> URL {
        let dir = FileManager.default.temporaryDirectory
        let url = dir.appendingPathComponent(name)
        try csv.data(using: .utf8)?.write(to: url, options: .atomic)
        return url
    }

    private static func escape(_ s: String) -> String {
        if s.contains(",") || s.contains("\"") || s.contains("\n") {
            let quoted = s.replacingOccurrences(of: "\"", with: "\"\"")
            return "\"\(quoted)\""
        }
        return s
    }
}
