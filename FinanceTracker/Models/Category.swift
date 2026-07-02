import Foundation
import SwiftData
import SwiftUI

@Model
final class Category {
    @Attribute(.unique) var name: String
    var typeRaw: String        // "income" or "expense"
    var colorHex: String       // for chart swatches
    var systemImage: String    // SF Symbol

    init(name: String, type: TransactionType, colorHex: String, systemImage: String) {
        self.name = name
        self.typeRaw = type.rawValue
        self.colorHex = colorHex
        self.systemImage = systemImage
    }

    var type: TransactionType {
        get { TransactionType(rawValue: typeRaw) ?? .debit }
        set { typeRaw = newValue.rawValue }
    }

    var color: Color { Color(hex: colorHex) ?? .gray }
}

/// Seeds a default set of categories on first launch so users can start categorizing immediately.
enum CategorySeeder {
    static func seedIfNeeded(context: ModelContext) {
        let existing = (try? context.fetch(FetchDescriptor<Category>())) ?? []
        guard existing.isEmpty else { return }

        let defaults: [(String, TransactionType, String, String)] = [
            // Income
            ("Salary",     .credit, "#22C55E", "banknote"),
            ("Refunds",    .credit, "#10B981", "arrow.uturn.left.circle"),
            ("Interest",   .credit, "#14B8A6", "percent"),
            ("Gifts",      .credit, "#84CC16", "gift"),
            ("Other Income", .credit, "#65A30D", "plus.circle"),
            // Expense
            ("Food",       .debit,  "#F97316", "fork.knife"),
            ("Groceries",  .debit,  "#F59E0B", "cart"),
            ("Transport",  .debit,  "#3B82F6", "car"),
            ("Rent",       .debit,  "#EF4444", "house"),
            ("Utilities",  .debit,  "#8B5CF6", "bolt"),
            ("Shopping",   .debit,  "#EC4899", "bag"),
            ("Health",     .debit,  "#06B6D4", "cross.case"),
            ("Entertainment", .debit, "#A855F7", "gamecontroller"),
            ("Fees",       .debit,  "#DC2626", "creditcard"),
            ("Uncategorized", .debit, "#6B7280", "questionmark.circle")
        ]
        for (name, type, hex, symbol) in defaults {
            context.insert(Category(name: name, type: type, colorHex: hex, systemImage: symbol))
        }
        try? context.save()
    }
}

extension Color {
    init?(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("#") { s.removeFirst() }
        guard s.count == 6, let v = UInt64(s, radix: 16) else { return nil }
        let r = Double((v >> 16) & 0xFF) / 255.0
        let g = Double((v >> 8) & 0xFF) / 255.0
        let b = Double(v & 0xFF) / 255.0
        self = Color(red: r, green: g, blue: b)
    }
}
