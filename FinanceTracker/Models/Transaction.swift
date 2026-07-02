import Foundation
import SwiftData

enum TransactionType: String, Codable, CaseIterable, Identifiable {
    case credit   // money in
    case debit    // money out
    var id: String { rawValue }
    var displayName: String { self == .credit ? "Credit" : "Debit" }
}

@Model
final class Transaction {
    // Stable identifier for exports and dedupe.
    @Attribute(.unique) var id: UUID
    var date: Date
    var amount: Double          // always positive; sign is derived from `type`
    var typeRaw: String         // TransactionType.rawValue
    var desc: String            // narration / merchant / memo
    var notes: String
    var categoryName: String    // denormalized for offline reports; category may be deleted
    var source: String          // "manual", "pdf-import:<file>", etc.
    var createdAt: Date

    init(
        id: UUID = UUID(),
        date: Date,
        amount: Double,
        type: TransactionType,
        desc: String,
        notes: String = "",
        categoryName: String = "Uncategorized",
        source: String = "manual"
    ) {
        self.id = id
        self.date = date
        self.amount = abs(amount)
        self.typeRaw = type.rawValue
        self.desc = desc
        self.notes = notes
        self.categoryName = categoryName
        self.source = source
        self.createdAt = Date()
    }

    var type: TransactionType {
        get { TransactionType(rawValue: typeRaw) ?? .debit }
        set { typeRaw = newValue.rawValue }
    }

    /// Signed amount: positive for credit, negative for debit.
    var signedAmount: Double {
        type == .credit ? amount : -amount
    }
}
