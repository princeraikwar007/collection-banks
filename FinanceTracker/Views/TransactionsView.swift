import SwiftUI
import SwiftData

struct TransactionsView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Transaction.date, order: .reverse) private var transactions: [Transaction]

    @State private var searchText = ""
    @State private var filterType: TransactionType? = nil
    @State private var showingAdd = false
    @State private var editing: Transaction? = nil

    var filtered: [Transaction] {
        transactions.filter { t in
            (filterType == nil || t.type == filterType!) &&
            (searchText.isEmpty ||
             t.desc.localizedCaseInsensitiveContains(searchText) ||
             t.categoryName.localizedCaseInsensitiveContains(searchText) ||
             t.notes.localizedCaseInsensitiveContains(searchText))
        }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Picker("Type", selection: $filterType) {
                        Text("All").tag(TransactionType?.none)
                        Text("Credit").tag(TransactionType?.some(.credit))
                        Text("Debit").tag(TransactionType?.some(.debit))
                    }
                    .pickerStyle(.segmented)
                }

                if filtered.isEmpty {
                    ContentUnavailableView(
                        "No matching transactions",
                        systemImage: "magnifyingglass",
                        description: Text("Tap + to add one, or import a bank statement PDF.")
                    )
                } else {
                    ForEach(filtered) { t in
                        Button { editing = t } label: {
                            TransactionRow(transaction: t)
                        }
                        .buttonStyle(.plain)
                    }
                    .onDelete(perform: delete)
                }
            }
            .searchable(text: $searchText, prompt: "Search description, category, notes")
            .navigationTitle("Transactions")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { showingAdd = true } label: { Image(systemName: "plus") }
                }
            }
            .sheet(isPresented: $showingAdd) {
                AddEditTransactionView()
            }
            .sheet(item: $editing) { t in
                AddEditTransactionView(existing: t)
            }
        }
    }

    private func delete(_ offsets: IndexSet) {
        for i in offsets { context.delete(filtered[i]) }
        try? context.save()
    }
}

#Preview {
    TransactionsView().modelContainer(for: [Transaction.self, Category.self], inMemory: true)
}
