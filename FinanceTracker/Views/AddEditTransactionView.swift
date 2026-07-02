import SwiftUI
import SwiftData

struct AddEditTransactionView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Category.name) private var categories: [Category]

    var existing: Transaction?

    @State private var date: Date = Date()
    @State private var amountText: String = ""
    @State private var type: TransactionType = .debit
    @State private var desc: String = ""
    @State private var notes: String = ""
    @State private var categoryName: String = "Uncategorized"

    init(existing: Transaction? = nil) {
        self.existing = existing
        if let e = existing {
            _date = State(initialValue: e.date)
            _amountText = State(initialValue: String(format: "%.2f", e.amount))
            _type = State(initialValue: e.type)
            _desc = State(initialValue: e.desc)
            _notes = State(initialValue: e.notes)
            _categoryName = State(initialValue: e.categoryName)
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Details") {
                    Picker("Type", selection: $type) {
                        ForEach(TransactionType.allCases) { t in
                            Text(t.displayName).tag(t)
                        }
                    }
                    .pickerStyle(.segmented)

                    TextField("Amount", text: $amountText)
                        .keyboardType(.decimalPad)

                    DatePicker("Date", selection: $date, displayedComponents: .date)

                    TextField("Description", text: $desc)

                    Picker("Category", selection: $categoryName) {
                        ForEach(matchingCategories, id: \.name) { c in
                            Label(c.name, systemImage: c.systemImage).tag(c.name)
                        }
                    }
                }
                Section("Notes") {
                    TextField("Notes", text: $notes, axis: .vertical).lineLimit(3...6)
                }
            }
            .navigationTitle(existing == nil ? "Add Transaction" : "Edit Transaction")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(!canSave)
                }
            }
        }
    }

    private var matchingCategories: [Category] {
        let filtered = categories.filter { $0.type == type }
        return filtered.isEmpty ? categories : filtered
    }

    private var canSave: Bool {
        Double(amountText.replacingOccurrences(of: ",", with: ".")) ?? 0 > 0 &&
        !desc.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private func save() {
        let amount = Double(amountText.replacingOccurrences(of: ",", with: ".")) ?? 0
        if let e = existing {
            e.date = date
            e.amount = abs(amount)
            e.type = type
            e.desc = desc
            e.notes = notes
            e.categoryName = categoryName
        } else {
            let t = Transaction(
                date: date, amount: amount, type: type,
                desc: desc, notes: notes, categoryName: categoryName
            )
            context.insert(t)
        }
        try? context.save()
        dismiss()
    }
}
